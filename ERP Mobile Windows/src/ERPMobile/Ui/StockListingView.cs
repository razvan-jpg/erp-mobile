using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Data;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Avalonia.VisualTree;
using ERPMobile.Services;
using SkiaSharp;

namespace ERPMobile.Ui;

/// <summary>Listare de stoc la momentul deschiderii, pe toata firma, cu filtre.</summary>
public sealed class StockListingView : UserControl
{
    private static readonly (string Code, string Label)[] Categories =
    {
        ("produs_finit", "Produs finit"),
        ("marfa", "Marfa"),
        ("materie_prima", "Materie prima"),
        ("ambalaj", "Ambalaj"),
        ("obiect_inventar", "Obiect de inventar"),
        ("servicii", "Servicii")
    };

    private readonly AppSession _session;
    private readonly ComboBox _location = new() { MinWidth = 180 };
    private readonly Button _groupButton = new() { Content = "Toate grupele", MinWidth = 140 };
    private readonly Button _categoryButton = new() { Content = "Toate categoriile", MinWidth = 150 };
    private readonly CalendarDatePicker _from = new() { Width = 150 };
    private readonly CalendarDatePicker _to = new() { Width = 150 };
    private readonly ComboBox _shift = new() { MinWidth = 130 };
    private readonly DataGrid _grid = new()
    {
        AutoGenerateColumns = false,
        IsReadOnly = true,
        CanUserSortColumns = false,
        HorizontalAlignment = HorizontalAlignment.Stretch,
        VerticalAlignment = VerticalAlignment.Stretch,
        HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
        HeadersVisibility = DataGridHeadersVisibility.Column
    };
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap, Margin = new Avalonia.Thickness(20, 8, 20, 8) };
    private readonly Grid _overlay = new();
    private readonly List<Article> _articles = new();
    private readonly List<WarehouseLink> _warehouses = new();
    private readonly List<GroupOption> _groups = new();
    private readonly HashSet<string> _selectedCategories = new(StringComparer.Ordinal);
    private readonly HashSet<string> _selectedGroupIds = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<CheckBox> _groupChecks = new();
    private DateTime _loadedAt;
    private bool _loading;
    private bool _suppress;

    public StockListingView(AppSession session, Action back)
    {
        _session = session;
        var today = RomaniaToday();
        _from.SelectedDate = new DateTime(today.Year, today.Month, 1);
        _to.SelectedDate = today;
        _shift.Items.Add(new ShiftChoice(0, "Toate turele"));
        _shift.Items.Add(new ShiftChoice(1, "Tura 1"));
        _shift.Items.Add(new ShiftChoice(2, "Tura 2"));
        _shift.SelectedIndex = 0;
        var bar = new WrapPanel { Margin = new Avalonia.Thickness(20, 12, 20, 0) };
        var backButton = new Button { Content = "← Listări", Background = Brushes.White };
        backButton.Click += (_, _) => back();
        var print = new Button { Padding = new Avalonia.Thickness(12, 6), Foreground = Brand.Brush(Brand.Navy) };
        var export = new Button { Padding = new Avalonia.Thickness(12, 6), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White };
        PdfGlyphs.Set(print, "Listează", print: true, save: false);
        PdfGlyphs.Set(export, "Salvează PDF", print: false, save: true);
        print.Click += async (_, _) => await Print();
        export.Click += async (_, _) => await Export();
        bar.Children.Add(backButton);
        bar.Children.Add(new TextBlock { Text = "Punct de lucru", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        bar.Children.Add(_location);
        bar.Children.Add(_groupButton);
        bar.Children.Add(_categoryButton);
        bar.Children.Add(Caption("De la"));
        bar.Children.Add(_from);
        bar.Children.Add(Caption("până la"));
        bar.Children.Add(_to);
        bar.Children.Add(_shift);
        bar.Children.Add(print);
        bar.Children.Add(export);
        _location.SelectionChanged += (_, _) =>
        {
            if (!_loading)
                Show();
        };
        _from.SelectedDateChanged += (_, _) =>
        {
            if (!_loading)
                Show();
        };
        _to.SelectedDateChanged += (_, _) =>
        {
            if (!_loading)
                Show();
        };
        AddColumn("Categorie", nameof(Row.Category), new DataGridLength(1.4, DataGridLengthUnitType.Star));
        AddColumn("Nr", nameof(Row.Number), new DataGridLength(48));
        AddColumn("Cod", nameof(Row.Code), new DataGridLength(110));
        AddColumn("Denumire", nameof(Row.Name), new DataGridLength(3, DataGridLengthUnitType.Star));
        AddColumn("UM", nameof(Row.Unit), new DataGridLength(56));
        AddColumn("Stoc scriptic", nameof(Row.QuantityText), new DataGridLength(120));
        AddColumn("Stoc faptic", nameof(Row.FactualText), new DataGridLength(110));
        _grid.SizeChanged += (_, _) => FitStockColumns();
        var root = new DockPanel();
        DockPanel.SetDock(bar, Dock.Top);
        DockPanel.SetDock(_status, Dock.Top);
        root.Children.Add(bar);
        root.Children.Add(_status);
        root.Children.Add(_grid);
        _grid.PointerReleased += async (_, e) => await OpenCard(e);
        _overlay.Children.Add(root);
        Content = _overlay;
        BuildCategoryFlyout();
        _ = Load();
    }

    private void AddColumn(string header, string binding, DataGridLength width)
    {
        _grid.Columns.Add(new DataGridTextColumn
        {
            Header = header,
            Binding = new Binding(binding),
            Width = width,
            MinWidth = 36,
            IsReadOnly = true
        });
    }

    private void FitStockColumns()
    {
        if (_grid.Columns.Count < 7)
            return;
        var width = _grid.Bounds.Width;
        if (double.IsNaN(width) || width < 280)
            return;
        const double stock = 120;
        const double factual = 110;
        const double unit = 56;
        const double number = 48;
        var code = Math.Min(120, Math.Max(72, width * 0.12));
        var rest = width - stock - factual - unit - number - code - 16;
        if (rest < 140)
            rest = 140;
        var category = Math.Max(80, rest * 0.34);
        var name = Math.Max(80, rest - category);
        var widths = new[] { category, number, code, name, unit, stock, factual };
        var sum = widths.Sum();
        if (sum > width - 4 && sum > 0)
        {
            var scale = (width - 4) / sum;
            for (var index = 0; index < widths.Length; index++)
                widths[index] *= scale;
        }
        for (var index = 0; index < widths.Length; index++)
        {
            var columnWidth = Math.Max(36, widths[index]);
            _grid.Columns[index].MinWidth = 36;
            _grid.Columns[index].MaxWidth = columnWidth;
            _grid.Columns[index].Width = new DataGridLength(columnWidth);
        }
    }

    private async Task Load()
    {
        if (_session.CurrentCompany == null)
        {
            _status.Text = "Selectați o societate.";
            return;
        }
        _loading = true;
        _status.Text = "Se încarcă stocul...";
        try
        {
            var company = _session.CurrentCompany.Id;
            _loadedAt = RomaniaNow();
            _location.Items.Clear();
            _location.Items.Add(new LocationChoice(null, "Toată firma"));
            var locations = await _session.SelectAllPages("company_work_locations", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
            foreach (var row in locations)
            {
                if (row.TryGetProperty("id", out var id) && id.TryGetGuid(out var guid))
                    _location.Items.Add(new LocationChoice(guid, Text(row, "denumire")));
            }
            _location.SelectedIndex = 0;
            _warehouses.Clear();
            foreach (var row in await _session.SelectAllPages("company_warehouses", $"company_id=eq.{company}&is_active=eq.true&select=id,work_location_id"))
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var warehouseId))
                    continue;
                Guid? locationId = null;
                if (row.TryGetProperty("work_location_id", out var link) && link.ValueKind != JsonValueKind.Null && link.TryGetGuid(out var parsed))
                    locationId = parsed;
                _warehouses.Add(new WarehouseLink(warehouseId, locationId));
            }
            var quantities = new Dictionary<Guid, Dictionary<Guid, decimal>>();
            foreach (var row in await _session.SelectAllPages("warehouse_product_stocks", $"company_id=eq.{company}&select=warehouse_id,product_id,cantitate&order=warehouse_id.asc,product_id.asc"))
            {
                if (!row.TryGetProperty("product_id", out var product) || !product.TryGetGuid(out var productId))
                    continue;
                if (!row.TryGetProperty("warehouse_id", out var warehouse) || !warehouse.TryGetGuid(out var warehouseId))
                    continue;
                if (!quantities.TryGetValue(productId, out var byWarehouse))
                {
                    byWarehouse = new Dictionary<Guid, decimal>();
                    quantities[productId] = byWarehouse;
                }
                byWarehouse[warehouseId] = byWarehouse.GetValueOrDefault(warehouseId) + Number(row, "cantitate");
            }
            _groups.Clear();
            var groupRows = await _session.SelectRows("cm_product_groups", $"company_id=eq.{company}&kind=eq.custom&select=id,name&order=name.asc");
            if (groupRows.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in groupRows.EnumerateArray())
                {
                    if (row.TryGetProperty("id", out var id) && id.TryGetGuid(out var groupId))
                        _groups.Add(new GroupOption(groupId, Text(row, "name")));
                }
            }
            var members = new Dictionary<Guid, HashSet<string>>();
            foreach (var row in await _session.SelectAllPages("cm_product_group_members", $"company_id=eq.{company}&select=id,group_id,product_id&order=id.asc"))
            {
                if (!row.TryGetProperty("product_id", out var product) || !product.TryGetGuid(out var productId))
                    continue;
                if (!row.TryGetProperty("group_id", out var group) || !group.TryGetGuid(out var groupId))
                    continue;
                if (_groups.All(option => option.Id != groupId))
                    continue;
                if (!members.TryGetValue(productId, out var set))
                {
                    set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                    members[productId] = set;
                }
                set.Add(groupId.ToString());
            }
            _articles.Clear();
            foreach (var row in await _session.SelectAllPages("products", $"company_id=eq.{company}&is_active=eq.true&tip=neq.garantie&select=id,cod,denumire,unitate_masura,tip&order=denumire.asc,id.asc"))
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var productId))
                    continue;
                var kind = Text(row, "tip");
                var code = Text(row, "cod");
                var name = Text(row, "denumire");
                if (!Listed(kind, code, name))
                    continue;
                members.TryGetValue(productId, out var groups);
                quantities.TryGetValue(productId, out var byWarehouse);
                _articles.Add(new Article(
                    productId,
                    code,
                    name,
                    Text(row, "unitate_masura"),
                    kind,
                    groups ?? new HashSet<string>(StringComparer.OrdinalIgnoreCase),
                    byWarehouse ?? new Dictionary<Guid, decimal>()));
            }
            RebuildGroupFlyout();
            Show();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
        finally
        {
            _loading = false;
        }
    }

    private void Show()
    {
        var rows = VisibleRows();
        _grid.ItemsSource = null;
        _grid.ItemsSource = rows;
        var scope = (_location.SelectedItem as LocationChoice)?.Name ?? "Toată firma";
        var from = (_from.SelectedDate ?? RomaniaToday()).ToString("dd/MM/yyyy");
        var to = (_to.SelectedDate ?? RomaniaToday()).ToString("dd/MM/yyyy");
        _status.Text = rows.Count == 0
            ? "Niciun articol pentru filtrele alese."
            : "Stoc la " + _loadedAt.ToString("dd/MM/yyyy HH:mm") + ". " + scope + ". " + rows.Count + " articole. Fișa: " + from + " – " + to + ". " + ShiftLabel() + ".";
        _status.Foreground = Brand.Brush(Brand.Muted);
    }

    private async Task OpenCard(PointerReleasedEventArgs e)
    {
        if (e.InitialPressMouseButton != MouseButton.Left)
            return;
        if (e.Source is not Visual visual)
            return;
        var gridRow = visual as DataGridRow ?? visual.FindAncestorOfType<DataGridRow>();
        if (gridRow?.DataContext is not Row row)
            return;
        var location = (_location.SelectedItem as LocationChoice)?.Id;
        var from = (_from.SelectedDate ?? RomaniaToday()).Date;
        var to = (_to.SelectedDate ?? RomaniaToday()).Date;
        if (to < from)
            (from, to) = (to, from);
        WarehouseCardListingView? card = null;
        card = new WarehouseCardListingView(_session, () =>
        {
            if (card != null)
                _overlay.Children.Remove(card);
        }, row.ProductId, location, "← Stocuri", from, to, _selectedCategories, _selectedGroupIds, SelectedShift());
        _overlay.Children.Add(card);
        await Task.CompletedTask;
    }

    private List<Row> VisibleRows()
    {
        var locationId = (_location.SelectedItem as LocationChoice)?.Id;
        var warehouseIds = locationId == null
            ? null
            : _warehouses.Where(item => item.LocationId == locationId).Select(item => item.Id).ToHashSet();
        var matched = _articles.Where(Matches).ToList();
        matched.Sort((left, right) =>
        {
            var rank = Rank(left.Kind).CompareTo(Rank(right.Kind));
            return rank != 0 ? rank : string.Compare(left.Name, right.Name, StringComparison.CurrentCultureIgnoreCase);
        });
        var rows = new List<Row>();
        var categoryNumber = 0;
        var lineNumber = 0;
        var lastKind = "";
        foreach (var article in matched)
        {
            if (article.Kind != lastKind)
            {
                categoryNumber++;
                lineNumber = 0;
                lastKind = article.Kind;
            }
            lineNumber++;
            var quantity = Quantity(article, warehouseIds);
            rows.Add(new Row(
                article.Id,
                categoryNumber + ". " + CategoryLabel(article.Kind),
                lineNumber,
                article.Code,
                article.Name,
                article.Unit,
                quantity));
        }
        return rows;
    }

    private int SelectedShift() => (_shift.SelectedItem as ShiftChoice)?.No ?? 0;

    private string ShiftLabel() => SelectedShift() switch
    {
        1 => "Tura 1",
        2 => "Tura 2",
        _ => "Toate turele"
    };

    private sealed record ShiftChoice(int No, string Name)
    {
        public override string ToString() => Name;
    }

    private bool Matches(Article article)
    {
        if (!Listed(article.Kind, article.Code, article.Name))
            return false;
        if (_selectedCategories.Count > 0 && !_selectedCategories.Contains(article.Kind))
            return false;
        if (_selectedGroupIds.Count == 0)
            return true;
        return article.Groups.Overlaps(_selectedGroupIds);
    }

    private static decimal Quantity(Article article, HashSet<Guid>? warehouseIds)
    {
        if (warehouseIds == null)
            return article.QuantityByWarehouse.Values.Sum();
        decimal sum = 0;
        foreach (var id in warehouseIds)
        {
            if (article.QuantityByWarehouse.TryGetValue(id, out var quantity))
                sum += quantity;
        }
        return sum;
    }

    private void BuildCategoryFlyout()
    {
        var panel = new StackPanel { Spacing = 6, Margin = new Avalonia.Thickness(12) };
        var all = new Button { Content = "Toate categoriile", HorizontalAlignment = HorizontalAlignment.Stretch };
        var boxes = new List<CheckBox>();
        all.Click += (_, _) =>
        {
            _suppress = true;
            _selectedCategories.Clear();
            foreach (var box in boxes)
                box.IsChecked = true;
            _suppress = false;
            UpdateCategoryTitle();
            Show();
        };
        panel.Children.Add(all);
        foreach (var choice in Categories)
        {
            var code = choice.Code;
            var box = new CheckBox { Content = choice.Label, IsChecked = true };
            box.IsCheckedChanged += (_, _) =>
            {
                if (_loading || _suppress)
                    return;
                if (_selectedCategories.Count == 0)
                {
                    _suppress = true;
                    _selectedCategories.Add(code);
                    foreach (var item in boxes)
                        item.IsChecked = ReferenceEquals(item, box);
                    _suppress = false;
                    UpdateCategoryTitle();
                    Show();
                    return;
                }
                if (box.IsChecked == true)
                    _selectedCategories.Add(code);
                else
                    _selectedCategories.Remove(code);
                if (_selectedCategories.Count == 0 || _selectedCategories.Count == Categories.Length)
                {
                    _suppress = true;
                    _selectedCategories.Clear();
                    foreach (var item in boxes)
                        item.IsChecked = true;
                    _suppress = false;
                }
                UpdateCategoryTitle();
                Show();
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
            _suppress = true;
            _selectedGroupIds.Clear();
            foreach (var box in _groupChecks)
                box.IsChecked = true;
            _suppress = false;
            UpdateGroupTitle();
            Show();
        };
        panel.Children.Add(all);
        foreach (var option in _groups)
        {
            var id = option.Id.ToString();
            var box = new CheckBox { Content = option.Name, IsChecked = _selectedGroupIds.Count == 0 || _selectedGroupIds.Contains(id) };
            box.IsCheckedChanged += (_, _) =>
            {
                if (_loading || _suppress)
                    return;
                if (_selectedGroupIds.Count == 0)
                {
                    _suppress = true;
                    _selectedGroupIds.Add(id);
                    foreach (var item in _groupChecks)
                        item.IsChecked = ReferenceEquals(item, box);
                    _suppress = false;
                    UpdateGroupTitle();
                    Show();
                    return;
                }
                if (box.IsChecked == true)
                    _selectedGroupIds.Add(id);
                else
                    _selectedGroupIds.Remove(id);
                if (_selectedGroupIds.Count == 0 || (_groups.Count > 0 && _selectedGroupIds.Count == _groups.Count))
                {
                    _suppress = true;
                    _selectedGroupIds.Clear();
                    foreach (var item in _groupChecks)
                        item.IsChecked = true;
                    _suppress = false;
                }
                UpdateGroupTitle();
                Show();
            };
            _groupChecks.Add(box);
            panel.Children.Add(box);
        }
        _groupButton.Flyout = new Flyout { Content = panel };
    }

    private void UpdateCategoryTitle()
    {
        var names = Categories.Where(choice => _selectedCategories.Contains(choice.Code)).Select(choice => choice.Label).ToList();
        _categoryButton.Content = names.Count switch
        {
            0 => "Toate categoriile",
            1 => names[0],
            _ => names.Count + " categorii"
        };
    }

    private void UpdateGroupTitle()
    {
        var names = _groups.Where(option => _selectedGroupIds.Contains(option.Id.ToString())).Select(option => option.Name).ToList();
        _groupButton.Content = names.Count switch
        {
            0 => "Toate grupele",
            1 => names[0],
            _ => names.Count + " grupe"
        };
    }

    private async Task Export()
    {
        var rows = VisibleRows();
        if (rows.Count == 0)
            return;
        var storage = TopLevel.GetTopLevel(this)?.StorageProvider;
        if (storage == null)
            return;
        var saved = await storage.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "Salvează listarea de stoc",
            SuggestedFileName = FileName(),
            DefaultExtension = "pdf",
            FileTypeChoices = [new FilePickerFileType("PDF") { Patterns = ["*.pdf"] }]
        });
        var path = saved?.TryGetLocalPath();
        if (string.IsNullOrEmpty(path))
            return;
        await File.WriteAllBytesAsync(path, Pdf(rows));
        _status.Text = "PDF salvat.";
        _status.Foreground = Brand.Brush(Brand.Muted);
    }

    private async Task Print()
    {
        var rows = VisibleRows();
        if (rows.Count == 0)
            return;
        var path = Path.Combine(Path.GetTempPath(), FileName());
        await File.WriteAllBytesAsync(path, Pdf(rows));
        try
        {
            Process.Start(new ProcessStartInfo(path) { UseShellExecute = true, Verb = "print" });
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private string FileName()
    {
        var scope = Plain((_location.SelectedItem as LocationChoice)?.Name ?? "Toata firma").Replace(' ', '-');
        return "Listare-stoc-" + scope + "-" + _loadedAt.ToString("yyyy-MM-dd") + ".pdf";
    }

    private byte[] Pdf(IReadOnlyList<Row> rows)
    {
        var scope = (_location.SelectedItem as LocationChoice)?.Name ?? "Toată firma";
        return StockListingPdf.Make(
            _session.CurrentCompany?.Denumire ?? "Societate",
            scope,
            _loadedAt,
            rows);
    }

    private static readonly HashSet<string> FinishedGoods = new(StringComparer.Ordinal)
    {
        "1318", "1503", "79", "83", "84", "1462", "81"
    };

    private static readonly HashSet<string> RawMaterialExcluded = new(StringComparer.Ordinal)
    {
        "216400", "6421735000207", "721806", "6421735000208",
        "driver fiscalnet plus - licenta anuala"
    };

    private static readonly HashSet<string> PackagingExcluded = new(StringComparer.Ordinal)
    {
        "223617", "211293", "209118", "6421735000145"
    };

    private static bool Listed(string kind, string code, string name)
    {
        var codeKey = Token(code);
        var nameKey = Token(name);
        switch (kind)
        {
            case "produs_finit":
                return FinishedGoods.Contains(codeKey);
            case "marfa":
            case "obiect_inventar":
            case "servicii":
                return true;
            case "materie_prima":
                return !RawMaterialExcluded.Contains(codeKey) && !RawMaterialExcluded.Contains(nameKey);
            case "ambalaj":
                return !PackagingExcluded.Contains(codeKey);
            default:
                return false;
        }
    }

    private static string Token(string text)
    {
        var plain = Plain(text).ToLowerInvariant()
            .Replace('–', '-')
            .Replace('—', '-');
        return string.Join(' ', plain.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
    }

    private static int Rank(string kind)
    {
        for (var index = 0; index < Categories.Length; index++)
        {
            if (Categories[index].Code == kind)
                return index;
        }
        return Categories.Length;
    }

    private static string CategoryLabel(string kind)
    {
        foreach (var choice in Categories)
        {
            if (choice.Code == kind)
                return choice.Label;
        }
        return kind;
    }

    private static TextBlock Caption(string text) => new()
    {
        Text = text,
        VerticalAlignment = VerticalAlignment.Center,
        Margin = new Avalonia.Thickness(8, 0, 4, 8),
        Foreground = Brand.Brush(Brand.Navy)
    };

    private static DateTime RomaniaToday() => RomaniaNow().Date;

    private static DateTime RomaniaNow()
    {
        try
        {
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Europe/Bucharest"));
        }
        catch (TimeZoneNotFoundException)
        {
            return DateTime.Now;
        }
    }

    private static string Text(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.ToString();
    }

    private static decimal Number(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            return 0;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number))
            return number;
        return decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : 0;
    }

    private sealed record LocationChoice(Guid? Id, string Name)
    {
        public override string ToString() => Name;
    }

    private sealed record WarehouseLink(Guid Id, Guid? LocationId);

    private sealed record GroupOption(Guid Id, string Name);

    private sealed class Article
    {
        public Article(Guid id, string code, string name, string unit, string kind, HashSet<string> groups, Dictionary<Guid, decimal> quantityByWarehouse)
        {
            Id = id;
            Code = code;
            Name = name;
            Unit = string.IsNullOrWhiteSpace(unit) ? "buc" : unit;
            Kind = kind;
            Groups = groups;
            QuantityByWarehouse = quantityByWarehouse;
        }

        public Guid Id { get; }
        public string Code { get; }
        public string Name { get; }
        public string Unit { get; }
        public string Kind { get; }
        public HashSet<string> Groups { get; }
        public Dictionary<Guid, decimal> QuantityByWarehouse { get; }
    }

    public sealed class Row
    {
        public Row(Guid productId, string category, int number, string code, string name, string unit, decimal quantity)
        {
            ProductId = productId;
            Category = category;
            Number = number.ToString(CultureInfo.InvariantCulture);
            Code = code;
            Name = name;
            Unit = unit;
            Quantity = quantity;
        }

        public Guid ProductId { get; }
        public string Category { get; }
        public string Number { get; }
        public string Code { get; }
        public string Name { get; }
        public string Unit { get; }
        public decimal Quantity { get; }
        public string QuantityText => Quantity.ToString("0.####", CultureInfo.GetCultureInfo("ro-RO"));
        public string FactualText => "";
    }

    public static string Plain(string text)
    {
        if (string.IsNullOrEmpty(text))
            return "";
        var builder = new StringBuilder();
        foreach (var ch in text.Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark)
                continue;
            builder.Append(ch switch
            {
                'ș' or 'ş' => 's',
                'ț' or 'ţ' => 't',
                'Ș' or 'Ş' => 'S',
                'Ț' or 'Ţ' => 'T',
                _ => ch
            });
        }
        return builder.ToString();
    }
}

static class StockListingPdf
{
    public static byte[] Make(string company, string scope, DateTime loadedAt, IReadOnlyList<StockListingView.Row> rows)
    {
        using var stream = new MemoryStream();
        using var document = SKDocument.CreatePdf(stream);
        var typeface = SKTypeface.FromFamilyName("Segoe UI") ?? SKTypeface.Default;
        var bold = SKTypeface.FromFamilyName("Segoe UI", SKFontStyle.Bold) ?? typeface;
        using var title = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 14, Typeface = bold };
        using var body = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 9, Typeface = typeface };
        using var head = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 9, Typeface = bold };
        using var linePaint = new SKPaint { Color = SKColors.LightGray, StrokeWidth = 0.4f, IsStroke = true };
        const float width = 595;
        const float height = 842;
        const float margin = 36;
        var headers = new[] { "Nr", "Cod", "Denumire", "UM", "Stoc scriptic", "Stoc faptic" };
        var widths = new[] { 26f, 72f, 217f, 36f, 86f, 86f };
        var index = 0;
        var page = 0;
        while (index < rows.Count || page == 0)
        {
            page++;
            var canvas = document.BeginPage(width, height);
            canvas.Clear(SKColors.White);
            var lastCategory = "";
            float y = margin + 12;
            canvas.DrawText(StockListingView.Plain(company), margin, y, title);
            y += 20;
            canvas.DrawText("Listare stocuri", margin, y, title);
            y += 16;
            canvas.DrawText(StockListingView.Plain(scope) + "  ·  " + loadedAt.ToString("dd/MM/yyyy HH:mm"), margin, y, body);
            y += 16;
            DrawRow(canvas, headers, widths, margin, y, head, linePaint, width);
            y += 16;
            while (index < rows.Count && y < height - 48)
            {
                var row = rows[index];
                if (row.Category != lastCategory)
                {
                    if (y > height - 70)
                        break;
                    canvas.DrawText(StockListingView.Plain(row.Category), margin, y, head);
                    y += 14;
                    lastCategory = row.Category;
                }
                DrawRow(
                    canvas,
                    new[]
                    {
                        row.Number,
                        StockListingView.Plain(row.Code),
                        StockListingView.Plain(row.Name),
                        StockListingView.Plain(row.Unit),
                        StockListingView.Plain(row.QuantityText),
                        ""
                    },
                    widths,
                    margin,
                    y,
                    body,
                    linePaint,
                    width);
                y += 14;
                index++;
            }
            var footer = "Pagina " + page + "  ·  Document generat cu ERP Mobile by DateConta";
            canvas.DrawText(footer, width / 2 - body.MeasureText(footer) / 2, height - 24, body);
            document.EndPage();
            if (index >= rows.Count)
                break;
        }
        document.Close();
        return stream.ToArray();
    }

    private static void DrawRow(SKCanvas canvas, string[] values, float[] widths, float x, float y, SKPaint paint, SKPaint line, float pageWidth)
    {
        var cursor = x;
        for (var index = 0; index < values.Length; index++)
        {
            var text = values[index] ?? "";
            var box = widths[index] - 4;
            while (text.Length > 1 && paint.MeasureText(text) > box)
                text = text[..^1];
            canvas.DrawText(text, cursor, y, paint);
            cursor += widths[index];
        }
        canvas.DrawLine(x, y + 4, pageWidth - x, y + 4, line);
    }
}
