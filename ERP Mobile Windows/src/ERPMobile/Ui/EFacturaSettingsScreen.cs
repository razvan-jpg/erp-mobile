using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class EFacturaSettingsScreen : UserControl
{
    private readonly AppSession _session;
    private readonly TextBox _email = new() { Watermark = "contabil@firma.ro" };
    private readonly TextBlock _status = new() { FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) };
    private readonly TextBlock _until = new() { Foreground = Brand.Brush(Brand.Navy) };
    private readonly TextBlock _hint = new() { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap, IsVisible = false };
    private readonly TextBlock _error = new() { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
    private readonly DatePicker _validUntil = new() { HorizontalAlignment = HorizontalAlignment.Left };
    private readonly StackPanel _dateRow = new() { Spacing = 4 };
    private string _authStatus = "none";
    private string? _requestedAt;
    private string? _authorizedAt;
    private string? _storedUntil;

    public EFacturaSettingsScreen(AppSession session)
    {
        _session = session;
        _validUntil.SelectedDate = new DateTimeOffset(DateTime.Today.AddYears(1));
        _validUntil.MinYear = DateTimeOffset.Now;
        var root = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 12, MaxWidth = 560 };
        root.Children.Add(new TextBlock
        {
            Text = "e-Factura (SPV)",
            FontSize = 22,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy)
        });
        root.Children.Add(new TextBlock
        {
            Text = "Autorizarea se face prin contabil. Îi trimiteți un email ca să autorizeze societatea în SPV cu semnătura lui electronică. Aici vedeți starea și până când este valabilă.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        root.Children.Add(Label("Email contabil"));
        root.Children.Add(_email);
        root.Children.Add(Label("Stare autentificare"));
        root.Children.Add(_status);
        root.Children.Add(Label("Valabilă până la"));
        root.Children.Add(_until);
        root.Children.Add(_hint);
        _dateRow.Children.Add(Label("Data comunicată de contabil"));
        _dateRow.Children.Add(_validUntil);
        _dateRow.IsVisible = false;
        root.Children.Add(_dateRow);
        root.Children.Add(Button("Salvează email", false, () => _ = SaveEmail()));
        root.Children.Add(Button("Trimite cerere de autorizare", true, () => _ = SendRequest()));
        root.Children.Add(Button("Marchează ca autorizat", true, () => _ = MarkAuthorized()));
        root.Children.Add(new TextBlock
        {
            Text = "„Autorizat” înseamnă că contabilul a confirmat autorizarea în SPV, cu semnătura electronică, și a comunicat data până la care este valabilă.",
            TextWrapping = TextWrapping.Wrap,
            FontSize = 12,
            Foreground = Brand.Brush(Brand.Muted)
        });
        root.Children.Add(_error);
        Content = new ScrollViewer { Content = root };
        _ = Reload();
    }

    private async Task Reload()
    {
        _error.Text = "";
        if (_session.CurrentCompany == null)
        {
            _status.Text = "Selectați o societate.";
            return;
        }
        try
        {
            var rows = await _session.SelectRows(
                "company_efactura_settings",
                "company_id=eq." + _session.CurrentCompany.Id + "&select=*&limit=1");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                Apply("none", "", null, null, null);
                return;
            }
            var row = rows[0];
            Apply(
                Text(row, "auth_status"),
                Text(row, "accountant_email"),
                Text(row, "auth_valid_until"),
                Text(row, "auth_requested_at"),
                Text(row, "auth_authorized_at"));
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
        }
    }

    private void Apply(string status, string email, string? validUntil, string? requestedAt, string? authorizedAt)
    {
        _authStatus = string.IsNullOrEmpty(status) ? "none" : status;
        _requestedAt = string.IsNullOrEmpty(requestedAt) ? null : requestedAt;
        _authorizedAt = string.IsNullOrEmpty(authorizedAt) ? null : authorizedAt;
        _storedUntil = string.IsNullOrEmpty(validUntil) ? null : validUntil.Length >= 10 ? validUntil[..10] : validUntil;
        if (!string.IsNullOrEmpty(email))
            _email.Text = email;
        DateTime? until = null;
        if (!string.IsNullOrEmpty(_storedUntil) && DateTime.TryParseExact(_storedUntil, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
            until = parsed.Date;
        var expired = _authStatus == "authorized" && until != null && until.Value.Date < DateTime.Today;
        _status.Text = expired ? "Expirat" : _authStatus switch
        {
            "requested" => "Cerere trimisă",
            "authorized" => "Autorizat",
            _ => "Neconfigurat"
        };
        _status.Foreground = expired ? Brushes.Firebrick : _authStatus switch
        {
            "requested" => Brushes.DarkOrange,
            "authorized" => Brushes.DarkGreen,
            _ => Brand.Brush(Brand.Muted)
        };
        _until.Text = until == null ? "—" : until.Value.ToString("d MMMM yyyy", CultureInfo.GetCultureInfo("ro-RO"));
        _hint.IsVisible = expired;
        _hint.Text = expired ? "Autorizarea a expirat. Trimiteți din nou cererea și marcați noua dată." : "";
        var canDate = _authStatus is "requested" or "authorized";
        _dateRow.IsVisible = canDate;
        if (until != null && until.Value.Date >= DateTime.Today)
            _validUntil.SelectedDate = new DateTimeOffset(until.Value);
    }

    private async Task SaveEmail()
    {
        await Save(_authStatus, _requestedAt, _authorizedAt, CurrentUntilOrNull());
    }

    private async Task SendRequest()
    {
        var email = (_email.Text ?? "").Trim();
        if (email.Length == 0 || _session.CurrentCompany == null)
        {
            _error.Text = "Completați emailul contabilului.";
            return;
        }
        var company = _session.CurrentCompany;
        var subject = "Cerere autorizare SPV e-Factura — " + company.Denumire;
        var body = "Bună ziua,\n\nVă rugăm să autorizați societatea de mai jos în SPV (RO e-Factura), cu semnătura dumneavoastră electronică:\n\nDenumire: "
            + company.Denumire + "\nCUI: " + (company.Cui ?? "—")
            + "\n\nDupă autorizare, vă rugăm să ne comunicați data până la care autorizarea este valabilă.\n\nVom trimite facturile emise din ERP Mobile ca XML UBL și PDF pe acest email, pentru încărcare în e-Factura.\n\nVă mulțumim.";
        try
        {
            Process.Start(new ProcessStartInfo("mailto:" + Uri.EscapeDataString(email) + "?subject=" + Uri.EscapeDataString(subject) + "&body=" + Uri.EscapeDataString(body))
            {
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
            return;
        }
        if (!await ConfirmDialog.Ask(this, "Ați trimis cererea către contabil? Starea devine „Cerere trimisă”."))
            return;
        var now = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture);
        await Save("requested", now, _authorizedAt, CurrentUntilOrNull());
    }

    private async Task MarkAuthorized()
    {
        if (_validUntil.SelectedDate == null)
        {
            _error.Text = "Alegeți data până la care este valabilă autorizarea.";
            return;
        }
        var day = _validUntil.SelectedDate.Value.Date;
        if (day < DateTime.Today)
        {
            _error.Text = "Data de valabilitate nu poate fi în trecut.";
            return;
        }
        var now = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture);
        await Save("authorized", _requestedAt ?? now, now, day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
    }

    private string? CurrentUntilOrNull() => _storedUntil;

    private async Task Save(string status, string? requestedAt, string? authorizedAt, string? validUntil)
    {
        _error.Text = "";
        if (_session.CurrentCompany == null)
            return;
        var email = (_email.Text ?? "").Trim();
        if (email.Length == 0)
        {
            _error.Text = "Completați emailul contabilului.";
            return;
        }
        try
        {
            await _session.UpsertRow("company_efactura_settings", new Dictionary<string, object?>
            {
                ["company_id"] = _session.CurrentCompany.Id.ToString(),
                ["accountant_email"] = email,
                ["auth_status"] = status,
                ["auth_requested_at"] = requestedAt,
                ["auth_authorized_at"] = authorizedAt,
                ["auth_valid_until"] = validUntil
            }, "company_id");
            await Reload();
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
        }
    }

    private static TextBlock Label(string text) => new()
    {
        Text = text,
        FontSize = 12,
        Foreground = Brand.Brush(Brand.Muted)
    };

    private static Button Button(string title, bool accent, Action action)
    {
        var button = new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Left,
            Padding = new Avalonia.Thickness(14, 8),
            Background = accent ? Brand.Brush(Brand.Navy) : Brushes.White,
            Foreground = accent ? Brushes.White : Brand.Brush(Brand.Navy)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static string Text(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.ToString();
    }
}
