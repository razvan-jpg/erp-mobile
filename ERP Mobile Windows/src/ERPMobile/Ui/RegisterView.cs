using System.Collections.ObjectModel;
using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Controls.Templates;
using Avalonia.Data;
using Avalonia.Layout;
using Avalonia.Media;
using ERPMobile.Data;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class GridRow
{
    public string? Id { get; set; }
    public string C0 { get; set; } = "";
    public string C1 { get; set; } = "";
    public string C2 { get; set; } = "";
    public string C3 { get; set; } = "";
    public string C4 { get; set; } = "";
    public string C5 { get; set; } = "";
    public string C6 { get; set; } = "";
    public string C7 { get; set; } = "";
    public string C8 { get; set; } = "";
    public string C9 { get; set; } = "";

    public void Set(int index, string value)
    {
        switch (index)
        {
            case 0: C0 = value; break;
            case 1: C1 = value; break;
            case 2: C2 = value; break;
            case 3: C3 = value; break;
            case 4: C4 = value; break;
            case 5: C5 = value; break;
            case 6: C6 = value; break;
            case 7: C7 = value; break;
            case 8: C8 = value; break;
            case 9: C9 = value; break;
        }
    }

    public string Cell(int index) => index switch
    {
        0 => C0, 1 => C1, 2 => C2, 3 => C3, 4 => C4,
        5 => C5, 6 => C6, 7 => C7, 8 => C8, _ => C9
    };
}

public sealed class RegisterView : UserControl
{
    private readonly AppSession _session;
    private readonly IReadOnlyList<ListSpec> _lists;
    private readonly ModuleAccess _access;
    private readonly ObservableCollection<GridRow> _rows = new();
    private readonly List<GridRow> _all = new();
    private readonly DataGrid _grid;
    private readonly TextBlock _status;
    private readonly TextBox _search;
    private readonly Button _groupButton;
    private readonly Button _categoryButton;
    private readonly HashSet<string> _selectedGroupIds = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> _selectedCategories = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<GroupOption> _groupOptions = new();
    private readonly List<CheckBox> _groupChecks = new();
    private readonly Dictionary<string, HashSet<string>> _groupsByProduct = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<GridRow> _menuRows = new();
    private readonly HashSet<string> _menuIds = new(StringComparer.OrdinalIgnoreCase);
    private readonly ScrollViewer _menuScroll;
    private readonly StackPanel _menuList = new() { Spacing = 8 };
    private string? _selectedMenuId;
    private int _index;

    public RegisterView(AppSession session, IReadOnlyList<ListSpec> lists, ModuleAccess access, string? note = null)
    {
        _session = session;
        _lists = lists;
        _access = access;

        var root = new DockPanel { Margin = new Avalonia.Thickness(20) };
        if (!string.IsNullOrWhiteSpace(note))
        {
            var banner = new TextBlock
            {
                Text = note,
                Foreground = Brand.Brush(Brand.Muted),
                TextWrapping = TextWrapping.Wrap,
                Margin = new Avalonia.Thickness(0, 0, 0, 12)
            };
            DockPanel.SetDock(banner, Dock.Top);
            root.Children.Add(banner);
        }

        var tabs = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Avalonia.Thickness(0, 0, 0, 12) };
        for (var i = 0; i < lists.Count; i++)
        {
            var index = i;
            var button = new Button
            {
                Content = lists[i].Title,
                Padding = new Avalonia.Thickness(12, 6),
                CornerRadius = new Avalonia.CornerRadius(8)
            };
            button.Click += async (_, _) =>
            {
                _index = index;
                PaintTabs(tabs);
                await Reload();
            };
            tabs.Children.Add(button);
        }
        PaintTabs(tabs);
        DockPanel.SetDock(tabs, Dock.Top);
        root.Children.Add(tabs);

        var tools = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), Margin = new Avalonia.Thickness(0, 0, 0, 12) };
        var filters = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        _search = new TextBox { Watermark = "Caută...", MinWidth = 220 };
        _search.TextChanged += (_, _) => ApplyFilter();
        _groupButton = new Button { Content = "Toate grupele", MinWidth = 180, IsVisible = false };
        _categoryButton = new Button { Content = "Toate categoriile", MinWidth = 180, IsVisible = false };
        BuildCategoryFlyout();
        filters.Children.Add(_search);
        filters.Children.Add(_groupButton);
        filters.Children.Add(_categoryButton);
        tools.Children.Add(filters);

        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, HorizontalAlignment = HorizontalAlignment.Right };
        Grid.SetColumn(actions, 1);
        actions.Children.Add(ActionButton("Reîncarcă", Reload));
        if (access.CanCreate)
            actions.Children.Add(ActionButton("Adaugă", Add));
        if (access.CanEdit)
            actions.Children.Add(ActionButton("Modifică", Edit));
        if (access.CanDelete)
            actions.Children.Add(ActionButton("Șterge", Delete));
        tools.Children.Add(actions);
        DockPanel.SetDock(tools, Dock.Top);
        root.Children.Add(tools);

        _status = new TextBlock { Foreground = Brushes.IndianRed, TextWrapping = TextWrapping.Wrap, Margin = new Avalonia.Thickness(0, 8, 0, 0) };
        DockPanel.SetDock(_status, Dock.Bottom);
        root.Children.Add(_status);

        _grid = new DataGrid
        {
            AutoGenerateColumns = false,
            IsReadOnly = true,
            CanUserResizeColumns = true,
            CanUserSortColumns = true,
            GridLinesVisibility = DataGridGridLinesVisibility.Horizontal,
            HeadersVisibility = DataGridHeadersVisibility.Column,
            SelectionMode = DataGridSelectionMode.Single,
            ItemsSource = _rows,
            Background = Brushes.White,
            RowBackground = Brushes.White
        };
        _grid.DoubleTapped += async (_, _) =>
        {
            if (access.CanEdit)
                await Edit();
        };
        _menuScroll = new ScrollViewer
        {
            Content = _menuList,
            IsVisible = false,
            Background = Brushes.White
        };
        var body = new Grid();
        body.Children.Add(_grid);
        body.Children.Add(_menuScroll);
        root.Children.Add(body);
        Content = root;
        _ = Reload();
    }

    private void PaintTabs(StackPanel tabs)
    {
        for (var i = 0; i < tabs.Children.Count; i++)
        {
            if (tabs.Children[i] is not Button button)
                continue;
            var selected = i == _index;
            button.Background = selected ? Brand.Brush(Brand.Navy) : Brushes.White;
            button.Foreground = selected ? Brushes.White : Brand.Brush(Brand.Navy);
            button.BorderBrush = Brand.Brush(Brand.Line);
        }
    }

    private ListSpec Current => _lists[Math.Clamp(_index, 0, _lists.Count - 1)];

    private async Task Reload()
    {
        var spec = Current;
        _status.Text = "Se încarcă...";
        _grid.Columns.Clear();
        for (var i = 0; i < spec.Columns.Length && i < 10; i++)
        {
            _grid.Columns.Add(new DataGridTextColumn
            {
                Header = spec.Columns[i].Header,
                Binding = new Binding("C" + i),
                Width = new DataGridLength(1, DataGridLengthUnitType.Star)
            });
        }

        try
        {
            var fields = spec.Columns.Select(column => column.Field).Distinct().ToList();
            if (spec.AllowWrite)
                fields.Insert(0, "id");
            var query = new List<string>
            {
                "select=" + string.Join(",", fields),
                "order=" + spec.Order
            };
            if (spec.CompanyScoped && _session.CurrentCompany != null)
                query.Add("company_id=eq." + _session.CurrentCompany.Id);
            if (!string.IsNullOrWhiteSpace(spec.ExtraFilter))
                query.Add(spec.ExtraFilter);

            var json = await _session.SelectRows(spec.Table, string.Join("&", query));
            _all.Clear();
            if (json.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in json.EnumerateArray())
                {
                    var item = new GridRow();
                    if (row.TryGetProperty("id", out var id) && id.ValueKind == JsonValueKind.String)
                        item.Id = id.GetString();
                    for (var i = 0; i < spec.Columns.Length && i < 10; i++)
                    {
                        var field = spec.Columns[i].Field;
                        item.Set(i, Money(spec.Table, field, FieldChoices.Display(spec.Table, field, Show(row, field))));
                    }
                    _all.Add(item);
                }
            }
            if (spec.Table == "products")
            {
                await MarkIncompleteRecipes();
                await MarkCatalogProfits();
            }
            await LoadGroups();
            _search.Watermark = spec.Table == "products" ? "Caută denumire sau cod" : "Caută...";
            _categoryButton.IsVisible = spec.Table == "products";
            ApplyFilter();
            _status.Text = _all.Count == 0 ? "Nu există înregistrări." : "";
        }
        catch (Exception ex)
        {
            _all.Clear();
            _rows.Clear();
            _status.Text = ex.Message;
        }
    }

    private void ApplyFilter()
    {
        var query = _search.Text?.Trim() ?? "";
        _rows.Clear();
        if (MenusOnlySelected)
        {
            ShowMenuList(query);
            return;
        }
        _menuScroll.IsVisible = false;
        _grid.IsVisible = true;
        EnsureTrashColumn(false);
        var productGroupIds = ProductGroupIds();
        var filterCategories = Current.Table == "products" && _selectedCategories.Count > 0;
        var matched = new List<GridRow>();
        foreach (var row in _all)
        {
            if (productGroupIds.Count > 0)
            {
                if (row.Id == null || !_groupsByProduct.TryGetValue(row.Id, out var groups) || !productGroupIds.Overlaps(groups))
                    continue;
            }
            if (filterCategories && !_selectedCategories.Contains(Cell(row, "tip")))
                continue;
            if (query.Length == 0 || Matches(row, query))
                matched.Add(row);
        }
        if (Current.Table == "products")
            matched.Sort(CompareProducts);
        foreach (var row in matched)
            _rows.Add(row);
    }

    private bool MenusOnlySelected =>
        _selectedGroupIds.Count > 0
        && _selectedGroupIds.All(id => _groupOptions.Any(option => option.Id == id && option.Kind == "menus"));

    private HashSet<string> ProductGroupIds()
    {
        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var id in _selectedGroupIds)
        {
            if (_groupOptions.Any(option => option.Id == id && option.Kind != "menus"))
                ids.Add(id);
        }
        return ids;
    }

    private int CompareProducts(GridRow left, GridRow right)
    {
        var culture = CultureInfo.GetCultureInfo("ro-RO");
        return string.Compare(Cell(left, "denumire"), Cell(right, "denumire"), culture, CompareOptions.IgnoreCase);
    }

    private string Cell(GridRow row, string field)
    {
        for (var i = 0; i < Current.Columns.Length && i < 10; i++)
        {
            if (Current.Columns[i].Field == field)
                return row.Cell(i);
        }
        return "";
    }

    private async Task LoadGroups()
    {
        _groupsByProduct.Clear();
        _menuRows.Clear();
        _menuIds.Clear();
        _groupOptions.Clear();
        if (Current.Table != "products" || _session.CurrentCompany == null)
        {
            _groupButton.IsVisible = false;
            _selectedGroupIds.Clear();
            RebuildGroupFlyout();
            UpdateGroupTitle();
            return;
        }

        _groupButton.IsVisible = true;
        try
        {
            var company = _session.CurrentCompany.Id;
            var groups = await _session.SelectRows(
                "cm_product_groups",
                $"company_id=eq.{company}&kind=in.(custom,menus)&select=id,name,kind&order=name.asc");
            var hasMenus = false;
            if (groups.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in groups.EnumerateArray())
                {
                    var id = TextId(row, "id");
                    var name = TextId(row, "name");
                    var kind = TextId(row, "kind") ?? "custom";
                    if (id == null || name == null)
                        continue;
                    if (kind == "menus")
                        hasMenus = true;
                    _groupOptions.Add(new GroupOption(id, name, kind));
                }
            }
            if (!hasMenus)
                _groupOptions.Add(new GroupOption("menus", "Meniuri", "menus"));
            var menuRows = await _session.SelectRows(
                "cm_menus",
                $"company_id=eq.{company}&select=id,name,is_active,cod,pret_vanzare,pret_vanzare_online&order=name.asc");
            if (menuRows.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in menuRows.EnumerateArray())
                {
                    var item = MenuRow(row);
                    if (item.Id != null)
                        _menuIds.Add(item.Id);
                    _menuRows.Add(item);
                }
                await AnnotateMenuProfits(menuRows);
            }
            _groupOptions.Sort((left, right) => string.Compare(left.Name, right.Name, CultureInfo.GetCultureInfo("ro-RO"), CompareOptions.IgnoreCase));
            var members = await _session.SelectRows(
                "cm_product_group_members",
                $"company_id=eq.{company}&select=product_id,group_id");
            if (members.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in members.EnumerateArray())
                {
                    var productId = TextId(row, "product_id");
                    var groupId = TextId(row, "group_id");
                    if (productId == null || groupId == null)
                        continue;
                    if (!_groupsByProduct.TryGetValue(productId, out var set))
                    {
                        set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                        _groupsByProduct[productId] = set;
                    }
                    set.Add(groupId);
                }
            }
        }
        finally
        {
            _selectedGroupIds.RemoveWhere(id => _groupOptions.All(option => option.Id != id));
            RebuildGroupFlyout();
            UpdateGroupTitle();
        }
    }

    private void BuildCategoryFlyout()
    {
        var panel = new StackPanel { Spacing = 6, Margin = new Avalonia.Thickness(12) };
        var all = new Button { Content = "Toate categoriile", HorizontalAlignment = HorizontalAlignment.Stretch };
        var boxes = new List<CheckBox>();
        all.Click += (_, _) =>
        {
            _selectedCategories.Clear();
            foreach (var box in boxes)
                box.IsChecked = false;
            UpdateCategoryTitle();
            ApplyFilter();
        };
        panel.Children.Add(all);
        foreach (var choice in FieldChoices.Options("products", "tip") ?? Array.Empty<FieldChoice>())
        {
            var box = new CheckBox { Content = choice.Label };
            var label = choice.Label;
            box.IsCheckedChanged += (_, _) =>
            {
                if (box.IsChecked == true)
                    _selectedCategories.Add(label);
                else
                    _selectedCategories.Remove(label);
                UpdateCategoryTitle();
                ApplyFilter();
            };
            boxes.Add(box);
            panel.Children.Add(box);
        }
        _categoryButton.Flyout = new Flyout { Content = panel };
    }

    private void RebuildGroupFlyout()
    {
        var panel = new StackPanel { Spacing = 6, Margin = new Avalonia.Thickness(12) };
        var all = new Button { Content = "Toate grupele", HorizontalAlignment = HorizontalAlignment.Stretch };
        _groupChecks.Clear();
        all.Click += (_, _) =>
        {
            _selectedGroupIds.Clear();
            foreach (var box in _groupChecks)
                box.IsChecked = false;
            UpdateGroupTitle();
            ApplyFilter();
        };
        panel.Children.Add(all);
        foreach (var option in _groupOptions)
        {
            var id = option.Id;
            var box = new CheckBox
            {
                Content = option.Name,
                IsChecked = id != null && _selectedGroupIds.Contains(id)
            };
            box.IsCheckedChanged += (_, _) =>
            {
                if (id == null)
                    return;
                if (box.IsChecked == true)
                    _selectedGroupIds.Add(id);
                else
                    _selectedGroupIds.Remove(id);
                UpdateGroupTitle();
                ApplyFilter();
            };
            _groupChecks.Add(box);
            panel.Children.Add(box);
        }
        _groupButton.Flyout = new Flyout { Content = panel };
    }

    private async Task MarkIncompleteRecipes()
    {
        if (_session.CurrentCompany == null)
            return;
        var nameIndex = -1;
        for (var i = 0; i < Current.Columns.Length; i++)
        {
            if (Current.Columns[i].Field == "denumire")
                nameIndex = i;
        }
        if (nameIndex < 0)
            return;
        var missing = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var from = 0;
        while (true)
        {
            var page = await _session.SelectRows(
                "product_recipe_lines",
                "company_id=eq." + _session.CurrentCompany.Id + "&pret_achizitie=is.null&select=product_id",
                from,
                from + 999);
            if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                break;
            foreach (var row in page.EnumerateArray())
            {
                if (row.TryGetProperty("product_id", out var id) && id.ValueKind == JsonValueKind.String && id.GetString() is string value)
                    missing.Add(value);
            }
            if (page.GetArrayLength() < 1000)
                break;
            from += 1000;
        }
        foreach (var item in _all)
        {
            if (item.Id != null && missing.Contains(item.Id))
                item.Set(nameIndex, item.Cell(nameIndex) + " · Lipsesc prețuri în rețetă");
        }
    }

    private async Task MarkCatalogProfits()
    {
        if (_session.CurrentCompany == null)
            return;
        var nameIndex = -1;
        for (var i = 0; i < Current.Columns.Length; i++)
        {
            if (Current.Columns[i].Field == "denumire")
                nameIndex = i;
        }
        if (nameIndex < 0)
            return;

        var catalog = new Dictionary<string, (string Tip, decimal Store, decimal Online, decimal? Purchase)>(StringComparer.OrdinalIgnoreCase);
        var from = 0;
        while (true)
        {
            var page = await _session.SelectRows(
                "products",
                "company_id=eq." + _session.CurrentCompany.Id + "&in_catalog=eq.true&select=id,tip,pret_vanzare,pret_vanzare_online,pret_achizitie",
                from,
                from + 999);
            if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                break;
            foreach (var row in page.EnumerateArray())
            {
                if (TextId(row, "id") is not string id
                    || !TryListedAmount(RawNumber(row, "pret_vanzare"), out var store)
                    || !TryListedAmount(RawNumber(row, "pret_vanzare_online"), out var online))
                    continue;
                decimal? purchase = TryListedAmount(RawNumber(row, "pret_achizitie"), out var purchasePrice) ? purchasePrice : null;
                catalog[id] = (Show(row, "tip"), store, online, purchase);
            }
            if (page.GetArrayLength() < 1000)
                break;
            from += 1000;
        }

        var production = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
        var hasRecipe = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        from = 0;
        while (true)
        {
            var page = await _session.SelectRows(
                "product_recipe_lines",
                "company_id=eq." + _session.CurrentCompany.Id + "&select=product_id,cantitate,pret_achizitie",
                from,
                from + 999);
            if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                break;
            foreach (var row in page.EnumerateArray())
            {
                if (TextId(row, "product_id") is not string id)
                    continue;
                hasRecipe.Add(id);
                if (!TryListedAmount(RawNumber(row, "cantitate"), out var qty) || !TryListedAmount(RawNumber(row, "pret_achizitie"), out var price))
                    continue;
                var line = decimal.Round(qty * price, 2, MidpointRounding.AwayFromZero);
                production[id] = production.TryGetValue(id, out var sum) ? sum + line : line;
            }
            if (page.GetArrayLength() < 1000)
                break;
            from += 1000;
        }

        foreach (var item in _all)
        {
            if (item.Id == null || !catalog.TryGetValue(item.Id, out var product))
                continue;
            decimal? cost = product.Tip == "produs_finit"
                ? (hasRecipe.Contains(item.Id) ? production.GetValueOrDefault(item.Id) : null)
                : product.Purchase;
            var storeProfit = cost is decimal storeCost
                ? ProfitWithPercent(product.Store - storeCost, storeCost)
                : "—";
            var onlineProfit = cost is decimal onlineCost
                ? ProfitWithPercent(product.Online - decimal.Round(product.Online * 0.30m, 2, MidpointRounding.AwayFromZero) - onlineCost, onlineCost)
                : "—";
            var suffix = " · Profit In Store/bucată = " + storeProfit;
            if (product.Online > 0)
                suffix += " · Profit On line/bucată = " + onlineProfit;
            item.Set(nameIndex, item.Cell(nameIndex) + suffix);
        }
    }

    private static string ProfitText(decimal value) =>
        decimal.Round(value, 2, MidpointRounding.AwayFromZero).ToString("0.00", CultureInfo.GetCultureInfo("ro-RO"));

    private static string ProfitWithPercent(decimal profit, decimal cost)
    {
        var amount = ProfitText(profit);
        if (cost <= 0)
            return amount + " / —";
        var percent = decimal.Round(profit / cost * 100m, 2, MidpointRounding.AwayFromZero);
        var percentText = percent.ToString("0.00", CultureInfo.GetCultureInfo("ro-RO"));
        if (percentText.EndsWith(",00", StringComparison.Ordinal))
            percentText = percentText.Substring(0, percentText.Length - 3);
        return amount + " / " + percentText + "%";
    }

    private void UpdateGroupTitle()
    {
        var names = _groupOptions.Where(option => option.Id != null && _selectedGroupIds.Contains(option.Id)).Select(option => option.Name).ToList();
        _groupButton.Content = names.Count switch
        {
            0 => "Toate grupele",
            1 => names[0],
            _ => names.Count + " grupe"
        };
    }

    private void UpdateCategoryTitle()
    {
        _categoryButton.Content = _selectedCategories.Count switch
        {
            0 => "Toate categoriile",
            1 => _selectedCategories.First(),
            _ => _selectedCategories.Count + " categorii"
        };
    }

    private GridRow MenuRow(JsonElement row)
    {
        var item = new GridRow();
        item.Id = TextId(row, "id");
        var active = row.TryGetProperty("is_active", out var flag) && flag.ValueKind == JsonValueKind.True;
        for (var i = 0; i < Current.Columns.Length && i < 10; i++)
        {
            var text = Current.Columns[i].Field switch
            {
                "denumire" => MenuTitle(row),
                "pret_vanzare" => Money("pret_vanzare", RawNumber(row, "pret_vanzare")),
                "pret_vanzare_online" => Money("pret_vanzare_online", RawNumber(row, "pret_vanzare_online")),
                "tip" => "Meniu",
                "is_active" => active ? "Da" : "Nu",
                _ => ""
            };
            item.Set(i, text);
        }
        return item;
    }

    private async Task AnnotateMenuProfits(JsonElement menuRows)
    {
        if (_session.CurrentCompany == null || menuRows.ValueKind != JsonValueKind.Array)
            return;
        var nameIndex = -1;
        for (var i = 0; i < Current.Columns.Length; i++)
        {
            if (Current.Columns[i].Field == "denumire")
                nameIndex = i;
        }
        if (nameIndex < 0)
            return;

        try
        {
            var company = _session.CurrentCompany.Id;
            var lines = new List<(string MenuId, string ProductId, decimal Qty, bool Include)>();
            var from = 0;
            while (true)
            {
                var page = await _session.SelectRows(
                    "cm_menu_lines",
                    "company_id=eq." + company + "&select=menu_id,product_id,cantitate,role,is_required",
                    from,
                    from + 999);
                if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                    break;
                foreach (var row in page.EnumerateArray())
                {
                    if (TextId(row, "menu_id") is not string menuId || TextId(row, "product_id") is not string productId)
                        continue;
                    var qty = TryListedAmount(RawNumber(row, "cantitate"), out var parsedQty) && parsedQty > 0 ? parsedQty : 1m;
                    var role = Show(row, "role");
                    var required = row.TryGetProperty("is_required", out var flag) && flag.ValueKind == JsonValueKind.True;
                    lines.Add((menuId, productId, qty, role == "main" || required));
                }
                if (page.GetArrayLength() < 1000)
                    break;
                from += 1000;
            }

            var products = new Dictionary<string, (string Tip, decimal? Purchase)>(StringComparer.OrdinalIgnoreCase);
            from = 0;
            while (true)
            {
                var page = await _session.SelectRows(
                    "products",
                    "company_id=eq." + company + "&select=id,tip,pret_achizitie",
                    from,
                    from + 999);
                if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                    break;
                foreach (var row in page.EnumerateArray())
                {
                    if (TextId(row, "id") is not string id)
                        continue;
                    decimal? purchase = TryListedAmount(RawNumber(row, "pret_achizitie"), out var price) ? price : null;
                    products[id] = (Show(row, "tip"), purchase);
                }
                if (page.GetArrayLength() < 1000)
                    break;
                from += 1000;
            }

            var production = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
            var hasRecipe = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            from = 0;
            while (true)
            {
                var page = await _session.SelectRows(
                    "product_recipe_lines",
                    "company_id=eq." + company + "&select=product_id,cantitate,pret_achizitie",
                    from,
                    from + 999);
                if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                    break;
                foreach (var row in page.EnumerateArray())
                {
                    if (TextId(row, "product_id") is not string id)
                        continue;
                    hasRecipe.Add(id);
                    if (!TryListedAmount(RawNumber(row, "cantitate"), out var qty) || !TryListedAmount(RawNumber(row, "pret_achizitie"), out var price))
                        continue;
                    var lineCost = decimal.Round(qty * price, 2, MidpointRounding.AwayFromZero);
                    production[id] = production.TryGetValue(id, out var sum) ? sum + lineCost : lineCost;
                }
                if (page.GetArrayLength() < 1000)
                    break;
                from += 1000;
            }

            var invoicePrice = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase);
            var needed = lines
                .Where(line => line.Include)
                .Select(line => line.ProductId)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Where(id => products.TryGetValue(id, out var product) && product.Tip != "produs_finit" && product.Purchase == null)
                .ToList();
            foreach (var productId in needed)
            {
                var page = await _session.SelectRows(
                    "supplier_invoice_lines",
                    "company_id=eq." + company
                    + "&product_id=eq." + productId
                    + "&select=pret_unitar,supplier_invoices!inner(data_factura)&order=supplier_invoices.data_factura.desc&limit=1");
                if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                    continue;
                if (TryListedAmount(RawNumber(page[0], "pret_unitar"), out var price))
                    invoicePrice[productId] = price;
            }

            var prices = new Dictionary<string, (decimal Store, decimal Online)>(StringComparer.OrdinalIgnoreCase);
            foreach (var row in menuRows.EnumerateArray())
            {
                if (TextId(row, "id") is not string id)
                    continue;
                if (!TryListedAmount(RawNumber(row, "pret_vanzare"), out var store))
                    continue;
                var online = TryListedAmount(RawNumber(row, "pret_vanzare_online"), out var onlinePrice) ? onlinePrice : store;
                prices[id] = (store, online);
            }

            foreach (var item in _menuRows)
            {
                if (item.Id == null || !prices.TryGetValue(item.Id, out var sale))
                    continue;
                decimal? cost = null;
                foreach (var line in lines)
                {
                    if (!string.Equals(line.MenuId, item.Id, StringComparison.OrdinalIgnoreCase) || !line.Include)
                        continue;
                    if (!products.TryGetValue(line.ProductId, out var product))
                        continue;
                    decimal? unit = product.Tip == "produs_finit"
                        ? (hasRecipe.Contains(line.ProductId) ? production.GetValueOrDefault(line.ProductId) : null)
                        : product.Purchase ?? (invoicePrice.TryGetValue(line.ProductId, out var latest) ? latest : null);
                    if (unit is not decimal unitCost)
                        continue;
                    cost = (cost ?? 0m) + decimal.Round(line.Qty * unitCost, 2, MidpointRounding.AwayFromZero);
                }
                var purchaseText = cost is decimal purchase ? ProfitText(purchase) : "—";
                var storeText = cost is decimal storeCost ? ProfitWithPercent(sale.Store - storeCost, storeCost) : "—";
                var onlineText = cost is decimal onlineCost
                    ? ProfitWithPercent(sale.Online - decimal.Round(sale.Online * 0.30m, 2, MidpointRounding.AwayFromZero) - onlineCost, onlineCost)
                    : "—";
                var text = item.Cell(nameIndex)
                    + " · Preț achiziție = " + purchaseText
                    + " · Profit In Store/bucată = " + storeText;
                if (sale.Online > 0)
                    text += " · Profit On line/bucată = " + onlineText;
                item.Set(nameIndex, text);
            }
        }
        catch
        {
        }
    }

    private static string RawNumber(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value))
            return "";
        return value.ValueKind == JsonValueKind.Number ? value.GetRawText() : value.ToString();
    }

    private static string MenuTitle(JsonElement row)
    {
        var code = TextId(row, "cod") ?? "";
        var name = TextId(row, "name") ?? "";
        return string.IsNullOrWhiteSpace(code) ? name : code + "  " + name;
    }

    private static string? TextId(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value) || value.ValueKind != JsonValueKind.String)
            return null;
        var text = value.GetString();
        return string.IsNullOrWhiteSpace(text) ? null : text;
    }

    private sealed record GroupOption(string? Id, string Name, string Kind = "")
    {
        public override string ToString() => Name;
    }

    private void ShowMenuList(string query)
    {
        _grid.IsVisible = false;
        _menuScroll.IsVisible = true;
        _rows.Clear();
        _menuList.Children.Clear();
        var add = new Button
        {
            Content = "Meniu nou",
            HorizontalAlignment = HorizontalAlignment.Left,
            Padding = new Avalonia.Thickness(14, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        add.Click += async (_, _) =>
        {
            if (await MenuEditor.Show(this, _session, null))
                await Reload();
        };
        _menuList.Children.Add(add);
        var shown = 0;
        foreach (var row in _menuRows)
        {
            if (query.Length > 0 && !Matches(row, query))
                continue;
            _menuList.Children.Add(MenuLine(row));
            shown++;
        }
        if (shown == 0)
        {
            _menuList.Children.Add(new TextBlock
            {
                Text = "Nu există meniuri. Apăsați Meniu nou.",
                Foreground = Brand.Brush(Brand.Muted),
                Margin = new Avalonia.Thickness(0, 8, 0, 0)
            });
        }
    }

    private Control MenuLine(GridRow row)
    {
        var selected = row.Id != null && string.Equals(row.Id, _selectedMenuId, StringComparison.OrdinalIgnoreCase);
        var line = new Border
        {
            Background = selected ? Brand.Brush(Brand.Page) : Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(1),
            CornerRadius = new Avalonia.CornerRadius(8),
            Padding = new Avalonia.Thickness(12, 8)
        };
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto") };
        var nameIndex = 0;
        for (var i = 0; i < Current.Columns.Length; i++)
        {
            if (Current.Columns[i].Field == "denumire")
                nameIndex = i;
        }
        var id = row.Id;
        var open = new Button
        {
            Content = string.IsNullOrWhiteSpace(row.Cell(nameIndex)) ? "Meniu" : row.Cell(nameIndex),
            Background = Brushes.Transparent,
            BorderThickness = new Avalonia.Thickness(0),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Foreground = Brand.Brush(Brand.Navy),
            FontWeight = FontWeight.SemiBold
        };
        open.Click += async (_, _) => await OpenMenu(id);
        var edit = new Button
        {
            Content = "Modifică",
            Margin = new Avalonia.Thickness(8, 0, 0, 0),
            Padding = new Avalonia.Thickness(12, 6)
        };
        edit.Click += async (_, _) => await OpenMenu(id);
        var trash = new Button
        {
            Content = "🗑 Șterge",
            Margin = new Avalonia.Thickness(8, 0, 0, 0),
            Padding = new Avalonia.Thickness(12, 6),
            Background = Brushes.Transparent,
            Foreground = Brushes.Firebrick,
            BorderBrush = Brushes.Firebrick
        };
        trash.Click += async (_, _) =>
        {
            if (id != null)
                await DeleteMenu(id);
        };
        Grid.SetColumn(edit, 1);
        Grid.SetColumn(trash, 2);
        grid.Children.Add(open);
        grid.Children.Add(edit);
        grid.Children.Add(trash);
        line.Child = grid;
        return line;
    }

    private async Task OpenMenu(string? id)
    {
        if (id == null)
            return;
        _selectedMenuId = id;
        if (await MenuEditor.Show(this, _session, id))
            await Reload();
    }

    private void EnsureTrashColumn(bool show)
    {
        var existing = _grid.Columns.FirstOrDefault(column => column.Header as string == " ");
        if (!show || !_access.CanDelete)
        {
            if (existing != null)
                _grid.Columns.Remove(existing);
            return;
        }
        if (existing != null)
            return;
        _grid.Columns.Add(new DataGridTemplateColumn
        {
            Header = " ",
            Width = new DataGridLength(48),
            CellTemplate = new FuncDataTemplate<GridRow>((row, _) =>
            {
                var button = new Button
                {
                    Content = "🗑",
                    Background = Brushes.Transparent,
                    Foreground = Brushes.Firebrick,
                    BorderThickness = new Avalonia.Thickness(0),
                    HorizontalAlignment = HorizontalAlignment.Center
                };
                button.Click += async (_, _) =>
                {
                    if (row?.Id != null)
                        await DeleteMenu(row.Id);
                };
                return button;
            })
        });
    }

    private async Task DeleteMenu(string id)
    {
        if (!await ConfirmDialog.Ask(this, "Ștergeți meniul selectat?"))
            return;
        try
        {
            await _session.DeleteRow("cm_menus", id, queueOnFailure: false);
            await Reload();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
    }

    private static bool Matches(GridRow row, string query)
    {
        for (var i = 0; i < 10; i++)
        {
            if (row.Cell(i).Contains(query, StringComparison.CurrentCultureIgnoreCase))
                return true;
        }
        return false;
    }

    private async Task Add()
    {
        var spec = Current;
        if (!spec.AllowWrite || !_access.CanCreate || _session.CurrentCompany == null)
            return;
        if (MenusOnlySelected)
        {
            if (await MenuEditor.Show(this, _session, null))
                await Reload();
            return;
        }
        var values = spec.Columns.ToDictionary(column => column.Field, _ => "");
        if (!await RecordDialog.Edit(this, "Adaugă — " + spec.Title, spec.Table, values, isNew: true, _session))
            return;
        try
        {
            var payload = ToPayload(values);
            payload["company_id"] = _session.CurrentCompany.Id;
            await _session.InsertRow(spec.Table, payload);
            await Reload();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
    }

    private async Task Edit()
    {
        var spec = Current;
        if (MenusOnlySelected)
        {
            await OpenMenu(_selectedMenuId);
            if (_selectedMenuId == null)
                _status.Text = "Alegeți un meniu din listă.";
            return;
        }
        var row = _grid.SelectedItem as GridRow;
        if (!spec.AllowWrite || !_access.CanEdit || row?.Id == null)
        {
            _status.Text = "Selectați o înregistrare.";
            return;
        }
        if (spec.Table == "products" && row.Id != null && _menuIds.Contains(row.Id))
        {
            if (await MenuEditor.Show(this, _session, row.Id))
                await Reload();
            return;
        }
        if (spec.Table == "products")
        {
            if (await ProductEditor.Edit(this, _session, row.Id))
                await Reload();
            return;
        }
        try
        {
            var json = await _session.SelectRows(spec.Table, "id=eq." + row.Id + "&select=*");
            if (json.ValueKind != JsonValueKind.Array || json.GetArrayLength() == 0)
            {
                _status.Text = "Înregistrarea nu mai există.";
                return;
            }
            var source = json[0];
            var values = new Dictionary<string, string>();
            foreach (var property in source.EnumerateObject())
            {
                if (property.Name is "id" or "company_id" or "created_at" or "updated_at" or "created_by")
                    continue;
                if (property.Value.ValueKind is JsonValueKind.Object or JsonValueKind.Array)
                    continue;
                values[property.Name] = ShowElement(property.Value);
            }
            if (!await RecordDialog.Edit(this, "Modifică — " + spec.Title, spec.Table, values, isNew: false, _session))
                return;
            await _session.UpdateRow(spec.Table, row.Id, ToPayload(values));
            await Reload();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
    }

    private async Task Delete()
    {
        var spec = Current;
        if (MenusOnlySelected)
        {
            if (_selectedMenuId == null)
            {
                _status.Text = "Alegeți un meniu din listă.";
                return;
            }
            await DeleteMenu(_selectedMenuId);
            return;
        }
        var row = _grid.SelectedItem as GridRow;
        if (!spec.AllowWrite || !_access.CanDelete || row?.Id == null)
        {
            _status.Text = "Selectați o înregistrare.";
            return;
        }
        if (spec.Table == "products" && _menuIds.Contains(row.Id))
        {
            await DeleteMenu(row.Id);
            return;
        }
        if (!await ConfirmDialog.Ask(this, "Ștergeți înregistrarea selectată?"))
            return;
        try
        {
            await _session.DeleteRow(spec.Table, row.Id);
            await Reload();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
    }

    private static Dictionary<string, object?> ToPayload(Dictionary<string, string> values)
    {
        var payload = new Dictionary<string, object?>();
        foreach (var (key, raw) in values)
        {
            var text = raw.Trim();
            if (text.Length == 0)
            {
                payload[key] = null;
                continue;
            }
            if (key.StartsWith("is_", StringComparison.Ordinal) || text is "Da" or "Nu")
            {
                payload[key] = text is "Da" or "true" or "1";
                continue;
            }
            if (decimal.TryParse(text, NumberStyles.Number, CultureInfo.CurrentCulture, out var ro)
                || decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out ro))
            {
                if (key.Contains("suma", StringComparison.Ordinal) || key.Contains("amount", StringComparison.Ordinal)
                    || key.Contains("cantitate", StringComparison.Ordinal) || key.Contains("salary", StringComparison.Ordinal)
                    || key.Contains("hours", StringComparison.Ordinal) || key.Contains("value", StringComparison.Ordinal)
                    || key.Contains("pret", StringComparison.Ordinal)
                    || key is "probability" or "sort_order" or "nr_zile_scadenta" or "year" or "month" or "z_number" or "cota_tva" or "factor_conversie")
                {
                    payload[key] = ro;
                    continue;
                }
            }
            payload[key] = text;
        }
        return payload;
    }

    private static string Money(string field, string raw) => Money("", field, raw);

    private static string Money(string table, string field, string raw)
    {
        if (!TryListedAmount(raw, out var amount))
            return raw;
        if (IsStockQuantityField(table, field))
            return StockFormat.Text(amount);
        if (field is "pret_vanzare" or "pret_vanzare_online")
            return amount.ToString("0.00", CultureInfo.GetCultureInfo("ro-RO"));
        return raw;
    }

    private static bool IsStockQuantityField(string table, string field)
    {
        if (field is "cantitate_minima" or "cantitate_optima")
            return true;
        if (field != "cantitate")
            return false;
        return table is "product_stocks" or "stock_movements" or "warehouse_product_stocks";
    }

    private static bool TryListedAmount(string raw, out decimal amount)
    {
        return decimal.TryParse(raw, NumberStyles.Number, CultureInfo.InvariantCulture, out amount)
            || decimal.TryParse(raw, NumberStyles.Number, CultureInfo.GetCultureInfo("ro-RO"), out amount);
    }

    private static string Show(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value))
            return "";
        return ShowElement(value);
    }

    private static string ShowElement(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.String => Pretty(value.GetString() ?? ""),
        JsonValueKind.Number => value.GetRawText(),
        JsonValueKind.True => "Da",
        JsonValueKind.False => "Nu",
        JsonValueKind.Null or JsonValueKind.Undefined => "",
        _ => value.GetRawText()
    };

    private static string Pretty(string text)
    {
        if (text.Length >= 10 && text[4] == '-' && text[7] == '-' && text.Contains('T'))
            return text[..10];
        return text;
    }

    private static Button ActionButton(string text, Func<Task> action)
    {
        var button = new Button
        {
            Content = text,
            Padding = new Avalonia.Thickness(12, 6),
            Background = Brushes.White,
            Foreground = Brand.Brush(Brand.Navy),
            BorderBrush = Brand.Brush(Brand.Line),
            CornerRadius = new Avalonia.CornerRadius(8)
        };
        button.Click += async (_, _) => await action();
        return button;
    }
}
