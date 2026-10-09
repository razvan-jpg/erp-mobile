using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class LanguageSettings : UserControl
{
    private static readonly (string Code, string Name)[] Languages =
    [
        ("ro", "Română"), ("en", "English"), ("fr", "Français"), ("it", "Italiano"), ("es", "Español"),
        ("de", "Deutsch"), ("pl", "Polski"), ("cs", "Čeština"), ("sr", "Srpski"), ("hu", "Magyar"),
        ("ru", "Русский"), ("bg", "Български"), ("tr", "Türkçe"), ("ne", "नेपाली"), ("ko", "한국어"),
        ("zh-Hans", "中文"), ("ja", "日本語"), ("ar", "العربية"), ("th", "ไทย"), ("nl", "Nederlands")
    ];

    public LanguageSettings(AppSession session, SettingsHome home)
    {
        var current = session.Profile?.PreferredLanguage ?? "ro";
        var combo = new ComboBox
        {
            ItemsSource = Languages.Select(language => language.Name).ToList(),
            SelectedIndex = Math.Max(0, Array.FindIndex(Languages, language => language.Code == current)),
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        var status = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) };
        var save = new Button { Content = "Salvează limba", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) =>
        {
            var index = combo.SelectedIndex;
            if (index < 0)
                return;
            try
            {
                await session.SetPreferredLanguage(Languages[index].Code);
                status.Foreground = Brushes.DarkGreen;
                status.Text = "Limba a fost salvată pe cont. Pe iPhone și Mac interfața se schimbă. Textele din aplicația Windows rămân în română.";
            }
            catch (Exception ex)
            {
                status.Foreground = Brushes.IndianRed;
                status.Text = ex.Message;
            }
        };
        Content = Page("Limba aplicației", "Aceeași preferință ca pe iPhone și Mac.", combo, save, status);
    }

    internal static StackPanel Page(string title, string hint, params Control[] controls)
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 12, MaxWidth = 640 };
        page.Children.Add(new TextBlock { Text = title, FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        if (hint.Length > 0)
            page.Children.Add(new TextBlock { Text = hint, TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) });
        foreach (var control in controls)
            page.Children.Add(control);
        return page;
    }
}

public sealed class PasswordSettings : UserControl
{
    public PasswordSettings(AppSession session, SettingsHome home)
    {
        var password = new TextBox { PasswordChar = '•', Watermark = "Parolă nouă" };
        var status = new TextBlock { TextWrapping = TextWrapping.Wrap };
        var save = new Button { Content = "Actualizează parola", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) =>
        {
            try
            {
                await session.ChangePassword(password.Text ?? "");
                password.Text = "";
                status.Foreground = Brushes.DarkGreen;
                status.Text = "Parola a fost actualizată.";
            }
            catch (Exception ex)
            {
                status.Foreground = Brushes.IndianRed;
                status.Text = ex.Message;
            }
        };
        Content = new ScrollViewer { Content = LanguageSettings.Page("Schimbă parola", "Minim 6 caractere. Se aplică la următoarea autentificare.", password, save, status) };
    }
}

public sealed class SyncSettings : UserControl
{
    private readonly AppSession _session;
    private readonly TextBlock _status = new() { Text = "Se verifică conexiunea...", FontWeight = FontWeight.SemiBold };
    private readonly TextBlock _error = new() { TextWrapping = TextWrapping.Wrap, Foreground = Brushes.IndianRed };
    private readonly StackPanel _items = new() { Spacing = 8 };
    private readonly StackPanel _actions = new() { Spacing = 8 };

    public SyncSettings(AppSession session, SettingsHome home)
    {
        _session = session;
        var page = LanguageSettings.Page("Nesincronizate", "Documente salvate fără internet. Când revine conexiunea, se trimit singure.", _status, _error, _items, _actions);
        Content = new ScrollViewer { Content = page };
        OfflineSync.Changed += OnAutoSync;
        DetachedFromVisualTree += (_, _) => OfflineSync.Changed -= OnAutoSync;
        _ = Refresh();
    }

    private void OnAutoSync() => Dispatcher.UIThread.Post(() => _ = Refresh());

    private async Task Refresh()
    {
        try
        {
            await _session.SelectRows("companies", "select=id&limit=1");
            _status.Text = "Online";
            _status.Foreground = Brushes.DarkGreen;
            _error.Text = "";
        }
        catch (Exception ex)
        {
            _status.Text = "Fără internet";
            _status.Foreground = Brushes.IndianRed;
            _error.Text = ex.Message;
        }
        RenderItems();
    }

    private void RenderItems()
    {
        _items.Children.Clear();
        _actions.Children.Clear();
        var items = OfflineOutbox.Load();
        if (items.Count == 0)
        {
            _items.Children.Add(new TextBlock { Text = "Nu există documente în așteptare de sync.", Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap });
            return;
        }

        _items.Children.Add(new TextBlock { Text = "Operații în așteptare", FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        foreach (var item in items)
        {
            var card = new StackPanel { Spacing = 2 };
            card.Children.Add(new TextBlock { Text = item.Title, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
            card.Children.Add(new TextBlock { Text = item.Operation + " · " + item.Table, FontSize = 12, Foreground = Brand.Brush(Brand.Muted) });
            card.Children.Add(new TextBlock
            {
                Text = item.Status == "failed" ? "Eșuat" : "În așteptare",
                FontSize = 12,
                Foreground = item.Status == "failed" ? Brushes.IndianRed : Brand.Brush(Brand.Muted)
            });
            if (!string.IsNullOrWhiteSpace(item.Error))
                card.Children.Add(new TextBlock { Text = item.Error, FontSize = 12, Foreground = Brushes.IndianRed, TextWrapping = TextWrapping.Wrap });
            var discard = new Button { Content = "Renunță", HorizontalAlignment = HorizontalAlignment.Left, Margin = new Avalonia.Thickness(0, 4, 0, 0) };
            var id = item.Id;
            discard.Click += (_, _) =>
            {
                OfflineOutbox.Discard(id);
                RenderItems();
            };
            card.Children.Add(discard);
            _items.Children.Add(new Border
            {
                Background = Brushes.White,
                BorderBrush = Brand.Brush(Brand.Line),
                BorderThickness = new Avalonia.Thickness(1),
                CornerRadius = new Avalonia.CornerRadius(10),
                Padding = new Avalonia.Thickness(12),
                Child = card
            });
        }

        var retry = new Button { Content = "Reîncearcă eșuatele", HorizontalAlignment = HorizontalAlignment.Left, Padding = new Avalonia.Thickness(12, 8), Background = Brushes.White };
        retry.Click += async (_, _) =>
        {
            var pending = OfflineOutbox.Load().ToList();
            foreach (var item in pending.Where(item => item.Status == "failed"))
                item.Status = "pending";
            OfflineOutbox.Save(pending);
            await SyncNow();
        };
        var sync = new Button { Content = "Sincronizează acum", HorizontalAlignment = HorizontalAlignment.Left, Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White };
        sync.Click += async (_, _) => await SyncNow();
        _actions.Children.Add(retry);
        _actions.Children.Add(sync);
    }

    private async Task SyncNow()
    {
        _status.Text = "Se sincronizează…";
        _status.Foreground = Brand.Brush(Brand.Navy);
        var reached = await OfflineSync.Flush();
        await Refresh();
        if (!reached && OfflineOutbox.Load().Count > 0)
            _error.Text = "Nu există conexiune. Operațiile rămân în așteptare și pleacă singure când revine internetul.";
    }
}

public sealed class UsersSettings : UserControl
{
    private readonly AppSession _session;
    private readonly StackPanel _list = new() { Spacing = 8 };
    private readonly TextBlock _status = new() { TextWrapping = TextWrapping.Wrap };

    public UsersSettings(AppSession session, SettingsHome home)
    {
        _session = session;
        var add = new Button { Content = "Utilizator nou", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        add.Click += async (_, _) => await Create();
        var page = LanguageSettings.Page("Utilizatori", "Conturi, blocare și ștergere. Utilizatorul nou primește acces la societatea activă.", add, _status, _list);
        Content = new ScrollViewer { Content = page };
        _ = Reload();
    }

    private async Task Reload()
    {
        _list.Children.Clear();
        _status.Foreground = Brand.Brush(Brand.Muted);
        _status.Text = "Se încarcă...";
        try
        {
            var rows = await _session.SelectRows("user_profiles", "select=id,nume,prenume,email,is_admin,is_superadmin,is_blocked&order=created_at.desc");
            _status.Text = "";
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                _status.Text = "Nu există utilizatori.";
                return;
            }
            foreach (var row in rows.EnumerateArray())
            {
                var id = row.GetProperty("id").GetGuid();
                var name = $"{Text(row, "prenume")} {Text(row, "nume")}".Trim();
                var email = Text(row, "email");
                var super = Bool(row, "is_superadmin");
                var admin = Bool(row, "is_admin");
                var blocked = Bool(row, "is_blocked");
                var role = super ? "Superadmin" : admin ? "Admin" : "Utilizator";
                _list.Children.Add(Card(id, name, email, role, blocked, super));
            }
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private Control Card(Guid id, string name, string email, string role, bool blocked, bool super)
    {
        var panel = new StackPanel { Spacing = 4 };
        panel.Children.Add(new TextBlock { Text = name, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        panel.Children.Add(new TextBlock { Text = email + " · " + role + (blocked ? " · blocat" : ""), Foreground = Brand.Brush(Brand.Muted), FontSize = 12 });
        if (!super && id != _session.Profile?.Id)
        {
            var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            var block = new Button { Content = blocked ? "Deblochează" : "Blochează", Padding = new Avalonia.Thickness(10, 6) };
            block.Click += async (_, _) =>
            {
                try
                {
                    await _session.InvokeFunction("admin-toggle-block", new { user_id = id, is_blocked = !blocked });
                    await Reload();
                }
                catch (Exception ex)
                {
                    _status.Foreground = Brushes.IndianRed;
                    _status.Text = ex.Message;
                }
            };
            var delete = new Button { Content = "Șterge", Padding = new Avalonia.Thickness(10, 6) };
            delete.Click += async (_, _) =>
            {
                if (!await ConfirmDialog.Ask(this, "Ștergeți utilizatorul " + name + "?"))
                    return;
                try
                {
                    await _session.InvokeFunction("admin-delete-user", new { user_id = id });
                    await Reload();
                }
                catch (Exception ex)
                {
                    _status.Foreground = Brushes.IndianRed;
                    _status.Text = ex.Message;
                }
            };
            actions.Children.Add(block);
            actions.Children.Add(delete);
            panel.Children.Add(actions);
        }
        return new Border
        {
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(1),
            CornerRadius = new Avalonia.CornerRadius(10),
            Padding = new Avalonia.Thickness(12),
            Child = panel
        };
    }

    private async Task Create()
    {
        var company = _session.CurrentCompany;
        if (company == null)
        {
            _status.Text = "Selectați o societate înainte de a adăuga un utilizator.";
            return;
        }
        var nume = Box();
        var prenume = Box();
        var email = Box();
        var telefon = Box();
        var cnp = Box();
        cnp.Watermark = "13 cifre sau 0000000000000";
        var parola = Box();
        parola.PasswordChar = '•';
        var error = new TextBlock { Foreground = Brushes.IndianRed, TextWrapping = TextWrapping.Wrap };
        var form = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 8 };
        void Add(string label, TextBox field)
        {
            form.Children.Add(new TextBlock { Text = label, Foreground = Brand.Brush(Brand.Muted) });
            form.Children.Add(field);
        }
        Add("Nume", nume);
        Add("Prenume", prenume);
        Add("Email", email);
        Add("Telefon", telefon);
        Add("CNP", cnp);
        Add("Parolă", parola);
        form.Children.Add(error);
        var window = new Window
        {
            Title = "Utilizator nou",
            Width = 480,
            Height = 560,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Icon = Brand.WindowIcon(),
            Content = new ScrollViewer { Content = form }
        };
        var save = new Button { Content = "Creează contul", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) =>
        {
            error.Text = "";
            try
            {
                var modules = _session.Modules.Select(module => new
                {
                    module_id = module.Id,
                    can_view = true,
                    can_create = true,
                    can_edit = true,
                    can_delete = true
                }).ToArray();
                await _session.InvokeFunction("admin-create-user", new
                {
                    nume = nume.Text?.Trim() ?? "",
                    prenume = prenume.Text?.Trim() ?? "",
                    cnp = cnp.Text?.Trim() ?? "",
                    email = email.Text?.Trim() ?? "",
                    telefon = telefon.Text?.Trim() ?? "",
                    parola = parola.Text ?? "",
                    permissions = modules,
                    company_permissions = new[]
                    {
                        new { company_id = company.Id, can_view = true, can_create = true, can_edit = true, can_delete = true }
                    },
                    admin_email = _session.Profile?.Email ?? ""
                });
                window.Close();
                await Reload();
                _status.Foreground = Brushes.DarkGreen;
                _status.Text = "Contul a fost creat, cu acces la " + company.Denumire + ".";
            }
            catch (Exception ex)
            {
                error.Text = ex.Message;
            }
        };
        form.Children.Add(save);
        if (TopLevel.GetTopLevel(this) is Window owner)
            await window.ShowDialog(owner);
    }

    private static TextBox Box() => new();
    private static string Text(JsonElement row, string name) => row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : "";
    private static bool Bool(JsonElement row, string name) => row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;
}

public sealed class CompaniesSettings : UserControl
{
    private readonly AppSession _session;
    private readonly StackPanel _list = new() { Spacing = 8 };
    private readonly TextBlock _status = new() { TextWrapping = TextWrapping.Wrap };

    public CompaniesSettings(AppSession session, SettingsHome home)
    {
        _session = session;
        var add = new Button { Content = "Adaugă societate", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        add.Click += async (_, _) =>
        {
            if (await CompanyDialog.Create(this, session))
            {
                _status.Foreground = Brushes.DarkGreen;
                _status.Text = "Societatea a fost creată.";
                Fill();
            }
        };
        Content = new ScrollViewer { Content = LanguageSettings.Page("Administrare societăți", "Alegeți societatea activă, modificați denumirea sau CUI-ul, sau creați una nouă.", add, _status, _list) };
        Fill();
    }

    private void Fill()
    {
        _list.Children.Clear();
        foreach (var company in _session.Companies.OrderBy(item => item.Denumire))
        {
            var current = _session.CurrentCompany?.Id == company.Id;
            var panel = new StackPanel { Spacing = 6 };
            panel.Children.Add(new TextBlock { Text = company.Denumire + (current ? " · activă" : ""), FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
            panel.Children.Add(new TextBlock { Text = string.IsNullOrWhiteSpace(company.Cui) ? "Fără CUI" : "CUI " + company.Cui, Foreground = Brand.Brush(Brand.Muted), FontSize = 12 });
            var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            if (!current)
            {
                var use = new Button { Content = "Folosește", Padding = new Avalonia.Thickness(10, 6) };
                use.Click += async (_, _) => await _session.SelectCompany(company);
                actions.Children.Add(use);
            }
            var edit = new Button { Content = "Modifică", Padding = new Avalonia.Thickness(10, 6) };
            edit.Click += async (_, _) => await Edit(company);
            actions.Children.Add(edit);
            panel.Children.Add(actions);
            _list.Children.Add(new Border
            {
                Background = Brushes.White,
                BorderBrush = Brand.Brush(Brand.Line),
                BorderThickness = new Avalonia.Thickness(1),
                CornerRadius = new Avalonia.CornerRadius(10),
                Padding = new Avalonia.Thickness(12),
                Child = panel
            });
        }
    }

    private async Task Edit(CompanyRow company)
    {
        var denumire = new TextBox { Text = company.Denumire };
        var cui = new TextBox { Text = company.Cui ?? "" };
        var error = new TextBlock { Foreground = Brushes.IndianRed, TextWrapping = TextWrapping.Wrap };
        var form = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 8 };
        form.Children.Add(new TextBlock { Text = "Denumire", Foreground = Brand.Brush(Brand.Muted) });
        form.Children.Add(denumire);
        form.Children.Add(new TextBlock { Text = "CUI", Foreground = Brand.Brush(Brand.Muted) });
        form.Children.Add(cui);
        form.Children.Add(error);
        var window = new Window { Title = "Modifică societatea", Width = 440, Height = 280, WindowStartupLocation = WindowStartupLocation.CenterOwner, Icon = Brand.WindowIcon(), Content = form };
        var save = new Button { Content = "Salvează", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) =>
        {
            try
            {
                await _session.UpdateCompany(company.Id, denumire.Text ?? "", cui.Text);
                window.Close();
                Fill();
            }
            catch (Exception ex)
            {
                error.Text = ex.Message;
            }
        };
        form.Children.Add(save);
        if (TopLevel.GetTopLevel(this) is Window owner)
            await window.ShowDialog(owner);
    }
}
