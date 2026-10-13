using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace ERPMobile.Services;

public sealed class SupabaseApi : IDisposable
{
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(60) };
    private readonly string _url;
    private readonly string _anonKey;
    private string? _accessToken;
    private string? _refreshToken;
    private DateTimeOffset _expiresAt;

    public SupabaseApi(string url, string anonKey)
    {
        _url = url.TrimEnd('/');
        _anonKey = anonKey;
    }

    public bool HasSession => !string.IsNullOrEmpty(_accessToken);
    public DateTimeOffset ExpiresAt => _expiresAt;

    /// <summary>Fired after a new access/refresh token pair is issued.</summary>
    public event Action? SessionChanged;

    public void UseSession(string accessToken, string refreshToken, DateTimeOffset expiresAt)
    {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _expiresAt = expiresAt;
    }

    public void ClearSession()
    {
        _accessToken = null;
        _refreshToken = null;
        _expiresAt = default;
    }

    public async Task<(string AccessToken, string RefreshToken, int ExpiresIn, Guid UserId)> SignIn(string email, string password)
    {
        var body = JsonSerializer.Serialize(new { email, password });
        using var response = await SendRaw(HttpMethod.Post, $"{_url}/auth/v1/token?grant_type=password", body, auth: false);
        var json = await ReadRequired(response);
        var access = RequiredString(json, "access_token");
        var refresh = RequiredString(json, "refresh_token");
        var expires = json.TryGetProperty("expires_in", out var exp) ? exp.GetInt32() : 3600;
        var userId = json.GetProperty("user").GetProperty("id").GetGuid();
        UseSession(access, refresh, DateTimeOffset.UtcNow.AddSeconds(Math.Max(expires - 30, 30)));
        SessionChanged?.Invoke();
        return (access, refresh, expires, userId);
    }

    public async Task SignOut()
    {
        if (!string.IsNullOrEmpty(_accessToken))
        {
            try
            {
                using var response = await SendRaw(HttpMethod.Post, $"{_url}/auth/v1/logout", "{}", auth: true);
            }
            catch
            {
                // Local session is cleared even if the server logout fails.
            }
        }
        ClearSession();
    }

    public async Task RefreshIfNeeded()
    {
        if (string.IsNullOrEmpty(_refreshToken))
            return;
        if (_expiresAt > DateTimeOffset.UtcNow.AddMinutes(2))
            return;
        await RefreshNow();
    }

    private async Task RefreshNow()
    {
        var body = JsonSerializer.Serialize(new { refresh_token = _refreshToken });
        using var response = await SendRaw(HttpMethod.Post, $"{_url}/auth/v1/token?grant_type=refresh_token", body, auth: false);
        var text = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
        {
            var message = FormatError(response.StatusCode, text);
            if ((int)response.StatusCode is 400 or 401 or 403)
                throw new SessionRejectedException(message);
            throw new InvalidOperationException(message);
        }

        using var doc = JsonDocument.Parse(text);
        var json = doc.RootElement;
        var access = RequiredString(json, "access_token");
        var refresh = RequiredString(json, "refresh_token");
        var expires = json.TryGetProperty("expires_in", out var exp) && exp.TryGetInt32(out var seconds) ? seconds : 3600;
        UseSession(access, refresh, DateTimeOffset.UtcNow.AddSeconds(Math.Max(expires - 30, 30)));
        SessionChanged?.Invoke();
    }

    public (string AccessToken, string RefreshToken, DateTimeOffset ExpiresAt) CurrentSession()
    {
        if (string.IsNullOrEmpty(_accessToken) || string.IsNullOrEmpty(_refreshToken))
            throw new InvalidOperationException("Nu există sesiune.");
        return (_accessToken, _refreshToken, _expiresAt);
    }

    public async Task<JsonElement> Select(string table, string query, string? range = null)
    {
        await RefreshIfNeeded();
        var url = $"{_url}/rest/v1/{table}";
        if (!string.IsNullOrEmpty(query))
            url += "?" + query;
        using var response = await SendRaw(HttpMethod.Get, url, null, auth: true, range: range ?? "0-999");
        return await ReadRequired(response);
    }

    public async Task<JsonElement> Insert(string table, Dictionary<string, object?> payload)
    {
        await RefreshIfNeeded();
        var body = JsonSerializer.Serialize(payload);
        using var response = await SendRaw(HttpMethod.Post, $"{_url}/rest/v1/{table}", body, auth: true, prefer: "return=representation");
        return await ReadRequired(response);
    }

    public async Task<JsonElement> Update(string table, string id, Dictionary<string, object?> payload)
    {
        await RefreshIfNeeded();
        var body = JsonSerializer.Serialize(payload);
        var url = $"{_url}/rest/v1/{table}?id=eq.{Uri.EscapeDataString(id)}";
        using var response = await SendRaw(HttpMethod.Patch, url, body, auth: true, prefer: "return=representation");
        return await ReadRequired(response);
    }

    public async Task UploadObject(string bucket, string path, byte[] data, string contentType)
    {
        await RefreshIfNeeded();
        var url = $"{_url}/storage/v1/object/{bucket}/{path}";
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.TryAddWithoutValidation("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _accessToken ?? _anonKey);
        request.Headers.TryAddWithoutValidation("x-upsert", "true");
        request.Content = new ByteArrayContent(data);
        request.Content.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        using var response = await _http.SendAsync(request);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(await ErrorText(response));
    }

    public string PublicObjectUrl(string bucket, string path) =>
        $"{_url}/storage/v1/object/public/{bucket}/{path}";

    public async Task RemoveObjects(string bucket, IReadOnlyList<string> paths)
    {
        await RefreshIfNeeded();
        var body = JsonSerializer.Serialize(paths);
        using var response = await SendRaw(HttpMethod.Post, $"{_url}/storage/v1/object/{bucket}/remove", body, auth: true);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(await ErrorText(response));
    }

    public async Task Delete(string table, string id)
    {
        await RefreshIfNeeded();
        var url = $"{_url}/rest/v1/{table}?id=eq.{Uri.EscapeDataString(id)}";
        using var response = await SendRaw(HttpMethod.Delete, url, null, auth: true);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(await ErrorText(response));
    }

    public async Task<JsonElement> Rpc(string name, object payload)
    {
        await RefreshIfNeeded();
        var body = JsonSerializer.Serialize(payload);
        using var response = await SendRaw(HttpMethod.Post, $"{_url}/rest/v1/rpc/{name}", body, auth: true);
        return await ReadRequired(response);
    }

    public async Task Upsert(string table, object payload, string onConflict)
    {
        await RefreshIfNeeded();
        var body = JsonSerializer.Serialize(payload);
        var url = $"{_url}/rest/v1/{table}?on_conflict={Uri.EscapeDataString(onConflict)}";
        using var response = await SendRaw(HttpMethod.Post, url, body, auth: true, prefer: "resolution=merge-duplicates,return=minimal");
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(await ErrorText(response));
    }

    public async Task PatchProfile(Guid userId, object payload)
    {
        await RefreshIfNeeded();
        var body = JsonSerializer.Serialize(payload);
        var url = $"{_url}/rest/v1/user_profiles?id=eq.{userId}";
        using var response = await SendRaw(HttpMethod.Patch, url, body, auth: true, prefer: "return=minimal");
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(await ErrorText(response));
    }

    public async Task<JsonElement> Invoke(string functionName, object payload, bool requireUser = true)
    {
        if (requireUser)
            await RefreshIfNeeded();
        var body = JsonSerializer.Serialize(payload);
        using var response = await SendRaw(HttpMethod.Post, $"{_url}/functions/v1/{functionName}", body, auth: true);
        var json = await ReadRequired(response);
        if (json.ValueKind == JsonValueKind.Object
            && json.TryGetProperty("error", out var error)
            && error.ValueKind == JsonValueKind.String
            && !string.IsNullOrWhiteSpace(error.GetString()))
        {
            throw new InvalidOperationException(error.GetString());
        }
        return json;
    }

    private async Task<HttpResponseMessage> SendRaw(
        HttpMethod method,
        string url,
        string? json,
        bool auth,
        string? prefer = null,
        string? range = null)
    {
        using var request = new HttpRequestMessage(method, url);
        request.Headers.TryAddWithoutValidation("apikey", _anonKey);
        var token = auth ? (_accessToken ?? _anonKey) : _anonKey;
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (!string.IsNullOrEmpty(prefer))
            request.Headers.TryAddWithoutValidation("Prefer", prefer);
        if (!string.IsNullOrEmpty(range))
            request.Headers.TryAddWithoutValidation("Range", range);
        if (json != null)
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");

        var response = await _http.SendAsync(request);
        if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized && auth && !string.IsNullOrEmpty(_refreshToken))
        {
            response.Dispose();
            _expiresAt = DateTimeOffset.MinValue;
            await RefreshIfNeeded();
            using var retry = new HttpRequestMessage(method, url);
            retry.Headers.TryAddWithoutValidation("apikey", _anonKey);
            retry.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _accessToken ?? _anonKey);
            if (!string.IsNullOrEmpty(prefer))
                retry.Headers.TryAddWithoutValidation("Prefer", prefer);
            if (!string.IsNullOrEmpty(range))
                retry.Headers.TryAddWithoutValidation("Range", range);
            if (json != null)
                retry.Content = new StringContent(json, Encoding.UTF8, "application/json");
            return await _http.SendAsync(retry);
        }
        return response;
    }

    private static async Task<JsonElement> ReadRequired(HttpResponseMessage response)
    {
        var text = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(FormatError(response.StatusCode, text));
        if (string.IsNullOrWhiteSpace(text))
            return default;
        using var doc = JsonDocument.Parse(text);
        return doc.RootElement.Clone();
    }

    private static async Task<string> ErrorText(HttpResponseMessage response)
    {
        var text = await response.Content.ReadAsStringAsync();
        return FormatError(response.StatusCode, text);
    }

    private static string FormatError(System.Net.HttpStatusCode status, string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return $"Eroare server ({(int)status}).";
        try
        {
            using var doc = JsonDocument.Parse(text);
            var root = doc.RootElement;
            if (root.TryGetProperty("msg", out var msg) && msg.ValueKind == JsonValueKind.String)
                return MapAuth(msg.GetString() ?? text);
            if (root.TryGetProperty("error_description", out var desc) && desc.ValueKind == JsonValueKind.String)
                return MapAuth(desc.GetString() ?? text);
            if (root.TryGetProperty("message", out var message) && message.ValueKind == JsonValueKind.String)
                return message.GetString() ?? text;
            if (root.TryGetProperty("error", out var error) && error.ValueKind == JsonValueKind.String)
                return MapAuth(error.GetString() ?? text);
        }
        catch
        {
            // Fall through to the raw body.
        }
        return MapAuth(text);
    }

    private static string MapAuth(string message)
    {
        var lower = message.ToLowerInvariant();
        if (lower.Contains("invalid login") || lower.Contains("invalid credentials"))
            return "Email sau parolă incorectă.";
        if (lower.Contains("email not confirmed") || lower.Contains("email_not_confirmed"))
            return "Confirmați adresa de email înainte de autentificare. Verificați inbox-ul pentru linkul de activare.";
        return message;
    }

    private static string RequiredString(JsonElement json, string name)
    {
        if (!json.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException("Răspuns invalid de la server. Verificați configurația Supabase și încercați din nou.");
        return value.GetString() ?? "";
    }

    public void Dispose() => _http.Dispose();
}

public sealed class SessionRejectedException : Exception
{
    public SessionRejectedException(string message) : base(message) { }
}
