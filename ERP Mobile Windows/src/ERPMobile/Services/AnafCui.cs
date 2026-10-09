using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace ERPMobile.Services;

public static class AnafCui
{
    public enum CheckResult
    {
        Valid,
        Invalid,
        Unavailable,
        Blocked
    }

    public readonly record struct Outcome(CheckResult Result, string Name, string Address, string Status, string FiscalCode = "");

    private static readonly HttpClient Http = CreateClient();

    public static async Task<Outcome> Check(string cui)
    {
        if (!TryDigits(cui, out var number))
            return new Outcome(CheckResult.Invalid, "", "", "");

        var payload = JsonSerializer.Serialize(new[]
        {
            new { cui = number, data = DateTime.Now.ToString("yyyy-MM-dd") }
        });
        try
        {
            using var response = await Http.PostAsync(
                "https://webservicesp.anaf.ro/api/PlatitorTvaRest/v9/tva",
                new StringContent(payload, Encoding.UTF8, "application/json"));
            if (!response.IsSuccessStatusCode)
                return new Outcome(CheckResult.Unavailable, "", "", "");
            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.TryGetProperty("found", out var found)
                && found.ValueKind == JsonValueKind.Array
                && found.GetArrayLength() > 0)
            {
                var company = found[0];
                var name = TextOf(company, "date_generale", "denumire");
                var address = AddressOf(company);
                var status = BlockedStatus(company);
                var fiscal = FiscalCodeOf(company, number);
                if (status.Length > 0)
                    return new Outcome(CheckResult.Blocked, name, address, status, fiscal);
                return new Outcome(CheckResult.Valid, name, address, "", fiscal);
            }
            return new Outcome(CheckResult.Invalid, "", "", "");
        }
        catch (Exception)
        {
            return new Outcome(CheckResult.Unavailable, "", "", "");
        }
    }

    private static string FiscalCodeOf(JsonElement company, long number)
    {
        var payer = company.TryGetProperty("inregistrare_scop_Tva", out var vat)
            && vat.ValueKind == JsonValueKind.Object
            && IsTrue(vat, "scpTVA");
        var digits = number.ToString(CultureInfo.InvariantCulture);
        return payer ? "RO" + digits : digits;
    }

    private static string BlockedStatus(JsonElement company)
    {
        var registration = TextOf(company, "date_generale", "stare_inregistrare");
        var folded = Fold(registration);
        var radiated = folded.Contains("RADIAT", StringComparison.Ordinal) || folded.Contains("RADIERE", StringComparison.Ordinal);
        var namedInactive = folded.Contains("INACTIV", StringComparison.Ordinal);
        var flagged = company.TryGetProperty("stare_inactiv", out var inactive)
            && inactive.ValueKind == JsonValueKind.Object
            && IsTrue(inactive, "statusInactivi");
        if (radiated && registration.Length > 0)
            return registration;
        if (flagged || namedInactive)
            return namedInactive && registration.Length > 0 ? registration : "INACTIV";
        return "";
    }

    private static bool IsTrue(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value))
            return false;
        if (value.ValueKind == JsonValueKind.True)
            return true;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number))
            return number != 0;
        if (value.ValueKind != JsonValueKind.String)
            return false;
        var text = value.GetString() ?? "";
        return text.Equals("true", StringComparison.OrdinalIgnoreCase) || text == "1";
    }

    private static string Fold(string text)
    {
        var normalized = text.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(normalized.Length);
        foreach (var character in normalized)
        {
            if (System.Globalization.CharUnicodeInfo.GetUnicodeCategory(character) != System.Globalization.UnicodeCategory.NonSpacingMark)
                builder.Append(character);
        }
        return builder.ToString().ToUpperInvariant();
    }

    private static string AddressOf(JsonElement company)
    {
        var direct = TextOf(company, "date_generale", "adresa");
        if (direct.Length > 0)
            return direct;
        if (!company.TryGetProperty("adresa_sediu_social", out var office) || office.ValueKind != JsonValueKind.Object)
            return "";
        var parts = new[]
        {
            Text(office, "sdenumire_Strada"),
            Text(office, "snumar_Strada"),
            Text(office, "sdenumire_Localitate"),
            Text(office, "sdenumire_Judet")
        }.Where(part => part.Length > 0);
        return string.Join(", ", parts);
    }

    private static string TextOf(JsonElement company, string objectName, string field)
    {
        if (!company.TryGetProperty(objectName, out var general) || general.ValueKind != JsonValueKind.Object)
            return "";
        return Text(general, field);
    }

    private static string Text(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String)
            return "";
        return (value.GetString() ?? "").Trim();
    }

    private static bool TryDigits(string cui, out long number)
    {
        number = 0;
        var cleaned = cui.Trim().ToUpperInvariant();
        if (cleaned.StartsWith("RO", StringComparison.Ordinal))
            cleaned = cleaned[2..];
        var digits = new string(cleaned.Where(char.IsDigit).ToArray());
        if (digits.Length == 0 || digits.Length > 10)
            return false;
        return long.TryParse(digits, out number) && number > 0;
    }

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("ERPMobile", "1"));
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        return client;
    }
}
