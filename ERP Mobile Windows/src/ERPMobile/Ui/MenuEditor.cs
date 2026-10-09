using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class MenuEditor : Window
{
    private readonly AppSession _session;
    private readonly string? _menuId;
    private readonly TextBox _name = new() { Watermark = "Denumire meniu" };
    private readonly TextBox _price = new() { Watermark = "Preț vânzare" };
    private readonly CheckBox _active = new() { Content = "Activ", IsChecked = true };
    private readonly CheckBox _multiple = new() { Content = "La vânzare se pot alege mai multe produse secundare" };
    private readonly TextBlock _code = new() { TextWrapping = TextWrapping.Wrap };
    private readonly ComboBox _main = new() { MinWidth = 280, HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ComboBox _required = new() { MinWidth = 280, HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly StackPanel _optionals = new() { Spacing = 8 };
    private readonly TextBlock _error = new() { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
    private readonly List<ProductPick> _products = new();
    private bool _saved;

    private MenuEditor(AppSession session, string? menuId)
    {
        _session = session;
        _menuId = menuId;
        Title = menuId == null ? "Meniu nou" : "Meniu";
        Width = 560;
        Height = 720;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Icon = Brand.WindowIcon();
        Background = Brand.Brush(Brand.Page);
        Build();
        Opened += async (_, _) =>
        {
            try
            {
                await Load();
            }
            catch (Exception ex)
            {
                _error.Text = ex.Message;
            }
        };
    }

    public static async Task<bool> Show(Control owner, AppSession session, string? menuId)
    {
        if (session.CurrentCompany == null)
            return false;
        var window = new MenuEditor(session, menuId);
        var parent = TopLevel.GetTopLevel(owner) as Window;
        if (parent == null && Avalonia.Application.Current?.ApplicationLifetime is Avalonia.Controls.ApplicationLifetimes.IClassicDesktopStyleApplicationLifetime desktop)
            parent = desktop.MainWindow;
        if (parent != null)
            await window.ShowDialog(parent);
        else
        {
            var closed = new TaskCompletionSource();
            window.Closed += (_, _) => closed.TrySetResult();
            window.Show();
            await closed.Task;
        }
        return window._saved;
    }

    private void Build()
    {
        var root = new DockPanel { Margin = new Avalonia.Thickness(20) };
        var actions = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Avalonia.Thickness(0, 12, 0, 0)
        };
        var cancel = new Button { Content = "Renunță", Padding = new Avalonia.Thickness(14, 8) };
        cancel.Click += (_, _) => Close();
        var save = new Button
        {
            Content = "Salvează",
            Padding = new Avalonia.Thickness(14, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        save.Click += async (_, _) => await Save();
        actions.Children.Add(cancel);
        actions.Children.Add(save);
        DockPanel.SetDock(actions, Dock.Bottom);
        root.Children.Add(actions);
        DockPanel.SetDock(_error, Dock.Bottom);
        root.Children.Add(_error);

        var form = new StackPanel { Spacing = 10 };
        form.Children.Add(Label("Denumire"));
        form.Children.Add(_name);
        form.Children.Add(Label("Preț vânzare"));
        form.Children.Add(_price);
        form.Children.Add(_code);
        form.Children.Add(_active);
        form.Children.Add(_multiple);
        form.Children.Add(Label("Produs principal"));
        form.Children.Add(_main);
        form.Children.Add(Label("Produs secundar obligatoriu"));
        form.Children.Add(_required);
        form.Children.Add(Label("Produse secundare opționale (cel mult 10)"));
        form.Children.Add(_optionals);
        var add = new Button { Content = "Adaugă produs opțional", HorizontalAlignment = HorizontalAlignment.Left };
        add.Click += (_, _) =>
        {
            if (_optionals.Children.Count >= 10)
                return;
            _optionals.Children.Add(OptionalRow(null));
        };
        form.Children.Add(add);
        root.Children.Add(new ScrollViewer { Content = form });
        Content = root;
    }

    private static TextBlock Label(string text) => new()
    {
        Text = text,
        FontWeight = FontWeight.SemiBold,
        Foreground = Brand.Brush(Brand.Navy)
    };

    private async Task Load()
    {
        if (_session.CurrentCompany == null)
            return;
        var company = _session.CurrentCompany.Id;
        var products = await _session.SelectRows(
            "products",
            $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
        _products.Clear();
        if (products.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in products.EnumerateArray())
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var productId))
                    continue;
                _products.Add(new ProductPick(productId, Text(row, "denumire")));
            }
        }
        Fill(_main, null);
        Fill(_required, null);
        if (_menuId == null)
        {
            _code.Text = "Codul de produs se alocă automat și este unic.";
            return;
        }
        var menus = await _session.SelectRows("cm_menus", "id=eq." + _menuId + "&select=name,pret_vanzare,is_active,cod,permite_secundare_multiple");
        if (menus.ValueKind == JsonValueKind.Array && menus.GetArrayLength() > 0)
        {
            var menu = menus[0];
            _name.Text = Text(menu, "name");
            _price.Text = Number(menu, "pret_vanzare").ToString("0.##", CultureInfo.GetCultureInfo("ro-RO"));
            _active.IsChecked = menu.TryGetProperty("is_active", out var flag) && flag.ValueKind == JsonValueKind.True;
            _multiple.IsChecked = menu.TryGetProperty("permite_secundare_multiple", out var many) && many.ValueKind == JsonValueKind.True;
            var code = Text(menu, "cod");
            _code.Text = string.IsNullOrWhiteSpace(code) ? "" : "Cod produs: " + code;
        }
        var lines = await _session.SelectRows(
            "cm_menu_lines",
            "menu_id=eq." + _menuId + "&select=product_id,role,is_required,sort_order&order=sort_order.asc");
        if (lines.ValueKind != JsonValueKind.Array)
            return;
        foreach (var line in lines.EnumerateArray())
        {
            if (!line.TryGetProperty("product_id", out var product) || !product.TryGetGuid(out var productId))
                continue;
            var role = Text(line, "role");
            var required = line.TryGetProperty("is_required", out var req) && req.ValueKind == JsonValueKind.True;
            if (role == "main")
                Fill(_main, productId);
            else if (required)
                Fill(_required, productId);
            else if (_optionals.Children.Count < 10)
                _optionals.Children.Add(OptionalRow(productId));
        }
    }

    private Control OptionalRow(Guid? productId)
    {
        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var combo = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch };
        Fill(combo, productId);
        var trash = new Button
        {
            Content = "🗑",
            Margin = new Avalonia.Thickness(8, 0, 0, 0),
            Background = Brushes.Transparent,
            Foreground = Brushes.Firebrick,
            BorderThickness = new Avalonia.Thickness(0)
        };
        trash.Click += (_, _) => _optionals.Children.Remove(row);
        Grid.SetColumn(trash, 1);
        row.Children.Add(combo);
        row.Children.Add(trash);
        return row;
    }

    private void Fill(ComboBox combo, Guid? selected)
    {
        combo.Items.Clear();
        combo.Items.Add(new ProductPick(Guid.Empty, "Alegeți produsul"));
        foreach (var product in _products)
            combo.Items.Add(product);
        combo.SelectedItem = combo.Items.OfType<ProductPick>().FirstOrDefault(item => item.Id == selected)
            ?? combo.Items[0];
    }

    private async Task Save()
    {
        _error.Text = "";
        if (_session.CurrentCompany == null)
            return;
        var name = _name.Text?.Trim() ?? "";
        if (name.Length == 0 || !TryPrice(_price.Text, out var price))
        {
            _error.Text = "Completați denumirea și prețul.";
            return;
        }
        var main = (_main.SelectedItem as ProductPick)?.Id ?? Guid.Empty;
        var required = (_required.SelectedItem as ProductPick)?.Id ?? Guid.Empty;
        var optionals = new List<Guid>();
        foreach (var child in _optionals.Children.OfType<Grid>())
        {
            var pick = child.Children.OfType<ComboBox>().FirstOrDefault()?.SelectedItem as ProductPick;
            if (pick != null && pick.Id != Guid.Empty)
                optionals.Add(pick.Id);
        }
        var ids = new List<Guid> { main, required };
        ids.AddRange(optionals);
        if (main == Guid.Empty || required == Guid.Empty || ids.Distinct().Count() != ids.Count || optionals.Count > 10)
        {
            _error.Text = "Meniul are un produs principal și produse secundare: unul obligatoriu și cel mult 10 opționale. Același produs nu se repetă.";
            return;
        }
        try
        {
            var company = _session.CurrentCompany.Id;
            var menuId = _menuId ?? Guid.NewGuid().ToString();
            var menu = new Dictionary<string, object?>
            {
                ["name"] = name,
                ["pret_vanzare"] = price.ToString(CultureInfo.InvariantCulture),
                ["is_active"] = _active.IsChecked == true,
                ["permite_secundare_multiple"] = _multiple.IsChecked == true
            };
            if (_menuId == null)
            {
                menu["id"] = menuId;
                menu["company_id"] = company;
                menu["sort_order"] = 0;
                menu["cod"] = await NextCode(company.ToString() ?? "");
                await _session.InsertRow("cm_menus", menu, queueOnFailure: false);
            }
            else
            {
                await _session.UpdateRow("cm_menus", menuId, menu, queueOnFailure: false);
                var existing = await _session.SelectRows("cm_menu_lines", "menu_id=eq." + menuId + "&select=id");
                if (existing.ValueKind == JsonValueKind.Array)
                {
                    foreach (var line in existing.EnumerateArray())
                    {
                        var id = Text(line, "id");
                        if (id.Length > 0)
                            await _session.DeleteRow("cm_menu_lines", id, queueOnFailure: false);
                    }
                }
            }
            var sort = 0;
            await InsertLine(company, menuId, main, "main", true, sort++);
            await InsertLine(company, menuId, required, "secondary", true, sort++);
            foreach (var productId in optionals)
                await InsertLine(company, menuId, productId, "secondary", false, sort++);
            _saved = true;
            Close();
        }
        catch (Exception ex)
        {
            _error.Text = ex.Message;
        }
    }

    private async Task InsertLine(Guid company, string menuId, Guid productId, string role, bool required, int sort)
    {
        await _session.InsertRow("cm_menu_lines", new Dictionary<string, object?>
        {
            ["id"] = Guid.NewGuid().ToString(),
            ["company_id"] = company,
            ["menu_id"] = menuId,
            ["product_id"] = productId.ToString(),
            ["cantitate"] = "1",
            ["sort_order"] = sort,
            ["role"] = role,
            ["is_required"] = required
        }, queueOnFailure: false);
    }

    private async Task<string> NextCode(string company)
    {
        var used = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var table in new[] { "products", "cm_menus" })
        {
            var rows = await _session.SelectRows(table, "company_id=eq." + company + "&select=cod");
            if (rows.ValueKind != JsonValueKind.Array)
                continue;
            foreach (var row in rows.EnumerateArray())
            {
                var code = Text(row, "cod").Trim();
                if (code.Length > 0)
                    used.Add(code);
            }
        }
        for (var number = 1; number < 100000; number++)
        {
            var candidate = "M" + number.ToString("D5");
            if (!used.Contains(candidate))
                return candidate;
        }
        throw new InvalidOperationException("Nu s-a putut aloca un cod de produs.");
    }

    private static bool TryPrice(string? text, out decimal price)
    {
        var value = (text ?? "").Trim().Replace(" ", "").Replace("RON", "", StringComparison.OrdinalIgnoreCase);
        return decimal.TryParse(value, NumberStyles.Number, CultureInfo.GetCultureInfo("ro-RO"), out price)
            || decimal.TryParse(value.Replace(",", "."), NumberStyles.Number, CultureInfo.InvariantCulture, out price);
    }

    private static string Text(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value))
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.ToString();
    }

    private static decimal Number(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value))
            return 0;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number))
            return number;
        var text = value.ValueKind == JsonValueKind.String ? value.GetString() : value.ToString();
        return decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed) ? parsed : 0;
    }

    private sealed record ProductPick(Guid Id, string Name)
    {
        public override string ToString() => Name;
    }
}
