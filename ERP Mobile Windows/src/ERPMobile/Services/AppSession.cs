using System.Text.Json;

namespace ERPMobile.Services;

public enum SessionState
{
    Loading,
    ConfigError,
    Login,
    Blocked,
    Ready
}

public sealed class UserProfile
{
    public Guid Id { get; init; }
    public string Nume { get; init; } = "";
    public string Prenume { get; init; } = "";
    public string Email { get; init; } = "";
    public string? Telefon { get; init; }
    public bool IsAdmin { get; init; }
    public bool IsSuperAdmin { get; init; }
    public bool IsBlocked { get; init; }
    public bool IsEmailConfirmed { get; init; } = true;
    public string PreferredLanguage { get; set; } = "ro";
    public Guid? SelectedCompanyId { get; set; }
    public string FullName => $"{Prenume} {Nume}".Trim();
    public bool IsCompanyAdmin => IsAdmin && !IsSuperAdmin;
    public string RoleLabel => IsSuperAdmin ? "Superadmin" : IsCompanyAdmin ? "Admin societate" : "Utilizator";
}

public sealed class CompanyRow
{
    public Guid Id { get; init; }
    public string Denumire { get; init; } = "";
    public string? Cui { get; init; }
    public Guid? AdminUserId { get; init; }
    public string? LogoUrl { get; init; }
    public bool IsActive { get; init; } = true;
    public override string ToString() => Denumire;

    public bool IsNectarie
    {
        get
        {
            var cui = (Cui ?? "").ToUpperInvariant()
                .Replace(" ", "", StringComparison.Ordinal)
                .Replace(".", "", StringComparison.Ordinal)
                .Replace("-", "", StringComparison.Ordinal);
            if (cui.StartsWith("RO", StringComparison.Ordinal))
                cui = cui[2..];
            if (cui == "51159591")
                return true;
            return Denumire.ToUpperInvariant().Contains("NECTARIE", StringComparison.Ordinal);
        }
    }
}

public sealed class CompanyPermission
{
    public Guid CompanyId { get; init; }
    public bool CanView { get; init; }
    public bool CanCreate { get; init; }
    public bool CanEdit { get; init; }
    public bool CanDelete { get; init; }
}

public sealed class AppModule
{
    public Guid Id { get; init; }
    public string Code { get; init; } = "";
    public string Name { get; init; } = "";
    public string? Description { get; init; }
    public int SortOrder { get; init; }
}

public sealed class ModuleAccess
{
    public bool CanView { get; init; }
    public bool CanCreate { get; init; }
    public bool CanEdit { get; init; }
    public bool CanDelete { get; init; }
    public static ModuleAccess Full { get; } = new() { CanView = true, CanCreate = true, CanEdit = true, CanDelete = true };
    public static ModuleAccess None { get; } = new();
}

public sealed class AppSession
{
    private const string DefaultSuperAdminEmail = "razvan.ivan@icloud.com";
    private readonly SupabaseApi? _api;

    public SessionState State { get; private set; } = SessionState.Loading;
    public string? Error { get; private set; }
    public bool IsBusy { get; private set; }
    public UserProfile? Profile { get; private set; }
    public List<CompanyRow> Companies { get; } = new();
    public List<CompanyRow> SwitchableCompanies { get; } = new();
    public CompanyRow? CurrentCompany { get; private set; }
    public List<AppModule> Modules { get; } = new();
    public string? PasswordWarning { get; private set; }
    public string RememberedEmail { get; private set; } = "";

    public bool IsAdmin => Profile?.IsSuperAdmin == true || Profile?.IsCompanyAdmin == true;
    public bool CanSwitchCompany => SwitchableCompanies.Count >= 2;
    public bool NeedsCompanyChoice => State == SessionState.Ready && CurrentCompany == null && CanSwitchCompany;

    public event Action? Changed;

    public AppSession()
    {
        var config = Config.AppConfig.Load();
        if (!config.IsConfigured)
        {
            State = SessionState.ConfigError;
            Error = "Configurați credențialele Supabase înainte de utilizare.";
            return;
        }
        _api = new SupabaseApi(config.SupabaseUrl, config.SupabaseAnonKey);
        _api.SessionChanged += Persist;
        RememberedEmail = SessionFile.Load()?.Email ?? "";
    }

    public async Task Bootstrap()
    {
        if (_api == null)
        {
            Notify();
            return;
        }

        IsBusy = true;
        Error = null;
        Notify();
        try
        {
            string? seedError = null;
            try
            {
                await _api.Invoke("seed-admin", new { }, requireUser: false);
            }
            catch (Exception ex)
            {
                seedError = "Inițializare Admin eșuată: " + ex.Message;
            }

            var stored = SessionFile.Load();
            if (stored != null && !string.IsNullOrWhiteSpace(stored.RefreshToken))
            {
                RememberedEmail = stored.Email;
                _api.UseSession(stored.AccessToken, stored.RefreshToken, stored.ExpiresAt);
                try
                {
                    await _api.RefreshIfNeeded();
                    await LoadProfile(UserIdFromAccessToken(_api.CurrentSession().AccessToken));
                    Persist();
                    return;
                }
                catch (SessionRejectedException)
                {
                    _api.ClearSession();
                    SessionFile.Clear();
                }
                catch
                {
                    if (_api.HasSession && _api.ExpiresAt > DateTimeOffset.UtcNow.AddMinutes(1))
                    {
                        try
                        {
                            await LoadProfile(UserIdFromAccessToken(_api.CurrentSession().AccessToken));
                            return;
                        }
                        catch (SessionRejectedException)
                        {
                            _api.ClearSession();
                            SessionFile.Clear();
                        }
                        catch
                        {
                            // Păstrăm sesiunea pe disc și reîncercăm la următoarea deschidere.
                        }
                    }
                }
            }

            State = SessionState.Login;
            Error = stored == null ? seedError : null;
        }
        finally
        {
            IsBusy = false;
            Notify();
        }
    }

    public async Task Login(string email, string password)
    {
        if (_api == null)
            return;
        IsBusy = true;
        Error = null;
        PasswordWarning = null;
        Notify();
        try
        {
            RememberedEmail = email.Trim();
            var (_, _, _, userId) = await _api.SignIn(RememberedEmail, password);
            await LoadProfile(userId);
            if (email.Trim().Equals(DefaultSuperAdminEmail, StringComparison.OrdinalIgnoreCase) && password == "123456")
                PasswordWarning = "Parola implicită a superadminului trebuie schimbată.";
            Persist();
        }
        catch (Exception ex)
        {
            Error = ex.Message;
            State = SessionState.Login;
        }
        finally
        {
            IsBusy = false;
            Notify();
        }
    }

    public async Task Logout()
    {
        if (_api == null)
            return;
        IsBusy = true;
        Notify();
        try
        {
            await _api.SignOut();
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
        SessionFile.Clear();
        RememberedEmail = "";
        Profile = null;
        StockFormat.Apply(2);
        CurrentCompany = null;
        Companies.Clear();
        SwitchableCompanies.Clear();
        Modules.Clear();
        PasswordWarning = null;
        State = SessionState.Login;
        IsBusy = false;
        Notify();
    }

    public async Task SelectCompany(CompanyRow company)
    {
        if (_api == null || Profile == null)
            return;
        if (!SwitchableCompanies.Any(item => item.Id == company.Id))
            return;
        IsBusy = true;
        Error = null;
        Notify();
        try
        {
            await _api.PatchProfile(Profile.Id, new { selected_company_id = company.Id });
            Profile.SelectedCompanyId = company.Id;
            CurrentCompany = company;
            await LoadStockDigits();
            await LoadModules();
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
        finally
        {
            IsBusy = false;
            Notify();
        }
    }

    public async Task<ModuleAccess> LoadAccess(AppModule module)
    {
        if (_api == null || Profile == null || CurrentCompany == null)
            return ModuleAccess.None;
        if (module.Code == "nomenclatoare")
            return Profile.IsSuperAdmin || Profile.IsCompanyAdmin ? ModuleAccess.Full : ModuleAccess.None;

        var moduleAccess = Profile.IsSuperAdmin || Profile.IsCompanyAdmin
            ? ModuleAccess.Full
            : await PermissionForModule(module.Id);
        var companyAccess = await PermissionForCompany(CurrentCompany.Id);
        return new ModuleAccess
        {
            CanView = moduleAccess.CanView && companyAccess.CanView,
            CanCreate = moduleAccess.CanCreate && companyAccess.CanCreate,
            CanEdit = moduleAccess.CanEdit && companyAccess.CanEdit,
            CanDelete = moduleAccess.CanDelete && companyAccess.CanDelete
        };
    }

    public async Task<JsonElement> SelectRows(string table, string query)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        return await _api.Select(table, query);
    }

    public async Task<JsonElement> SelectRows(string table, string query, int from, int to)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        return await _api.Select(table, query, $"{from}-{to}");
    }

    public async Task InsertRow(string table, Dictionary<string, object?> payload, bool queueOnFailure = true)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        try
        {
            await _api.Insert(table, payload);
        }
        catch (Exception ex) when (queueOnFailure && OfflineOutbox.IsTransient(ex))
        {
            OfflineOutbox.Add("insert", table, null, payload, "Adăugare " + table);
            throw new InvalidOperationException("Fără internet. Operația a rămas în Setări → Sync offline și se trimite când revine conexiunea.");
        }
    }

    public async Task UpdateRow(string table, string id, Dictionary<string, object?> payload, bool queueOnFailure = true)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        try
        {
            await _api.Update(table, id, payload);
        }
        catch (Exception ex) when (queueOnFailure && OfflineOutbox.IsTransient(ex))
        {
            OfflineOutbox.Add("update", table, id, payload, "Modificare " + table);
            throw new InvalidOperationException("Fără internet. Operația a rămas în Setări → Sync offline și se trimite când revine conexiunea.");
        }
    }

    public (string Path, string Url) PosDocumentTarget(Guid companyId)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        var path = companyId.ToString("D").ToLowerInvariant() + "/" + Guid.NewGuid().ToString("D") + ".pdf";
        return (path, _api.PublicObjectUrl("pos-documents", path));
    }

    public async Task UploadPosDocument(string path, byte[] pdf)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        await _api.UploadObject("pos-documents", path, pdf, "application/pdf");
    }

    public async Task<string> UploadProductImage(string companyId, string productId, byte[] data, string contentType)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        var ext = contentType.ToLowerInvariant() switch
        {
            "image/png" => "png",
            "image/webp" => "webp",
            _ => "jpg"
        };
        var path = companyId.ToLowerInvariant() + "/" + productId.ToLowerInvariant() + "." + ext;
        await _api.UploadObject("product-images", path, data, contentType);
        return _api.PublicObjectUrl("product-images", path);
    }

    public async Task RemoveStoredProductImage(string? imagineUrl)
    {
        if (_api == null)
            return;
        var path = ProductImagePath(imagineUrl);
        if (path == null)
            return;
        try
        {
            await _api.RemoveObjects("product-images", [path]);
        }
        catch
        {
            // Ștergerea din storage nu blochează scoaterea pozei de pe fișă.
        }
    }

    private static string? ProductImagePath(string? imagineUrl)
    {
        const string marker = "/storage/v1/object/public/product-images/";
        if (string.IsNullOrWhiteSpace(imagineUrl))
            return null;
        var index = imagineUrl.IndexOf(marker, StringComparison.Ordinal);
        if (index < 0)
            return null;
        var path = Uri.UnescapeDataString(imagineUrl[(index + marker.Length)..]);
        return path.Length == 0 ? null : path;
    }

    public async Task DeleteRow(string table, string id, bool queueOnFailure = true)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        try
        {
            await _api.Delete(table, id);
        }
        catch (Exception ex) when (queueOnFailure && OfflineOutbox.IsTransient(ex))
        {
            OfflineOutbox.Add("delete", table, id, null, "Ștergere " + table);
            throw new InvalidOperationException("Fără internet. Operația a rămas în Setări → Sync offline și se trimite când revine conexiunea.");
        }
    }

    public async Task ReplayOutboxItem(OfflineItem item)
    {
        if (item.Operation == "delete")
            await DeleteRow(item.Table, item.RowId ?? "", queueOnFailure: false);
        else if (item.Operation == "update")
            await UpdateRow(item.Table, item.RowId ?? "", item.Payload ?? new Dictionary<string, object?>(), queueOnFailure: false);
        else
            await InsertRow(item.Table, item.Payload ?? new Dictionary<string, object?>(), queueOnFailure: false);
    }

    public async Task CreateCompany(string denumire, string? cui, string adminNume, string adminPrenume, string adminEmail, string adminParola, string? adminCnp, string? adminTelefon)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        await _api.Invoke("admin-create-company", new
        {
            company = new
            {
                denumire,
                cui,
                nr_reg_com = (string?)null,
                adresa = (string?)null,
                iban = (string?)null,
                email = (string?)null,
                telefon = (string?)null,
                is_active = true,
                platitor_tva = true
            },
            company_admin = new
            {
                nume = adminNume,
                prenume = adminPrenume,
                email = adminEmail,
                parola = adminParola,
                cnp = adminCnp ?? "",
                telefon = adminTelefon ?? ""
            }
        });
        await ReloadCompanies();
        Notify();
    }

    public async Task ChangePassword(string password)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        await _api.Invoke("update-own-password", new { parola = password });
    }

    public async Task SetPreferredLanguage(string code)
    {
        if (_api == null || Profile == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        await _api.PatchProfile(Profile.Id, new { preferred_language_code = code });
        await LoadProfile();
        Notify();
    }

    public async Task<JsonElement> InvokeFunction(string name, object payload)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        return await _api.Invoke(name, payload);
    }

    public async Task<JsonElement> Rpc(string name, object payload)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        return await _api.Rpc(name, payload);
    }

    public async Task UpsertRow(string table, object payload, string onConflict)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        await _api.Upsert(table, payload, onConflict);
    }

    public async Task UpdateCompany(Guid id, string denumire, string? cui)
    {
        if (_api == null)
            throw new InvalidOperationException("Aplicația nu este configurată.");
        await _api.Update("companies", id.ToString(), new Dictionary<string, object?>
        {
            ["denumire"] = denumire.Trim(),
            ["cui"] = string.IsNullOrWhiteSpace(cui) ? null : cui.Trim()
        });
        await ReloadCompanies();
        Notify();
    }

    private async Task LoadProfile(Guid? userId = null)
    {
        if (_api == null)
            return;
        var id = userId ?? Profile?.Id;
        if (id == null)
            throw new InvalidOperationException("Profilul utilizatorului nu a fost găsit.");

        var rows = await _api.Select("user_profiles", $"id=eq.{id}&select=*");
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            throw new InvalidOperationException("Profilul utilizatorului nu a fost găsit.");

        var row = rows[0];
        var profile = new UserProfile
        {
            Id = row.GetProperty("id").GetGuid(),
            Nume = Text(row, "nume"),
            Prenume = Text(row, "prenume"),
            Email = Text(row, "email"),
            Telefon = Optional(row, "telefon"),
            IsAdmin = Bool(row, "is_admin"),
            IsSuperAdmin = Bool(row, "is_superadmin"),
            IsBlocked = Bool(row, "is_blocked"),
            IsEmailConfirmed = !row.TryGetProperty("is_email_confirmed", out var confirmed) || confirmed.ValueKind != JsonValueKind.False,
            PreferredLanguage = string.IsNullOrWhiteSpace(Optional(row, "preferred_language_code")) ? "ro" : Optional(row, "preferred_language_code")!,
            SelectedCompanyId = GuidOrNull(row, "selected_company_id")
        };

        if (profile.IsBlocked)
        {
            await _api.SignOut();
            SessionFile.Clear();
            Profile = null;
            State = SessionState.Blocked;
            Error = "Contul dvs. este blocat. Contactați administratorul.";
            return;
        }

        if (!profile.IsEmailConfirmed && !profile.IsAdmin && !profile.IsSuperAdmin)
        {
            await _api.SignOut();
            SessionFile.Clear();
            Profile = null;
            State = SessionState.Login;
            Error = "Confirmați adresa de email înainte de autentificare. Verificați inbox-ul pentru linkul de activare.";
            return;
        }

        Profile = profile;
        await ReloadCompanies();
        await LoadModules();
        State = SessionState.Ready;
    }

    public async Task RefreshCompanies()
    {
        await ReloadCompanies();
        Notify();
    }

    private async Task ReloadCompanies()
    {
        if (_api == null || Profile == null)
            return;
        Companies.Clear();
        SwitchableCompanies.Clear();
        var rows = await _api.Select("companies", "select=*&order=denumire.asc");
        if (rows.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in rows.EnumerateArray())
            {
                Companies.Add(new CompanyRow
                {
                    Id = row.GetProperty("id").GetGuid(),
                    Denumire = Text(row, "denumire"),
                    Cui = Optional(row, "cui"),
                    AdminUserId = GuidOrNull(row, "admin_user_id"),
                    LogoUrl = Optional(row, "logo_url"),
                    IsActive = !row.TryGetProperty("is_active", out var active) || active.ValueKind != JsonValueKind.False
                });
            }
        }

        var permissions = new List<CompanyPermission>();
        if (!Profile.IsSuperAdmin)
        {
            var permRows = await _api.Select("user_company_permissions", $"user_id=eq.{Profile.Id}&select=*");
            if (permRows.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in permRows.EnumerateArray())
                {
                    permissions.Add(new CompanyPermission
                    {
                        CompanyId = row.GetProperty("company_id").GetGuid(),
                        CanView = Bool(row, "can_view"),
                        CanCreate = Bool(row, "can_create"),
                        CanEdit = Bool(row, "can_edit"),
                        CanDelete = Bool(row, "can_delete")
                    });
                }
            }
        }

        IEnumerable<CompanyRow> writable = Profile.IsSuperAdmin
            ? Companies
            : Companies.Where(company =>
                company.AdminUserId == Profile.Id
                || permissions.Any(permission => permission.CompanyId == company.Id && (permission.CanCreate || permission.CanEdit || permission.CanDelete)));

        SwitchableCompanies.AddRange(writable.OrderBy(company => company.Denumire, StringComparer.CurrentCultureIgnoreCase));

        if (SwitchableCompanies.Count == 0)
        {
            StockFormat.Apply(2);
            CurrentCompany = null;
            if (Profile.IsSuperAdmin)
                await _api.PatchProfile(Profile.Id, new { selected_company_id = (Guid?)null });
            return;
        }

        var selected = Profile.SelectedCompanyId is Guid selectedId
            ? SwitchableCompanies.FirstOrDefault(company => company.Id == selectedId)
            : null;
        if (selected == null && SwitchableCompanies.Count == 1)
        {
            selected = SwitchableCompanies[0];
            await _api.PatchProfile(Profile.Id, new { selected_company_id = selected.Id });
            Profile.SelectedCompanyId = selected.Id;
        }
        CurrentCompany = selected;
        await LoadStockDigits();
    }

    public async Task LoadStockDigits()
    {
        var company = CurrentCompany;
        if (_api == null || company == null)
        {
            StockFormat.Apply(2);
            return;
        }
        try
        {
            var rows = await SelectRows("company_stock_settings", "company_id=eq." + company.Id + "&select=fraction_digits");
            if (rows.ValueKind == JsonValueKind.Array && rows.GetArrayLength() > 0
                && rows[0].TryGetProperty("fraction_digits", out var digits)
                && digits.TryGetInt32(out var value))
            {
                StockFormat.Apply(value);
                return;
            }
            StockFormat.Apply(StockFormat.Fallback(company));
        }
        catch
        {
            StockFormat.Apply(StockFormat.Fallback(company));
        }
    }

    private async Task LoadModules()
    {
        if (_api == null || Profile == null)
            return;
        Modules.Clear();
        var rows = await _api.Select("modules", "is_active=eq.true&select=*&order=sort_order.asc");
        var all = new List<AppModule>();
        if (rows.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in rows.EnumerateArray())
            {
                all.Add(new AppModule
                {
                    Id = row.GetProperty("id").GetGuid(),
                    Code = Text(row, "code"),
                    Name = Text(row, "name"),
                    Description = Optional(row, "description"),
                    SortOrder = row.TryGetProperty("sort_order", out var order) && order.TryGetInt32(out var number) ? number : 0
                });
            }
        }

        all = all.Where(module => module.Code != "products").ToList();
        if (Profile.IsSuperAdmin || Profile.IsCompanyAdmin)
        {
            Modules.AddRange(all);
            return;
        }

        var perms = await _api.Select("user_module_permissions", $"user_id=eq.{Profile.Id}&select=*");
        var allowed = new HashSet<Guid>();
        if (perms.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in perms.EnumerateArray())
            {
                if (Bool(row, "can_view"))
                    allowed.Add(row.GetProperty("module_id").GetGuid());
            }
        }
        Modules.AddRange(all.Where(module => allowed.Contains(module.Id) && module.Code != "nomenclatoare"));
    }

    private async Task<ModuleAccess> PermissionForModule(Guid moduleId)
    {
        if (_api == null || Profile == null)
            return ModuleAccess.None;
        var rows = await _api.Select("user_module_permissions", $"user_id=eq.{Profile.Id}&module_id=eq.{moduleId}&select=*");
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            return ModuleAccess.None;
        var row = rows[0];
        return new ModuleAccess
        {
            CanView = Bool(row, "can_view"),
            CanCreate = Bool(row, "can_create"),
            CanEdit = Bool(row, "can_edit"),
            CanDelete = Bool(row, "can_delete")
        };
    }

    private async Task<ModuleAccess> PermissionForCompany(Guid companyId)
    {
        if (_api == null || Profile == null)
            return ModuleAccess.None;
        if (Profile.IsSuperAdmin)
            return ModuleAccess.Full;
        if (Profile.IsCompanyAdmin && Companies.Any(company => company.Id == companyId && company.AdminUserId == Profile.Id))
            return ModuleAccess.Full;
        var rows = await _api.Select("user_company_permissions", $"user_id=eq.{Profile.Id}&company_id=eq.{companyId}&select=*");
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            return ModuleAccess.None;
        var row = rows[0];
        return new ModuleAccess
        {
            CanView = Bool(row, "can_view"),
            CanCreate = Bool(row, "can_create"),
            CanEdit = Bool(row, "can_edit"),
            CanDelete = Bool(row, "can_delete")
        };
    }

    private void Persist()
    {
        if (_api == null || !_api.HasSession)
            return;
        var session = _api.CurrentSession();
        SessionFile.Save(session.AccessToken, session.RefreshToken, session.ExpiresAt, RememberedEmail);
    }

    private void Notify() => Changed?.Invoke();

    private static Guid UserIdFromAccessToken(string token)
    {
        var part = token.Split('.')[1].Replace('-', '+').Replace('_', '/');
        part = (part.Length % 4) switch
        {
            2 => part + "==",
            3 => part + "=",
            _ => part
        };
        var json = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(part));
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("sub").GetGuid();
    }

    private static string Text(JsonElement row, string name) =>
        row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : "";

    private static string? Optional(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String)
            return null;
        var text = value.GetString();
        return string.IsNullOrWhiteSpace(text) ? null : text;
    }

    private static bool Bool(JsonElement row, string name) =>
        row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;

    private static Guid? GuidOrNull(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String)
            return null;
        return Guid.TryParse(value.GetString(), out var id) ? id : null;
    }
}

file static class SessionFile
{
    private static string PathName => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Dateconta",
        "ERP Mobile",
        "session.json");

    public static void Save(string accessToken, string refreshToken, DateTimeOffset expiresAt, string email)
    {
        var dir = Path.GetDirectoryName(PathName)!;
        Directory.CreateDirectory(dir);
        var json = JsonSerializer.Serialize(new Stored
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            ExpiresAt = expiresAt,
            Email = email
        });
        var temporary = PathName + ".tmp";
        File.WriteAllText(temporary, json);
        File.Move(temporary, PathName, overwrite: true);
    }

    public static Stored? Load()
    {
        if (!File.Exists(PathName))
            return null;
        try
        {
            return JsonSerializer.Deserialize<Stored>(File.ReadAllText(PathName), new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }
        catch
        {
            return null;
        }
    }

    public static void Clear()
    {
        if (File.Exists(PathName))
            File.Delete(PathName);
    }

    public sealed class Stored
    {
        public string AccessToken { get; set; } = "";
        public string RefreshToken { get; set; } = "";
        public DateTimeOffset ExpiresAt { get; set; }
        public string Email { get; set; } = "";
    }
}
