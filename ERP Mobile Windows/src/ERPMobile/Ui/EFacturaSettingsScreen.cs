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
    private readonly TextBlock _status = new() { FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) };
    private readonly TextBlock _until = new() { Foreground = Brand.Brush(Brand.Navy) };
    private readonly TextBlock _info = new() { Foreground = Brushes.DarkGreen, TextWrapping = TextWrapping.Wrap, IsVisible = false };
    private readonly TextBlock _error = new() { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
    private readonly TextBox _email = new() { Watermark = "contabil@firma.ro" };
    private readonly Button _extend;
    private readonly Button _revoke;
    private readonly Button _reauth;
    private readonly StackPanel _enroll = new() { Spacing = 8, IsVisible = false };
    private readonly TextBox _callback = new() { IsReadOnly = true };
    private readonly TextBox _clientId = new();
    private readonly TextBox _clientSecret = new() { PasswordChar = '*' };
    private string _authStatus = "none";
    private bool _expired;
    private int _waitGeneration;

    public EFacturaSettingsScreen(AppSession session)
    {
        _session = session;
        _extend = Button("Prelungește conectarea", true, () => _ = Extend());
        _revoke = Button("Revocă conectarea", false, () => _ = Revoke());
        _reauth = Button("Reautorizează SPV", false, () => _ = SendInvite());
        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        actions.Children.Add(_extend);
        actions.Children.Add(_revoke);
        actions.Children.Add(_reauth);

        var root = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 12, MaxWidth = 640 };
        root.Children.Add(Title("e-Factura (SPV)"));
        root.Children.Add(new TextBlock
        {
            Text = "Semnătura rămâne la contabil. Îi trimiteți un link, valabil 7 zile, pe care îl deschide pe calculatorul lui. Data până la care este autorizată societatea se citește din SPV.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        root.Children.Add(Label("Stare"));
        root.Children.Add(_status);
        root.Children.Add(Label("Valabilă până la (din SPV)"));
        root.Children.Add(_until);
        root.Children.Add(actions);
        root.Children.Add(new TextBlock
        {
            Text = "Dacă ANAF arată „session finished” / hangup, contabilul reîncearcă după restart browser sau trimiteți invitația din nou.",
            TextWrapping = TextWrapping.Wrap,
            FontSize = 12,
            Foreground = Brand.Brush(Brand.Muted)
        });
        root.Children.Add(Title("Invită contabilul pe email"));
        root.Children.Add(new TextBlock
        {
            Text = "Contabilul primește un link de autorizare SPV (valabil 7 zile). După trimitere vedeți confirmarea cu data și ora.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        var inviteRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        _email.MinWidth = 280;
        inviteRow.Children.Add(_email);
        inviteRow.Children.Add(Button("Trimite invitația", true, () => _ = SendInvite()));
        root.Children.Add(inviteRow);
        root.Children.Add(_info);
        if (_session.Profile?.IsSuperAdmin == true)
        {
            _enroll.Children.Add(Label("Înrolare aplicație la ANAF, o singură dată"));
            _enroll.Children.Add(new TextBlock
            {
                Text = "Pe anaf.ro, Servicii online → Înregistrare utilizatori → Dezvoltatori aplicații, înregistrați ERP Mobile pentru serviciul E-Factura. Callback URL este exact adresa de mai jos. Nu se instalează semnătura pe calculatoare.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brand.Brush(Brand.Muted)
            });
            _enroll.Children.Add(Label("Callback URL"));
            _enroll.Children.Add(_callback);
            _enroll.Children.Add(Label("Client ID"));
            _enroll.Children.Add(_clientId);
            _enroll.Children.Add(Label("Client Secret"));
            _enroll.Children.Add(_clientSecret);
            _enroll.Children.Add(Button("Salvează înrolarea", false, () => _ = SaveEnrollment()));
            _enroll.IsVisible = true;
            root.Children.Add(_enroll);
        }
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
            var oauth = await _session.InvokeFunction("anaf-oauth", new { action = "status" });
            if (_session.Profile?.IsSuperAdmin == true)
            {
                _callback.Text = Text(oauth, "redirect_uri");
                var clientId = Text(oauth, "client_id");
                if (clientId.Length > 0)
                    _clientId.Text = clientId;
            }
            var rows = await _session.SelectRows(
                "company_efactura_settings",
                "company_id=eq." + _session.CurrentCompany.Id + "&select=*&limit=1");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                Apply("none", null, null);
                return;
            }
            var row = rows[0];
            var email = Text(row, "accountant_email");
            if (email.Length > 0)
                _email.Text = email;
            Apply(Text(row, "auth_status"), Text(row, "auth_valid_until"), Text(row, "auth_invite_sent_at"));
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
        }
    }

    private void Apply(string status, string? validUntil, string? inviteSentAt)
    {
        _authStatus = string.IsNullOrEmpty(status) ? "none" : status;
        var day = string.IsNullOrEmpty(validUntil) ? null : validUntil.Length >= 10 ? validUntil[..10] : validUntil;
        DateTime? until = null;
        if (!string.IsNullOrEmpty(day) && DateTime.TryParseExact(day, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
            until = parsed.Date;
        _expired = _authStatus == "authorized" && until != null && until.Value.Date < DateTime.Today;
        var invited = !string.IsNullOrEmpty(inviteSentAt);
        _status.Text = _expired ? "Expirat" : _authStatus switch
        {
            "authorized" => "Autorizat în SPV",
            "requested" when invited => "Invitație trimisă",
            _ => "Neautorizat"
        };
        _status.Foreground = _expired ? Brushes.Firebrick : _authStatus == "authorized" ? Brushes.DarkGreen : Brand.Brush(Brand.Muted);
        _until.Text = until == null ? "—" : until.Value.ToString("d MMMM yyyy", CultureInfo.GetCultureInfo("ro-RO"));
        var connected = _authStatus == "authorized" && !_expired;
        _extend.IsEnabled = connected;
        _revoke.IsEnabled = _authStatus == "authorized";
    }

    private async Task SendInvite()
    {
        if (_session.CurrentCompany == null)
        {
            _error.Text = "Selectați o societate.";
            return;
        }
        var email = (_email.Text ?? "").Trim();
        if (email.Length == 0)
        {
            _error.Text = "Completați emailul contabilului.";
            return;
        }
        var wait = ++_waitGeneration;
        _error.Text = "";
        try
        {
            var result = await _session.InvokeFunction("anaf-oauth", new
            {
                action = "invite",
                company_id = _session.CurrentCompany.Id.ToString(),
                accountant_email = email
            });
            _info.IsVisible = true;
            _info.Text = "Invitație trimisă la " + When(Text(result, "sent_at")) + ". Linkul este valabil 7 zile. Data de autorizare apare aici după ce contabilul o termină în SPV.";
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
            return;
        }

        var before = _until.Text;
        for (var i = 0; i < 90 && wait == _waitGeneration; i++)
        {
            await Task.Delay(2000);
            if (wait != _waitGeneration)
                return;
            await Reload();
            if (_authStatus == "authorized" && _until.Text != before && _until.Text != "—")
            {
                _info.Text = "Autorizat în SPV până la " + _until.Text + ". Data este citită din SPV.";
                return;
            }
        }
    }

    private async Task Extend()
    {
        if (_session.CurrentCompany == null)
            return;
        _error.Text = "";
        try
        {
            await _session.InvokeFunction("anaf-oauth", new
            {
                action = "refresh",
                company_id = _session.CurrentCompany.Id.ToString()
            });
            await Reload();
            _info.IsVisible = true;
            _info.Text = "Conectarea a fost prelungită. Valabilă până la " + _until.Text + ", citit din SPV.";
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
        }
    }

    private async Task Revoke()
    {
        if (_session.CurrentCompany == null)
            return;
        _error.Text = "";
        ++_waitGeneration;
        try
        {
            await _session.InvokeFunction("anaf-oauth", new
            {
                action = "revoke",
                company_id = _session.CurrentCompany.Id.ToString()
            });
            await Reload();
            _info.IsVisible = true;
            _info.Text = "Conectarea SPV a fost revocată.";
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
        }
    }

    private async Task SaveEnrollment()
    {
        _error.Text = "";
        try
        {
            await _session.InvokeFunction("anaf-oauth", new
            {
                action = "save",
                client_id = (_clientId.Text ?? "").Trim(),
                client_secret = _clientSecret.Text ?? ""
            });
            _clientSecret.Text = "";
            _info.IsVisible = true;
            _info.Text = "Înrolarea a fost salvată. Puteți trimite invitația contabilului.";
            await Reload();
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
        }
    }

    private static string When(string iso)
    {
        if (DateTimeOffset.TryParse(iso, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var parsed))
            return parsed.ToLocalTime().ToString("d MMMM yyyy, HH:mm", CultureInfo.GetCultureInfo("ro-RO"));
        return DateTime.Now.ToString("d MMMM yyyy, HH:mm", CultureInfo.GetCultureInfo("ro-RO"));
    }

    private static TextBlock Title(string text) => new()
    {
        Text = text,
        FontSize = 22,
        FontWeight = FontWeight.SemiBold,
        Foreground = Brand.Brush(Brand.Navy)
    };

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
