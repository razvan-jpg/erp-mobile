using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Data;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class NomenclatoareHome : UserControl
{
    private readonly AppSession _session;
    private readonly AppModule _module;
    private readonly Border _host = new();

    public NomenclatoareHome(AppSession session, AppModule module)
    {
        _session = session;
        _module = module;
        Content = _host;
        ShowTiles();
    }

    private void ShowTiles()
    {
        var wrap = new WrapPanel();
        wrap.Children.Add(SectionHome.Tile("Societăți", "Date societăți, parametrizare, puncte de lucru și depozite.", () => Open(Companies)));
        wrap.Children.Add(SectionHome.Tile("Parteneri", "Furnizori, clienți și alți parteneri comerciali.", () => Open(Partners)));
        wrap.Children.Add(SectionHome.Tile("Catalog", "Grupe CM pentru vânzare casă marcat și produsele din catalogul de vânzare.", () => Open(() => Lists("Catalog", CatalogLists()))));
        wrap.Children.Add(SectionHome.Tile("Articole", "Fișe articole, coduri de bare și prețuri.", () => Open(() => Lists("Articole", ArticleLists()))));
        wrap.Children.Add(SectionHome.Tile("Persoane", "Persoane de contact și reprezentanți.", () => Open(() => Developing("Persoane"))));
        wrap.Children.Add(SectionHome.Tile("Conturi", "Plan de conturi și conturi analitice.", () => Open(() => Developing("Conturi"))));
        _host.Child = new ScrollViewer { Content = new StackPanel { Margin = new Avalonia.Thickness(20), Children = { wrap } } };
    }

    private void Open(Func<Control> page) => Dispatcher.UIThread.Post(() =>
    {
        var root = new DockPanel();
        var back = new Button
        {
            Content = "← Nomenclatoare",
            Margin = new Avalonia.Thickness(20, 12, 20, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brushes.White
        };
        back.Click += (_, _) => Dispatcher.UIThread.Post(ShowTiles);
        DockPanel.SetDock(back, Dock.Top);
        root.Children.Add(back);
        root.Children.Add(page());
        _host.Child = root;
    });

    private Control Companies()
    {
        var host = new Border();
        var tabs = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Avalonia.Thickness(20, 8, 20, 0) };
        void Select(string title, Func<Control> body)
        {
            var button = new Button { Content = title, Padding = new Avalonia.Thickness(12, 8), Background = Brushes.White };
            button.Click += (_, _) => Dispatcher.UIThread.Post(() =>
            {
                foreach (var child in tabs.Children.OfType<Button>())
                {
                    child.Background = Brushes.White;
                    child.Foreground = Brand.Brush(Brand.Navy);
                }
                button.Background = Brand.Brush(Brand.Navy);
                button.Foreground = Brushes.White;
                host.Child = body();
            });
            tabs.Children.Add(button);
        }
        Select("Parametrizare", () => new CompanyParametrizareForm(_session));
        Select("Serii documente", () => new DocumentSeriesView(_session));
        Select("Puncte de lucru", () => Lists("Puncte de lucru", Named("Puncte de lucru")));
        Select("Depozite", () => Lists("Depozite", Named("Depozite")));
        var root = new DockPanel();
        DockPanel.SetDock(tabs, Dock.Top);
        root.Children.Add(tabs);
        root.Children.Add(host);
        host.Child = new CompanyParametrizareForm(_session);
        if (tabs.Children[0] is Button first)
        {
            first.Background = Brand.Brush(Brand.Navy);
            first.Foreground = Brushes.White;
        }
        return root;
    }

    private Control Partners()
    {
        var suppliers = ModuleCatalog.ForModule("supplier_invoices_payments").Where(list => list.Title == "Furnizori").ToList();
        var clients = ModuleCatalog.ForModule("client_invoices_payments").Where(list => list.Title == "Clienți").ToList();
        return new ModuleHost(_session, _module, suppliers.Concat(clients).ToList(), "Furnizori și clienți ai societății active.");
    }

    private Control Lists(string title, IReadOnlyList<ListSpec> lists) => new ModuleHost(_session, _module, lists, title);
    private static Control Developing(string title) => new TextBlock { Text = title + " — modul în dezvoltare.", Margin = new Avalonia.Thickness(24), FontSize = 16, Foreground = Brand.Brush(Brand.Navy) };

    private static IReadOnlyList<ListSpec> Named(string title) =>
        ModuleCatalog.ForModule("nomenclatoare").Where(list => list.Title == title).ToList();

    private static IReadOnlyList<ListSpec> CatalogLists() =>
        ModuleCatalog.ForModule("nomenclatoare").Where(list => list.Title == "Grupe catalog").ToList();

    private static IReadOnlyList<ListSpec> ArticleLists() =>
        ModuleCatalog.ForModule("nomenclatoare").Where(list => list.Title == "Produse").ToList();
}

public sealed class CompanyParametrizareForm : UserControl
{
    private readonly AppSession _session;
    private readonly TextBlock _status = new() { TextWrapping = TextWrapping.Wrap };
    private readonly Dictionary<string, TextBox> _fields = new();
    private readonly CheckBox _tva = new() { Content = "Plătitor de TVA" };
    private readonly CheckBox _split = new() { Content = "TVA la încasare" };

    public CompanyParametrizareForm(AppSession session)
    {
        _session = session;
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 10, MaxWidth = 720 };
        page.Children.Add(Header("Identitate societate"));
        page.Children.Add(Field("denumire", "Nume societate"));
        page.Children.Add(Field("cui", "CIF / CNP"));
        page.Children.Add(Field("nr_reg_com", "Nr. Reg. Com."));
        page.Children.Add(Field("cod_caen", "Cod CAEN"));
        page.Children.Add(Field("capital_social", "Capital social"));
        page.Children.Add(Field("cod_lei", "Cod LEI"));
        page.Children.Add(_tva);
        page.Children.Add(_split);
        page.Children.Add(Header("Contact"));
        page.Children.Add(Field("telefon", "Telefon"));
        page.Children.Add(Field("fax", "Fax"));
        page.Children.Add(Field("email", "Email"));
        page.Children.Add(Field("web", "Web"));
        page.Children.Add(Field("iban", "IBAN"));
        page.Children.Add(Header("Sediu"));
        page.Children.Add(Field("hq_county", "Județ"));
        page.Children.Add(Field("hq_city", "Localitate"));
        page.Children.Add(Field("hq_street", "Stradă"));
        page.Children.Add(Field("hq_street_number", "Număr"));
        page.Children.Add(Field("adresa", "Adresă"));
        var save = new Button { Content = "Salvează", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) => await Save();
        page.Children.Add(save);
        page.Children.Add(_status);
        Content = new ScrollViewer { Content = page };
        _ = Load();
    }

    private async Task Load()
    {
        var company = _session.CurrentCompany;
        if (company == null)
        {
            _status.Text = "Selectați o societate.";
            return;
        }
        try
        {
            var rows = await _session.SelectRows("companies", "id=eq." + company.Id + "&select=*");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
                return;
            var row = rows[0];
            foreach (var (name, box) in _fields)
                box.Text = Text(row, name);
            _tva.IsChecked = Bool(row, "platitor_tva");
            _split.IsChecked = Bool(row, "split_tva");
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private async Task Save()
    {
        var company = _session.CurrentCompany;
        if (company == null)
            return;
        try
        {
            var payload = _fields.ToDictionary(pair => pair.Key, pair => (object?)(string.IsNullOrWhiteSpace(pair.Value.Text) ? null : pair.Value.Text.Trim()));
            payload["platitor_tva"] = _tva.IsChecked == true;
            payload["split_tva"] = _split.IsChecked == true;
            await _session.UpdateRow("companies", company.Id.ToString(), payload);
            await _session.RefreshCompanies();
            _status.Foreground = Brushes.DarkGreen;
            _status.Text = "Datele societății au fost salvate.";
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private Control Field(string name, string label)
    {
        var box = new TextBox();
        _fields[name] = box;
        var stack = new StackPanel { Spacing = 4 };
        stack.Children.Add(new TextBlock { Text = label, FontSize = 12, Foreground = Brand.Brush(Brand.Muted) });
        stack.Children.Add(box);
        return stack;
    }

    private static Control Header(string text) => new TextBlock { Text = text, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy), Margin = new Avalonia.Thickness(0, 8, 0, 0) };
    private static string Text(JsonElement row, string name) => row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : "";
    private static bool Bool(JsonElement row, string name) => row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;
}

public sealed class HrSettingsForm : UserControl
{
    private readonly AppSession _session;
    private readonly TextBox _expense = new() { Text = "641" };
    private readonly TextBox _payable = new() { Text = "421" };
    private readonly TextBox _cas = new() { Text = "431" };
    private readonly TextBox _tax = new() { Text = "444" };
    private readonly TextBox _journal = new() { Text = "OD" };
    private readonly TextBox _first = new() { Text = "1" };
    private readonly CheckBox _oneNote = new() { Content = "O notă pe angajat" };
    private readonly TextBlock _status = new() { TextWrapping = TextWrapping.Wrap };

    public HrSettingsForm(AppSession session)
    {
        _session = session;
        var save = new Button { Content = "Salvează setările HR", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) => await Save();
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 8, MaxWidth = 520 };
        page.Children.Add(new TextBlock { Text = "Setări HR", FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        page.Children.Add(Label("Cont cheltuială", _expense));
        page.Children.Add(Label("Cont salarii datorate", _payable));
        page.Children.Add(Label("Cont CAS", _cas));
        page.Children.Add(Label("Cont impozit", _tax));
        page.Children.Add(Label("Jurnal", _journal));
        page.Children.Add(Label("Primul număr de notă", _first));
        page.Children.Add(_oneNote);
        page.Children.Add(save);
        page.Children.Add(_status);
        Content = new ScrollViewer { Content = page };
        _ = Load();
    }

    private async Task Load()
    {
        var company = _session.CurrentCompany;
        if (company == null)
            return;
        try
        {
            var rows = await _session.SelectRows("hr_settings", "company_id=eq." + company.Id + "&select=*");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
                return;
            var row = rows[0];
            _expense.Text = Text(row, "expense_account", "641");
            _payable.Text = Text(row, "payable_account", "421");
            _cas.Text = Text(row, "cas_account", "431");
            _tax.Text = Text(row, "tax_account", "444");
            _journal.Text = Text(row, "journal", "OD");
            _first.Text = row.TryGetProperty("first_note_number", out var number) && number.TryGetInt32(out var value) ? value.ToString() : "1";
            _oneNote.IsChecked = row.TryGetProperty("one_note_per_employee", out var flag) && flag.ValueKind == JsonValueKind.True;
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
    }

    private async Task Save()
    {
        var company = _session.CurrentCompany;
        if (company == null)
            return;
        if (!int.TryParse(_first.Text?.Trim(), out var first) || first < 1)
        {
            _status.Text = "Primul număr de notă trebuie să fie cel puțin 1.";
            return;
        }
        try
        {
            await _session.UpsertRow("hr_settings", new Dictionary<string, object?>
            {
                ["company_id"] = company.Id,
                ["expense_account"] = _expense.Text?.Trim(),
                ["payable_account"] = _payable.Text?.Trim(),
                ["cas_account"] = _cas.Text?.Trim(),
                ["tax_account"] = _tax.Text?.Trim(),
                ["journal"] = _journal.Text?.Trim(),
                ["first_note_number"] = first,
                ["one_note_per_employee"] = _oneNote.IsChecked == true
            }, "company_id");
            _status.Foreground = Brushes.DarkGreen;
            _status.Text = "Setările HR au fost salvate.";
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private static Control Label(string title, Control field)
    {
        var stack = new StackPanel { Spacing = 4 };
        stack.Children.Add(new TextBlock { Text = title, FontSize = 12, Foreground = Brand.Brush(Brand.Muted) });
        stack.Children.Add(field);
        return stack;
    }

    private static string Text(JsonElement row, string name, string fallback) =>
        row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? fallback : fallback;
}
