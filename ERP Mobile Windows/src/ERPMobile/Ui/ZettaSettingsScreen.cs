using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class ZettaSettingsScreen : UserControl
{
    private static readonly (string Code, string Label, string Account, bool Fixed)[] Sales =
    [
        ("marfa", "Marfă", "707", false),
        ("produse_finite", "Produse finite", "7015", false),
        ("servicii", "Servicii", "704", false),
        ("chirii", "Chirii", "706", false),
        ("venituri_diverse", "Venituri diverse", "708", false),
        ("sgr", "SGR", "267", true),
        ("bacsis", "Bacșiș", "462", true)
    ];

    private readonly AppSession _session;
    private readonly CheckBox _shifts = new() { Content = "Societatea are mai multe ture pe o casă de marcat?" };
    private readonly ComboBox _shiftCount = new() { ItemsSource = Enumerable.Range(2, 9).Select(n => n.ToString()).ToList(), SelectedIndex = 0, Width = 80 };
    private readonly CheckBox _multiLocation = new() { Content = "Societatea folosește case de marcat pe mai multe puncte de lucru?" };
    private readonly TextBox _headquarters = new() { Text = "5311.0" };
    private readonly TextBox _card = new() { Text = "5125" };
    private readonly TextBox _modern = new() { Text = "5113" };
    private readonly StackPanel _locations = new() { Spacing = 8 };
    private readonly StackPanel _vats = new() { Spacing = 12 };
    private readonly TextBlock _status = new() { TextWrapping = TextWrapping.Wrap };
    private readonly List<LocationRow> _locationRows = [];
    private readonly List<VatRow> _vatRows = [];

    public ZettaSettingsScreen(AppSession session, SettingsHome home)
    {
        _session = session;
        var save = new Button { Content = "Salvează setările Zetta", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) => await Save();
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 12, MaxWidth = 720 };
        page.Children.Add(new TextBlock { Text = "Setări Zetta", FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        page.Children.Add(new TextBlock { Text = "Case de marcat, conturi casă și cote TVA pentru raportul Z. Se salvează pe societatea activă.", TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) });
        page.Children.Add(Section("Case de marcat — ture", _shifts, _shiftCount));
        page.Children.Add(Section("Puncte de lucru", _multiLocation, _locations));
        page.Children.Add(Section("Casa sediu", Label("Cont casă sediu"), _headquarters));
        page.Children.Add(Section("Metode de încasare", Label("Cont încasare CARD"), _card, Label("Cont încasare PLATA MODERNA"), _modern));
        page.Children.Add(_vats);
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
            var locations = await _session.SelectRows("company_work_locations", "company_id=eq." + company.Id + "&select=id,denumire&order=denumire.asc");
            var settingsRows = await _session.SelectRows("company_zetta_settings", "company_id=eq." + company.Id + "&select=settings");
            JsonElement settings = default;
            var hasSettings = settingsRows.ValueKind == JsonValueKind.Array && settingsRows.GetArrayLength() > 0
                && settingsRows[0].TryGetProperty("settings", out settings)
                && settings.ValueKind == JsonValueKind.Object;

            _shifts.IsChecked = hasSettings && Bool(settings, "multipleShiftsPerRegister");
            var shifts = hasSettings && Int(settings, "shiftsPerRegisterCount") is int count ? count : 2;
            _shiftCount.SelectedIndex = Math.Clamp(shifts - 2, 0, 8);
            _multiLocation.IsChecked = hasSettings && Bool(settings, "usesRegistersOnMultipleWorkLocations");
            _headquarters.Text = hasSettings ? Text(settings, "headquartersCasaAccount", "5311.0") : "5311.0";
            _card.Text = hasSettings ? Text(settings, "cardPaymentAccount", "5125") : "5125";
            _modern.Text = hasSettings ? Text(settings, "modernPaymentAccount", "5113") : "5113";

            var accounts = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (hasSettings && settings.TryGetProperty("locationCasaAccounts", out var stored) && stored.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in stored.EnumerateArray())
                {
                    var id = Text(item, "workLocationId", "");
                    if (id.Length > 0)
                        accounts[id] = Text(item, "account", "5311");
                }
            }

            _locations.Children.Clear();
            _locationRows.Clear();
            if (locations.ValueKind != JsonValueKind.Array || locations.GetArrayLength() == 0)
            {
                _locations.Children.Add(new TextBlock { Text = "Nu există niciun punct de lucru. Creați unul în Nomenclatoare.", TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) });
            }
            else
            {
                var index = 0;
                foreach (var row in locations.EnumerateArray())
                {
                    var id = row.GetProperty("id").GetString() ?? "";
                    var name = Text(row, "denumire", "Punct de lucru");
                    var account = accounts.TryGetValue(id, out var saved) ? saved : locations.GetArrayLength() == 1 ? "5311" : "5311." + (index + 1);
                    var box = new TextBox { Text = account };
                    _locationRows.Add(new LocationRow(id, box));
                    _locations.Children.Add(new TextBlock { Text = name, FontWeight = FontWeight.SemiBold });
                    _locations.Children.Add(Label("Cont casă în lei (5311)"));
                    _locations.Children.Add(box);
                    index++;
                }
            }

            _vats.Children.Clear();
            _vatRows.Clear();
            foreach (var slot in new[] { "A", "B", "C", "D" })
            {
                var enabled = slot == "A";
                var rate = slot switch { "A" => 21, "B" => 11, "C" => 5, _ => 0 };
                var category = "";
                var account = "";
                if (hasSettings && settings.TryGetProperty("vatCategories", out var categories) && categories.TryGetProperty(slot, out var vat))
                {
                    enabled = Bool(vat, "isEnabled");
                    rate = Int(vat, "rate") ?? rate;
                    if (vat.TryGetProperty("salesMappings", out var mappings) && mappings.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var mapping in mappings.EnumerateArray())
                        {
                            if (!Bool(mapping, "isEnabled"))
                                continue;
                            category = Text(mapping, "category", "");
                            account = Text(mapping, "account", "");
                            break;
                        }
                    }
                }
                var row = new VatRow(slot, enabled, rate, category, account);
                _vatRows.Add(row);
                _vats.Children.Add(row.Panel());
            }
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
            var locationAccounts = _locationRows.Select(row => new Dictionary<string, object?>
            {
                ["workLocationId"] = row.Id,
                ["account"] = row.Account.Text?.Trim() ?? ""
            }).ToList();
            var vat = new Dictionary<string, object?>();
            foreach (var row in _vatRows)
                vat[row.Slot] = row.Payload();
            var settings = new Dictionary<string, object?>
            {
                ["multipleShiftsPerRegister"] = _shifts.IsChecked == true,
                ["shiftsPerRegisterCount"] = 2 + Math.Max(0, _shiftCount.SelectedIndex),
                ["usesRegistersOnMultipleWorkLocations"] = _multiLocation.IsChecked == true,
                ["headquartersCasaAccount"] = _headquarters.Text?.Trim() ?? "",
                ["locationCasaAccounts"] = locationAccounts,
                ["cardPaymentAccount"] = _card.Text?.Trim() ?? "",
                ["modernPaymentAccount"] = _modern.Text?.Trim() ?? "",
                ["vatCategories"] = vat
            };
            await _session.UpsertRow("company_zetta_settings", new Dictionary<string, object?>
            {
                ["company_id"] = company.Id,
                ["settings"] = settings
            }, "company_id");
            _status.Foreground = Brushes.DarkGreen;
            _status.Text = "Setările Zetta au fost salvate.";
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private static Control Section(string title, params Control[] children)
    {
        var panel = new StackPanel { Spacing = 8 };
        panel.Children.Add(new TextBlock { Text = title, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        foreach (var child in children)
            panel.Children.Add(child);
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

    private static TextBlock Label(string text) => new() { Text = text, Foreground = Brand.Brush(Brand.Muted), FontSize = 12 };
    private static bool Bool(JsonElement row, string name) => row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;
    private static int? Int(JsonElement row, string name) => row.TryGetProperty(name, out var value) && value.TryGetInt32(out var number) ? number : null;
    private static string Text(JsonElement row, string name, string fallback) =>
        row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? fallback : fallback;

    private sealed record LocationRow(string Id, TextBox Account);

    private sealed class VatRow
    {
        public string Slot { get; }
        private readonly CheckBox _enabled;
        private readonly ComboBox _rate;
        private readonly ComboBox _category;
        private readonly TextBox _account;

        public VatRow(string slot, bool enabled, int rate, string category, string account)
        {
            Slot = slot;
            _enabled = new CheckBox { Content = "Folosită", IsChecked = enabled };
            _rate = new ComboBox { ItemsSource = new[] { "0%", "5%", "11%", "21%" }, SelectedIndex = rate switch { 5 => 1, 11 => 2, 21 => 3, _ => 0 }, HorizontalAlignment = HorizontalAlignment.Left, MinWidth = 100 };
            var labels = Sales.Select(item => item.Label).Prepend("— Alegeți —").ToList();
            _category = new ComboBox { ItemsSource = labels, HorizontalAlignment = HorizontalAlignment.Stretch };
            var match = Array.FindIndex(Sales, item => item.Code == category);
            _category.SelectedIndex = match < 0 ? 0 : match + 1;
            var initial = account;
            if (initial.Length == 0 && match >= 0)
                initial = Sales[match].Account;
            _account = new TextBox { Text = initial };
            _category.SelectionChanged += (_, _) =>
            {
                var index = _category.SelectedIndex - 1;
                if (index < 0)
                    return;
                if (Sales[index].Fixed || string.IsNullOrWhiteSpace(_account.Text))
                    _account.Text = Sales[index].Account;
                _account.IsReadOnly = Sales[index].Fixed;
            };
            if (match >= 0)
                _account.IsReadOnly = Sales[match].Fixed;
        }

        public Control Panel()
        {
            var stack = new StackPanel { Spacing = 6 };
            stack.Children.Add(new TextBlock { Text = "Cota " + Slot + " — Raport Z", FontWeight = FontWeight.SemiBold });
            stack.Children.Add(_enabled);
            stack.Children.Add(Label("Cota TVA"));
            stack.Children.Add(_rate);
            stack.Children.Add(Label("Tip vânzare pe această cotă"));
            stack.Children.Add(_category);
            stack.Children.Add(Label("Cont"));
            stack.Children.Add(_account);
            return new Border
            {
                Background = Brushes.White,
                BorderBrush = Brand.Brush(Brand.Line),
                BorderThickness = new Avalonia.Thickness(1),
                CornerRadius = new Avalonia.CornerRadius(10),
                Padding = new Avalonia.Thickness(12),
                Child = stack
            };
        }

        public Dictionary<string, object?> Payload()
        {
            var index = _category.SelectedIndex - 1;
            var mappings = new List<Dictionary<string, object?>>();
            foreach (var sale in Sales)
            {
                var selected = index >= 0 && Sales[index].Code == sale.Code;
                mappings.Add(new Dictionary<string, object?>
                {
                    ["category"] = sale.Code,
                    ["account"] = selected ? (_account.Text?.Trim() ?? sale.Account) : sale.Account,
                    ["isEnabled"] = selected
                });
            }
            var rate = _rate.SelectedIndex switch { 1 => 5, 2 => 11, 3 => 21, _ => 0 };
            return new Dictionary<string, object?>
            {
                ["isEnabled"] = _enabled.IsChecked == true,
                ["rate"] = rate,
                ["salesMappings"] = mappings
            };
        }

        private static TextBlock Label(string text) => new() { Text = text, Foreground = Brand.Brush(Brand.Muted), FontSize = 12 };
    }
}
