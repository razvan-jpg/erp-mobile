using System.Diagnostics;
using System.Globalization;
using System.Net.Http;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using ERPMobile.Services;
using SkiaSharp;

namespace ERPMobile.Ui;

/// <summary>Fișe de magazie: articole bifate, puncte, grupe, categorii și perioadă.</summary>
public sealed class WarehouseCardListingView : UserControl
{
    private static readonly (string Code, string Label)[] Categories =
    {
        ("produs_finit", "Produs finit"),
        ("marfa", "Marfa"),
        ("materie_prima", "Materie prima"),
        ("ambalaj", "Ambalaj"),
        ("materiale_consumabile", "Materiale consumabile"),
        ("materiale_curatenie", "Materiale curatenie"),
        ("birotica", "Birotica"),
        ("obiect_inventar", "Obiect de inventar"),
        ("servicii", "Servicii")
    };

    private readonly AppSession _session;
    private readonly CalendarDatePicker _from = new() { Width = 150 };
    private readonly CalendarDatePicker _to = new() { Width = 150 };
    private readonly ComboBox _shift = new() { MinWidth = 130 };
    private readonly Button _locationButton = new() { Content = "Toată firma", MinWidth = 140 };
    private readonly Button _groupButton = new() { Content = "Toate grupele", MinWidth = 140 };
    private readonly Button _categoryButton = new() { Content = "Toate categoriile", MinWidth = 150 };
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap, Margin = new Avalonia.Thickness(20, 8) };
    private readonly StackPanel _picks = new() { Spacing = 2, Margin = new Avalonia.Thickness(12, 0, 12, 12), HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly StackPanel _cards = new() { Spacing = 16, Margin = new Avalonia.Thickness(12, 0, 12, 16), HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ScrollViewer _pickScroll;
    private readonly ScrollViewer _cardScroll;
    private readonly List<Pick> _articles = new();
    private readonly List<WarehouseLink> _warehouses = new();
    private readonly List<GroupOption> _groups = new();
    private readonly List<LocationOption> _locations = new();
    private readonly HashSet<Guid> _checked = new();
    private readonly HashSet<Guid> _selectedLocations = new();
    private readonly HashSet<string> _selectedCategories = new(StringComparer.Ordinal);
    private readonly HashSet<string> _selectedGroups = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<Guid, Guid> _locationByWarehouse = new();
    private List<CardModel> _shown = new();
    private bool _loading;
    private bool _suppress;
    private string _companyName = "Societate";
    private readonly Button _backButton = new() { Background = Brushes.White, Margin = new Avalonia.Thickness(0, 0, 8, 8) };
    private readonly string _backLabel;
    private readonly Action _leave;
    private readonly Guid? _focusProduct;
    private readonly Guid? _focusLocation;
    private readonly HashSet<string>? _focusCategories;
    private readonly HashSet<string>? _focusGroups;

    public WarehouseCardListingView(AppSession session, Action back, Guid? focusProduct = null, Guid? focusLocation = null, string backLabel = "← Listări", DateTime? focusFrom = null, DateTime? focusTo = null, IEnumerable<string>? focusCategories = null, IEnumerable<string>? focusGroups = null, int focusShift = 0)
    {
        _session = session;
        _focusProduct = focusProduct;
        _focusLocation = focusLocation;
        _backLabel = backLabel;
        _leave = back;
        _focusCategories = focusCategories == null ? null : new HashSet<string>(focusCategories, StringComparer.Ordinal);
        _focusGroups = focusGroups == null ? null : new HashSet<string>(focusGroups, StringComparer.OrdinalIgnoreCase);
        var today = RomaniaNow().Date;
        var from = (focusFrom ?? new DateTime(today.Year, today.Month, 1)).Date;
        var to = (focusTo ?? today).Date;
        if (to < from)
            (from, to) = (to, from);
        _from.SelectedDate = from;
        _to.SelectedDate = to;
        _shift.Items.Add(new ShiftChoice(0, "Toate turele"));
        _shift.Items.Add(new ShiftChoice(1, "Tura 1"));
        _shift.Items.Add(new ShiftChoice(2, "Tura 2"));
        _shift.SelectedIndex = focusShift is 1 or 2 ? focusShift : 0;
        var bar = new WrapPanel { Margin = new Avalonia.Thickness(20, 12, 20, 0) };
        _backButton.Content = backLabel;
        _backButton.Click += (_, _) =>
        {
            if (_cardScroll.IsVisible && _focusProduct == null)
            {
                _cardScroll.IsVisible = false;
                _pickScroll.IsVisible = true;
                _backButton.Content = _backLabel;
                _status.Text = "Bifați articolele. Implicit este toată firma, luna curentă.";
                _status.Foreground = Brand.Brush(Brand.Muted);
                return;
            }
            _leave();
        };
        var show = new Button
        {
            Content = "Listează fișele bifate",
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            Margin = new Avalonia.Thickness(20, 8, 20, 0),
            Padding = new Avalonia.Thickness(12, 10),
            Background = Brand.Brush(Brand.Gold),
            Foreground = Brushes.White,
            FontWeight = FontWeight.SemiBold
        };
        var pdf = new Button { Margin = new Avalonia.Thickness(0, 0, 8, 8), Foreground = Brand.Brush(Brand.Navy) };
        var print = new Button { Margin = new Avalonia.Thickness(0, 0, 8, 8), Foreground = Brand.Brush(Brand.Navy) };
        PdfGlyphs.Set(pdf, "Salvează PDF", print: false, save: true);
        PdfGlyphs.Set(print, "Listează", print: true, save: false);
        var check = new Button { Content = "Bifează vizibile", Margin = new Avalonia.Thickness(0, 0, 8, 8) };
        var uncheck = new Button { Content = "Debifează vizibile", Margin = new Avalonia.Thickness(0, 0, 8, 8) };
        show.Click += async (_, _) => await ShowCards();
        pdf.Click += async (_, _) => await Export();
        print.Click += async (_, _) => await Print();
        check.Click += (_, _) => SetVisible(true);
        uncheck.Click += (_, _) => SetVisible(false);
        bar.Children.Add(_backButton);
        bar.Children.Add(Label("De la"));
        bar.Children.Add(_from);
        bar.Children.Add(Label("până la"));
        bar.Children.Add(_to);
        bar.Children.Add(_shift);
        bar.Children.Add(_locationButton);
        bar.Children.Add(_groupButton);
        bar.Children.Add(_categoryButton);
        bar.Children.Add(check);
        bar.Children.Add(uncheck);
        bar.Children.Add(pdf);
        bar.Children.Add(print);
        _pickScroll = new ScrollViewer
        {
            Content = _picks,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        _cardScroll = new ScrollViewer
        {
            Content = _cards,
            IsVisible = false,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        _cardScroll.SizeChanged += (_, _) => FitCardWidth();
        _pickScroll.SizeChanged += (_, _) => FitCardWidth();
        var body = new Grid();
        body.Children.Add(_pickScroll);
        body.Children.Add(_cardScroll);
        var root = new DockPanel();
        DockPanel.SetDock(bar, Dock.Top);
        DockPanel.SetDock(show, Dock.Top);
        DockPanel.SetDock(_status, Dock.Top);
        root.Children.Add(bar);
        root.Children.Add(show);
        root.Children.Add(_status);
        root.Children.Add(body);
        Content = root;
        BuildCategoryFlyout();
        _ = Load();
    }

    private static TextBlock Label(string text) => new()
    {
        Text = text,
        VerticalAlignment = VerticalAlignment.Center,
        Margin = new Avalonia.Thickness(8, 0, 6, 8),
        Foreground = Brand.Brush(Brand.Navy)
    };

    private async Task Load()
    {
        if (_session.CurrentCompany == null)
        {
            _status.Text = "Selectați o societate.";
            return;
        }
        _loading = true;
        _status.Text = "Se încarcă articolele...";
        try
        {
            var company = _session.CurrentCompany.Id;
            _companyName = _session.CurrentCompany.Denumire ?? "Societate";
            _locations.Clear();
            foreach (var row in await _session.SelectAllPages("company_work_locations", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc"))
            {
                if (row.TryGetProperty("id", out var id) && id.TryGetGuid(out var guid))
                    _locations.Add(new LocationOption(guid, Text(row, "denumire")));
            }
            _warehouses.Clear();
            _locationByWarehouse.Clear();
            foreach (var row in await _session.SelectAllPages("company_warehouses", $"company_id=eq.{company}&is_active=eq.true&select=id,work_location_id"))
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var warehouseId))
                    continue;
                Guid? locationId = null;
                if (row.TryGetProperty("work_location_id", out var link) && link.ValueKind != JsonValueKind.Null && link.TryGetGuid(out var parsed))
                {
                    locationId = parsed;
                    _locationByWarehouse[warehouseId] = parsed;
                }
                _warehouses.Add(new WarehouseLink(warehouseId, locationId));
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
                if (kind == "garantie" || Categories.All(choice => choice.Code != kind))
                    continue;
                members.TryGetValue(productId, out var groups);
                _articles.Add(new Pick(productId, Text(row, "cod"), Text(row, "denumire"), Text(row, "unitate_masura"), kind, groups ?? new HashSet<string>(StringComparer.OrdinalIgnoreCase)));
            }
            _articles.Sort((left, right) =>
            {
                var rank = Rank(left.Kind).CompareTo(Rank(right.Kind));
                return rank != 0 ? rank : string.Compare(left.Name, right.Name, StringComparison.CurrentCultureIgnoreCase);
            });
            RebuildLocationFlyout();
            RebuildGroupFlyout();
            if (_focusProduct is Guid focusId)
            {
                _checked.Add(focusId);
                if (_focusLocation is Guid locationId)
                    _selectedLocations.Add(locationId);
                if (_focusCategories is { Count: > 0 })
                {
                    foreach (var code in _focusCategories)
                        _selectedCategories.Add(code);
                }
                if (_focusGroups is { Count: > 0 })
                {
                    foreach (var id in _focusGroups)
                        _selectedGroups.Add(id);
                }
                RebuildLocationFlyout();
                RebuildGroupFlyout();
                BuildCategoryFlyout();
                await ShowCards();
            }
            else
            {
                RenderPicks();
                _status.Text = "Bifați articolele. Implicit este toată firma, luna curentă.";
                _status.Foreground = Brand.Brush(Brand.Muted);
            }
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

    private void RenderPicks()
    {
        _picks.Children.Clear();
        foreach (var article in Visible())
        {
            var box = new CheckBox
            {
                Content = article.Code + "  " + article.Name + "  ·  " + CategoryLabel(article.Kind),
                IsChecked = _checked.Contains(article.Id),
                Margin = new Avalonia.Thickness(0, 2),
                HorizontalAlignment = HorizontalAlignment.Stretch
            };
            var id = article.Id;
            box.IsCheckedChanged += (_, _) =>
            {
                if (box.IsChecked == true)
                    _checked.Add(id);
                else
                    _checked.Remove(id);
            };
            _picks.Children.Add(box);
        }
        _pickScroll.IsVisible = true;
        _cardScroll.IsVisible = false;
    }

    private IEnumerable<Pick> Visible() => _articles.Where(article =>
    {
        if (_selectedCategories.Count > 0 && !_selectedCategories.Contains(article.Kind))
            return false;
        if (_selectedGroups.Count == 0)
            return true;
        return article.Groups.Overlaps(_selectedGroups);
    });

    private void SetVisible(bool check)
    {
        foreach (var article in Visible())
        {
            if (check)
                _checked.Add(article.Id);
            else
                _checked.Remove(article.Id);
        }
        RenderPicks();
    }

    private async Task ShowCards()
    {
        if (_session.CurrentCompany == null || _checked.Count == 0)
        {
            _status.Text = "Bifați cel puțin un articol.";
            return;
        }
        _loading = true;
        _status.Text = "Se încarcă fișele...";
        try
        {
            var company = _session.CurrentCompany.Id;
            var ids = _checked.ToList();
            var movements = new List<Move>();
            var select = "id,product_id,tip,cantitate,sursa,referinta,data_tranzactie,created_at,warehouse_id,pret_unitar,invoice_id,nir_id,transfer_id,production_voucher_id,consumption_voucher_id,physical_inventory_id,invoice:supplier_invoices(numar_factura)";
            for (var start = 0; start < ids.Count; start += 30)
            {
                var slice = string.Join(",", ids.Skip(start).Take(30));
                foreach (var row in await _session.SelectAllPages("stock_movements", $"company_id=eq.{company}&product_id=in.({slice})&select={select}&order=data_tranzactie.asc,id.asc"))
                    movements.Add(Move.Read(row));
            }
            var from = (_from.SelectedDate ?? DateTime.Today).Date;
            var to = (_to.SelectedDate ?? DateTime.Today).Date;
            if (to < from)
                (from, to) = (to, from);
            HashSet<Guid>? warehouses = null;
            if (_selectedLocations.Count > 0)
                warehouses = _warehouses.Where(item => item.LocationId != null && _selectedLocations.Contains(item.LocationId.Value)).Select(item => item.Id).ToHashSet();
            var sheets = await _session.SelectAllPages("z_stock_sheets", $"company_id=eq.{company}&select=work_location_id,sheet_date,shift_no,created_at&order=created_at.asc");
            var windows = MakeWindows(sheets);
            _shown = _articles.Where(article => _checked.Contains(article.Id)).Select(article => Build(article, movements, from, to, warehouses, SelectedShift(), windows)).ToList();
            DrawCards();
            _status.Text = from.ToString("dd/MM/yyyy") + " – " + to.ToString("dd/MM/yyyy") + ". " + ShiftLabel() + ". " + ScopeName() + ". " + _shown.Count + " fișe. Click pe o linie deschide documentul.";
            _status.Foreground = Brand.Brush(Brand.Muted);
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

    private void DrawCards()
    {
        _cards.Children.Clear();
        var headers = new[] { "Data", "Document", "Fel", "Intrare", "Ieșire", "Preț", "Stoc" };
        foreach (var card in _shown)
        {
            var block = new StackPanel { Spacing = 4, HorizontalAlignment = HorizontalAlignment.Stretch };
            block.Children.Add(new TextBlock { Text = card.Name, FontSize = 16, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
            block.Children.Add(new TextBlock { Text = card.Code + " · " + card.Unit + " · " + CategoryLabel(card.Kind), Foreground = Brand.Brush(Brand.Muted) });
            block.Children.Add(HeaderRow(headers));
            foreach (var line in card.Lines)
            {
                var row = LineRow(line);
                if (line.Link != null)
                {
                    var button = new Button
                    {
                        Content = row,
                        HorizontalAlignment = HorizontalAlignment.Stretch,
                        HorizontalContentAlignment = HorizontalAlignment.Stretch,
                        Background = Brushes.Transparent,
                        Padding = new Avalonia.Thickness(0)
                    };
                    var link = line.Link;
                    button.Click += async (_, _) => await Open(link);
                    block.Children.Add(button);
                }
                else
                    block.Children.Add(row);
            }
            _cards.Children.Add(block);
        }
        _pickScroll.IsVisible = false;
        _cardScroll.IsVisible = true;
        if (_focusProduct == null)
            _backButton.Content = "← Articole";
        FitCardWidth();
    }

    private void FitCardWidth()
    {
        var viewport = Math.Max(_cardScroll?.Bounds.Width ?? 0, _pickScroll?.Bounds.Width ?? 0);
        if (double.IsNaN(viewport) || viewport < 200)
            return;
        var inner = Math.Max(200, viewport - 8);
        _cards.Width = inner;
        _picks.Width = inner;
    }

    private static Grid HeaderRow(string[] headers)
    {
        var grid = RowGrid();
        for (var index = 0; index < headers.Length; index++)
            grid.Children.Add(Cell(headers[index], index, true));
        return grid;
    }

    private static Grid LineRow(CardLine line)
    {
        var grid = RowGrid();
        var values = new[] { line.Date, line.Document, line.Kind, line.Inbound, line.Outbound, line.Price, line.Stock };
        for (var index = 0; index < values.Length; index++)
            grid.Children.Add(Cell(values[index], index, line.Balance));
        return grid;
    }

    private static Grid RowGrid()
    {
        var grid = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("1.7*,2*,1.6*,1*,1*,1*,1*"),
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        return grid;
    }

    private static TextBlock Cell(string text, int column, bool bold)
    {
        var block = new TextBlock
        {
            Text = text,
            FontWeight = bold ? FontWeight.SemiBold : FontWeight.Normal,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Avalonia.Thickness(4, 3)
        };
        Grid.SetColumn(block, column);
        return block;
    }

    private CardModel Build(Pick article, List<Move> movements, DateTime from, DateTime to, HashSet<Guid>? warehouses, int shift, List<ShiftWindow> windows)
    {
        var rows = movements.Where(move => move.ProductId == article.Id && (warehouses == null || (move.WarehouseId != null && warehouses.Contains(move.WarehouseId.Value)))).OrderBy(move => AsUtc(move.At)).ThenBy(move => move.Id).ToList();
        decimal stock = 0;
        decimal cost = 0;
        decimal inboundTotal = 0;
        decimal outboundTotal = 0;
        var lines = new List<CardLine>();
        var opened = false;
        foreach (var move in rows)
        {
            var instant = AsUtc(move.At);
            Guid? location = move.WarehouseId != null && _locationByWarehouse.TryGetValue(move.WarehouseId.Value, out var found) ? found : null;
            if (location != null && windows.Any(window => window.LocationId == location.Value))
            {
                if (Listed(instant, location.Value, from, to, shift, windows))
                {
                    if (!opened)
                    {
                        lines.Add(Balance("Sold inițial", stock, cost));
                        opened = true;
                    }
                    var shiftPrice = move.Tip == "iesire" ? cost : move.Price;
                    Add(move, ref inboundTotal, ref outboundTotal);
                    Apply(move, ref stock, ref cost);
                    lines.Add(new CardLine(
                        Stamp(move.At),
                        move.Document,
                        KindLabel(move.Source),
                        move.Tip == "intrare" ? Qty(move.Quantity) : "—",
                        move.Tip == "iesire" ? Qty(move.Quantity) : "—",
                        shiftPrice.ToString("N2", CultureInfo.GetCultureInfo("ro-RO")),
                        Qty(stock),
                        false,
                        move.Link(_locationByWarehouse)));
                }
                else if (BeforePeriod(instant, location.Value, from, to, shift, windows))
                    Apply(move, ref stock, ref cost);
                continue;
            }
            var day = move.When.Date;
            if (day < from)
            {
                Apply(move, ref stock, ref cost);
                continue;
            }
            if (day > to)
                continue;
            if (!opened)
            {
                lines.Add(Balance("Sold inițial", stock, cost));
                opened = true;
            }
            var price = move.Tip == "iesire" ? cost : move.Price;
            Add(move, ref inboundTotal, ref outboundTotal);
            Apply(move, ref stock, ref cost);
            lines.Add(new CardLine(
                Stamp(move.At),
                move.Document,
                KindLabel(move.Source),
                move.Tip == "intrare" ? Qty(move.Quantity) : "—",
                move.Tip == "iesire" ? Qty(move.Quantity) : "—",
                price.ToString("N2", CultureInfo.GetCultureInfo("ro-RO")),
                Qty(stock),
                false,
                move.Link(_locationByWarehouse)));
        }
        if (!opened)
            lines.Add(Balance("Sold inițial", stock, cost));
        lines.Add(Balance("Sold final", stock, cost));
        lines.Add(new CardLine("", "Total", "", Qty(inboundTotal), Qty(outboundTotal), "", "", true, null));
        return new CardModel(article.Code, article.Name, article.Unit, article.Kind, lines);
    }

    private static void Add(Move move, ref decimal inbound, ref decimal outbound)
    {
        if (move.Tip == "intrare")
            inbound += move.Quantity;
        else
            outbound += move.Quantity;
    }

    private static void Apply(Move move, ref decimal stock, ref decimal cost)
    {
        if (move.Tip == "intrare")
        {
            var keeps = move.Source == "stock_transfer" && stock > 0;
            if (!keeps)
            {
                var total = stock + move.Quantity;
                cost = total > 0 ? (stock * cost + move.Quantity * move.Price) / total : move.Price;
            }
            stock += move.Quantity;
        }
        else
            stock -= move.Quantity;
    }

    private static CardLine Balance(string title, decimal stock, decimal cost) =>
        new("", title, "", "", "", stock > 0 ? cost.ToString("N2", CultureInfo.GetCultureInfo("ro-RO")) : "—", Qty(stock), true, null);

    private async Task Open(CardLink? link)
    {
        if (link == null || _session.CurrentCompany == null)
            return;
        try
        {
            if (link.Kind == "fiscal")
            {
                await OpenSlip(link);
                return;
            }
            var window = new Window
            {
                Title = link.Title,
                Width = 760,
                Height = 560,
                WindowStartupLocation = WindowStartupLocation.CenterOwner
            };
            var back = new Button { Content = "← Înapoi", HorizontalAlignment = HorizontalAlignment.Left, Background = Brushes.White, Margin = new Avalonia.Thickness(12, 12, 12, 0) };
            back.Click += (_, _) => window.Close();
            var page = new StackPanel { Margin = new Avalonia.Thickness(16), Spacing = 8 };
            page.Children.Add(new TextBlock { Text = "Se încarcă documentul...", Foreground = Brand.Brush(Brand.Muted) });
            var root = new DockPanel();
            DockPanel.SetDock(back, Dock.Top);
            root.Children.Add(back);
            root.Children.Add(new ScrollViewer { Content = page });
            window.Content = root;
            if (TopLevel.GetTopLevel(this) is Window owner)
                window.Show(owner);
            else
                window.Show();
            page.Children.Clear();
            await FillDocument(page, link);
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async Task FillDocument(StackPanel page, CardLink link)
    {
        var company = _session.CurrentCompany!.Id;
        switch (link.Kind)
        {
            case "invoice":
                await HeaderLines(page, "supplier_invoices", $"id=eq.{link.Id}&select=numar_factura,data_factura,suma_totala", "Factură " , "numar_factura", "data_factura",
                    "supplier_invoice_lines", $"invoice_id=eq.{link.Id}&select=numar_linie,denumire,cantitate,unitate_masura,suma_linie&order=numar_linie.asc", "denumire");
                break;
            case "nir":
                await HeaderLines(page, "supplier_nirs", $"id=eq.{link.Id}&select=numar_nir,data_nir", "NIR ", "numar_nir", "data_nir",
                    "supplier_nir_lines", $"nir_id=eq.{link.Id}&select=numar_linie,denumire,cantitate,unitate_masura&order=numar_linie.asc", "denumire");
                break;
            case "transfer":
                await HeaderLines(page, "stock_transfers", $"id=eq.{link.Id}&select=numar,data_bon,observatii", "Transfer ", "numar", "data_bon",
                    "stock_transfer_lines", $"transfer_id=eq.{link.Id}&select=numar_linie,cantitate,unitate_masura,product:products(denumire)&order=numar_linie.asc", "product");
                break;
            case "production":
                await HeaderLines(page, "production_vouchers", $"id=eq.{link.Id}&select=numar,data_bon,cantitate,unitate_masura,product:products(denumire)", "Bon producție ", "numar", "data_bon",
                    "production_voucher_lines", $"voucher_id=eq.{link.Id}&select=numar_linie,cantitate,unitate_masura,product:products(denumire)&order=numar_linie.asc", "product");
                break;
            case "consumption":
                await HeaderLines(page, "consumption_vouchers", $"id=eq.{link.Id}&select=numar,data_bon,motiv", "Bon consum ", "numar", "data_bon",
                    "consumption_voucher_lines", $"voucher_id=eq.{link.Id}&select=numar_linie,cantitate,unitate_masura,product:products(denumire)&order=numar_linie.asc", "product");
                break;
            case "inventory":
                await HeaderLines(page, "physical_inventories", $"id=eq.{link.Id}&select=numar_inventar,data_inventar", "Inventar ", "numar_inventar", "data_inventar",
                    "physical_inventory_lines", $"inventory_id=eq.{link.Id}&select=stoc_scriptic,cantitate_numarata,unitate_masura,product:products(denumire)", "product");
                break;
        }
    }

    private async Task HeaderLines(StackPanel page, string headerTable, string headerQuery, string title, string numberField, string dateField, string lineTable, string lineQuery, string nameField)
    {
        var headers = await _session.SelectRows(headerTable, headerQuery);
        if (headers.ValueKind != JsonValueKind.Array || headers.GetArrayLength() == 0)
        {
            page.Children.Add(new TextBlock { Text = "Documentul nu mai există." });
            return;
        }
        var header = headers[0];
        page.Children.Add(new TextBlock { Text = title + Text(header, numberField), FontSize = 18, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        page.Children.Add(new TextBlock { Text = Text(header, dateField), Foreground = Brand.Brush(Brand.Muted) });
        if (header.TryGetProperty("product", out var made) && made.ValueKind == JsonValueKind.Object)
            page.Children.Add(new TextBlock { Text = Text(made, "denumire") + "  " + Text(header, "cantitate") + " " + Text(header, "unitate_masura") });
        var lines = await _session.SelectAllPages(lineTable, lineQuery);
        foreach (var line in lines)
        {
            var name = nameField == "product" && line.TryGetProperty("product", out var product) && product.ValueKind == JsonValueKind.Object
                ? Text(product, "denumire")
                : Text(line, nameField);
            var qty = line.TryGetProperty("cantitate", out var qtyValue) && qtyValue.ValueKind != JsonValueKind.Null
                ? Text(line, "cantitate")
                : line.TryGetProperty("cantitate_numarata", out _)
                    ? Text(line, "cantitate_numarata")
                    : Text(line, "stoc_scriptic");
            page.Children.Add(new TextBlock { Text = name + "   " + qty + " " + Text(line, "unitate_masura"), TextWrapping = TextWrapping.Wrap });
        }
    }

    private async Task OpenSlip(CardLink link)
    {
        var filter = $"receipt_number=eq.{Uri.EscapeDataString(link.Number)}&issued_on=eq.{link.Day}&select=storage_path";
        if (link.LocationId != null)
            filter += $"&work_location_id=eq.{link.LocationId}";
        var rows = await _session.SelectRows("pos_fiscal_slips", filter);
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0 || string.IsNullOrWhiteSpace(Text(rows[0], "storage_path")))
        {
            _status.Text = "Acest bon nu are PDF salvat.";
            _status.Foreground = Brushes.Firebrick;
            return;
        }
        var url = _session.PosDocumentUrl(Text(rows[0], "storage_path"));
        using var client = new HttpClient();
        var bytes = await client.GetByteArrayAsync(url);
        var file = Path.Combine(Path.GetTempPath(), "Bon-fiscal-" + link.Number + ".pdf");
        await File.WriteAllBytesAsync(file, bytes);
        Process.Start(new ProcessStartInfo(file) { UseShellExecute = true });
    }

    private async Task Export()
    {
        if (_shown.Count == 0)
        {
            _status.Text = "Arătați fișele, apoi salvați PDF.";
            return;
        }
        var storage = TopLevel.GetTopLevel(this)?.StorageProvider;
        if (storage == null)
            return;
        var saved = await storage.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "Salvează fișele de magazie",
            SuggestedFileName = "Listare-fise-magazie-" + RomaniaNow().ToString("yyyy-MM-dd") + ".pdf",
            DefaultExtension = "pdf",
            FileTypeChoices = [new FilePickerFileType("PDF") { Patterns = ["*.pdf"] }]
        });
        var path = saved?.TryGetLocalPath();
        if (string.IsNullOrEmpty(path))
            return;
        await File.WriteAllBytesAsync(path, Pdf());
        _status.Text = "PDF salvat.";
    }

    private async Task Print()
    {
        if (_shown.Count == 0)
            return;
        var path = Path.Combine(Path.GetTempPath(), "Listare-fise-magazie.pdf");
        await File.WriteAllBytesAsync(path, Pdf());
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true, Verb = "print" });
    }

    private byte[] Pdf()
    {
        var from = (_from.SelectedDate ?? DateTime.Today).ToString("dd/MM/yyyy");
        var to = (_to.SelectedDate ?? DateTime.Today).ToString("dd/MM/yyyy") + "  " + ShiftLabel();
        return WarehouseCardPdf.Make(_companyName, ScopeName(), from, to, _shown);
    }

    private int SelectedShift() => (_shift.SelectedItem as ShiftChoice)?.No ?? 0;

    private string ShiftLabel() => SelectedShift() switch
    {
        1 => "Tura 1",
        2 => "Tura 2",
        _ => "Toate turele"
    };

    private static List<ShiftWindow> MakeWindows(IEnumerable<JsonElement> rows)
    {
        var stamps = new List<(Guid Location, DateTime At, DateTime Written, string SheetDate, int Shift)>();
        foreach (var row in rows)
        {
            if (!Guid.TryParse(Text(row, "work_location_id"), out var location))
                continue;
            var stamp = Text(row, "created_at");
            if (!DateTime.TryParse(stamp, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var created))
                continue;
            var shift = int.TryParse(Text(row, "shift_no"), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsedShift) ? parsedShift : 1;
            if (shift != 1 && shift != 2)
                shift = 1;
            var sheetDate = Text(row, "sheet_date");
            stamps.Add((location, AsUtc(created), WrittenDay(sheetDate, shift), sheetDate, shift));
        }
        var windows = new List<ShiftWindow>();
        foreach (var group in stamps.GroupBy(item => item.Location))
        {
            var previous = DateTime.SpecifyKind(DateTime.MinValue, DateTimeKind.Utc);
            (Guid Location, DateTime At, DateTime Written, string SheetDate, int Shift)? last = null;
            foreach (var row in group.OrderBy(item => item.At))
            {
                windows.Add(new ShiftWindow(group.Key, previous, row.At, row.Written, row.Shift));
                previous = row.At;
                last = row;
            }
            if (last == null)
                continue;
            var openShift = last.Value.Shift == 1 ? 2 : 1;
            windows.Add(new ShiftWindow(group.Key, previous, DateTime.SpecifyKind(DateTime.MaxValue, DateTimeKind.Utc), WrittenDay(last.Value.SheetDate, 1), openShift));
        }
        return windows;
    }

    private static bool Listed(DateTime instant, Guid location, DateTime from, DateTime to, int shift, List<ShiftWindow> windows)
    {
        var window = Match(instant, location, windows);
        if (window == null || DayKey(window.WrittenDay) < DayKey(from) || DayKey(window.WrittenDay) > DayKey(to))
            return false;
        return shift == 0 || window.Shift == shift;
    }

    private static bool BeforePeriod(DateTime instant, Guid location, DateTime from, DateTime to, int shift, List<ShiftWindow> windows)
    {
        var starts = windows
            .Where(window => window.LocationId == location && DayKey(window.WrittenDay) >= DayKey(from) && DayKey(window.WrittenDay) <= DayKey(to) && (shift == 0 || window.Shift == shift))
            .Select(window => window.StartsAfter)
            .ToList();
        if (starts.Count == 0)
            return true;
        return instant <= starts.Min();
    }

    private static ShiftWindow? Match(DateTime instant, Guid location, List<ShiftWindow> windows)
    {
        ShiftWindow? found = null;
        foreach (var window in windows)
        {
            if (window.LocationId != location || instant <= window.StartsAfter || instant > window.EndsAt)
                continue;
            if (found == null || window.EndsAt < found.EndsAt)
                found = window;
        }
        return found;
    }

    private static DateTime WrittenDay(string sheetDate, int shift)
    {
        var raw = sheetDate.Length >= 10 ? sheetDate[..10] : sheetDate;
        if (!DateTime.TryParseExact(raw, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day))
            return DateTime.MinValue;
        return shift == 2 ? day.Date.AddDays(-1) : day.Date;
    }

    private static int DayKey(DateTime value) => value.Year * 10000 + value.Month * 100 + value.Day;

    private static string Stamp(DateTime instant)
    {
        TimeZoneInfo zone;
        try
        {
            zone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Bucharest");
        }
        catch (TimeZoneNotFoundException)
        {
            zone = TimeZoneInfo.FindSystemTimeZoneById("GTB Standard Time");
        }
        return TimeZoneInfo.ConvertTimeFromUtc(AsUtc(instant), zone).ToString("dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture);
    }

    private static DateTime AsUtc(DateTime instant) => instant.Kind switch
    {
        DateTimeKind.Utc => instant,
        DateTimeKind.Local => instant.ToUniversalTime(),
        _ => DateTime.SpecifyKind(instant, DateTimeKind.Utc)
    };

    private sealed class ShiftWindow
    {
        public ShiftWindow(Guid locationId, DateTime startsAfter, DateTime endsAt, DateTime writtenDay, int shift)
        {
            LocationId = locationId;
            StartsAfter = startsAfter;
            EndsAt = endsAt;
            WrittenDay = writtenDay;
            Shift = shift;
        }

        public Guid LocationId { get; }
        public DateTime StartsAfter { get; }
        public DateTime EndsAt { get; }
        public DateTime WrittenDay { get; }
        public int Shift { get; }
    }

    private sealed record ShiftChoice(int No, string Name)
    {
        public override string ToString() => Name;
    }

    private string ScopeName()
    {
        var names = _locations.Where(item => _selectedLocations.Contains(item.Id)).Select(item => item.Name).ToList();
        return names.Count switch
        {
            0 => "Toată firma",
            1 => names[0],
            _ => names.Count + " puncte"
        };
    }

    private void BuildCategoryFlyout() => BuildFlyout(_categoryButton, "Toate categoriile", Categories.Select(item => (item.Code, item.Label)).ToList(), _selectedCategories, UpdateCategoryTitle);
    private void RebuildGroupFlyout() => BuildFlyout(_groupButton, "Toate grupele", _groups.Select(item => (item.Id.ToString(), item.Name)).ToList(), _selectedGroups, UpdateGroupTitle);
    private void RebuildLocationFlyout() => BuildFlyout(_locationButton, "Toată firma", _locations.Select(item => (item.Id.ToString(), item.Name)).ToList(), _selectedLocations.Select(id => id.ToString()).ToHashSet(StringComparer.OrdinalIgnoreCase), UpdateLocationTitle, isLocation: true);

    private void BuildFlyout(Button button, string allTitle, List<(string Id, string Label)> options, HashSet<string> selected, Action refresh, bool isLocation = false)
    {
        var panel = new StackPanel { Spacing = 6, Margin = new Avalonia.Thickness(12) };
        var boxes = new List<CheckBox>();
        var all = new Button { Content = allTitle, HorizontalAlignment = HorizontalAlignment.Stretch };
        all.Click += (_, _) =>
        {
            _suppress = true;
            selected.Clear();
            if (isLocation)
                _selectedLocations.Clear();
            foreach (var box in boxes)
                box.IsChecked = true;
            _suppress = false;
            refresh();
            if (_cardScroll.IsVisible)
                _ = ShowCards();
            else
                RenderPicks();
        };
        panel.Children.Add(all);
        void SyncLocations()
        {
            if (!isLocation)
                return;
            _selectedLocations.Clear();
            foreach (var value in selected)
            {
                if (Guid.TryParse(value, out var guid))
                    _selectedLocations.Add(guid);
            }
        }
        foreach (var option in options)
        {
            var id = option.Id;
            var box = new CheckBox { Content = option.Label, IsChecked = selected.Count == 0 || selected.Contains(id) };
            box.IsCheckedChanged += (_, _) =>
            {
                if (_loading || _suppress)
                    return;
                if (selected.Count == 0)
                {
                    _suppress = true;
                    selected.Add(id);
                    foreach (var item in boxes)
                        item.IsChecked = ReferenceEquals(item, box);
                    _suppress = false;
                    SyncLocations();
                    refresh();
                    if (!_cardScroll.IsVisible)
                        RenderPicks();
                    return;
                }
                if (box.IsChecked == true)
                    selected.Add(id);
                else
                    selected.Remove(id);
                if (selected.Count == 0 || (options.Count > 0 && selected.Count == options.Count))
                {
                    _suppress = true;
                    selected.Clear();
                    foreach (var item in boxes)
                        item.IsChecked = true;
                    _suppress = false;
                }
                SyncLocations();
                refresh();
                if (!_cardScroll.IsVisible)
                    RenderPicks();
            };
            boxes.Add(box);
            panel.Children.Add(box);
        }
        button.Flyout = new Flyout { Content = panel };
        refresh();
    }

    private void UpdateCategoryTitle() => Title(_categoryButton, "Toate categoriile", Categories.Where(item => _selectedCategories.Contains(item.Code)).Select(item => item.Label).ToList(), "categorii");
    private void UpdateGroupTitle() => Title(_groupButton, "Toate grupele", _groups.Where(item => _selectedGroups.Contains(item.Id.ToString())).Select(item => item.Name).ToList(), "grupe");
    private void UpdateLocationTitle() => Title(_locationButton, "Toată firma", _locations.Where(item => _selectedLocations.Contains(item.Id)).Select(item => item.Name).ToList(), "puncte");

    private static void Title(Button button, string all, List<string> names, string plural)
    {
        button.Content = names.Count switch
        {
            0 => all,
            1 => names[0],
            _ => names.Count + " " + plural
        };
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

    private static string KindLabel(string source) => source switch
    {
        "supplier_nir" => "NIR",
        "supplier_invoice" or "supplier_invoice_backfill" => "Factură",
        "supplier_invoice_delete" or "supplier_invoice_storno" or "supplier_invoice_storno_delete" => "Storno factură",
        "stock_transfer" => "Transfer",
        "production_voucher" => "Bon producție",
        "consumption_voucher" => "Bon consum",
        "fiscal_receipt" => "Bon fiscal",
        "physical_inventory" => "Inventar",
        "initial_stock" => "Stoc inițial",
        _ => source
    };

    private static string Qty(decimal value) => value.ToString("0.####", CultureInfo.GetCultureInfo("ro-RO"));

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

    private sealed record LocationOption(Guid Id, string Name);
    private sealed record GroupOption(Guid Id, string Name);
    private sealed record WarehouseLink(Guid Id, Guid? LocationId);

    private sealed class Pick
    {
        public Pick(Guid id, string code, string name, string unit, string kind, HashSet<string> groups)
        {
            Id = id;
            Code = code;
            Name = name;
            Unit = string.IsNullOrWhiteSpace(unit) ? "buc" : unit;
            Kind = kind;
            Groups = groups;
        }

        public Guid Id { get; }
        public string Code { get; }
        public string Name { get; }
        public string Unit { get; }
        public string Kind { get; }
        public HashSet<string> Groups { get; }
    }

    public sealed class CardModel
    {
        public CardModel(string code, string name, string unit, string kind, List<CardLine> lines)
        {
            Code = code;
            Name = name;
            Unit = unit;
            Kind = kind;
            Lines = lines;
        }

        public string Code { get; }
        public string Name { get; }
        public string Unit { get; }
        public string Kind { get; }
        public List<CardLine> Lines { get; }
    }

    public sealed record CardLine(string Date, string Document, string Kind, string Inbound, string Outbound, string Price, string Stock, bool Balance, CardLink? Link);

    public sealed class CardLink
    {
        public CardLink(string kind, Guid? id, string number, string day, Guid? locationId, string title)
        {
            Kind = kind;
            Id = id;
            Number = number;
            Day = day;
            LocationId = locationId;
            Title = title;
        }

        public string Kind { get; }
        public Guid? Id { get; }
        public string Number { get; }
        public string Day { get; }
        public Guid? LocationId { get; }
        public string Title { get; }
    }

    private sealed class Move
    {
        public Guid Id { get; init; }
        public Guid ProductId { get; init; }
        public string Tip { get; init; } = "";
        public decimal Quantity { get; init; }
        public string Source { get; init; } = "";
        public string Reference { get; init; } = "";
        public DateTime When { get; init; }
        public DateTime At { get; init; }
        public Guid? WarehouseId { get; init; }
        public decimal Price { get; init; }
        public Guid? InvoiceId { get; init; }
        public Guid? NirId { get; init; }
        public Guid? TransferId { get; init; }
        public Guid? ProductionId { get; init; }
        public Guid? ConsumptionId { get; init; }
        public Guid? InventoryId { get; init; }
        public string InvoiceNumber { get; init; } = "";

        public string Document => !string.IsNullOrWhiteSpace(InvoiceNumber) ? InvoiceNumber : string.IsNullOrWhiteSpace(Reference) ? "—" : Reference;

        public static Move Read(JsonElement row)
        {
            var when = DateTime.Today;
            var raw = Text(row, "data_tranzactie");
            if (string.IsNullOrWhiteSpace(raw))
                raw = Text(row, "created_at");
            if (DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var parsed))
                when = parsed;
            var at = when;
            var stamp = Text(row, "created_at");
            if (!string.IsNullOrWhiteSpace(stamp) && DateTime.TryParse(stamp, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var created))
                at = created;
            decimal price = 0;
            if (row.TryGetProperty("pret_unitar", out var pret) && pret.ValueKind == JsonValueKind.Number && pret.TryGetDecimal(out var parsedPrice))
                price = parsedPrice;
            var invoiceNumber = "";
            if (row.TryGetProperty("invoice", out var invoice) && invoice.ValueKind == JsonValueKind.Object)
                invoiceNumber = Text(invoice, "numar_factura");
            return new Move
            {
                Id = GuidOf(row, "id"),
                ProductId = GuidOf(row, "product_id"),
                Tip = Text(row, "tip"),
                Quantity = Number(row, "cantitate"),
                Source = Text(row, "sursa"),
                Reference = Text(row, "referinta"),
                When = when,
                At = at,
                WarehouseId = OptionalGuid(row, "warehouse_id"),
                Price = price,
                InvoiceId = OptionalGuid(row, "invoice_id"),
                NirId = OptionalGuid(row, "nir_id"),
                TransferId = OptionalGuid(row, "transfer_id"),
                ProductionId = OptionalGuid(row, "production_voucher_id"),
                ConsumptionId = OptionalGuid(row, "consumption_voucher_id"),
                InventoryId = OptionalGuid(row, "physical_inventory_id"),
                InvoiceNumber = invoiceNumber
            };
        }

        public CardLink? Link(Dictionary<Guid, Guid> locationByWarehouse)
        {
            if (ProductionId != null) return new CardLink("production", ProductionId, "", "", null, "Bon producție");
            if (ConsumptionId != null) return new CardLink("consumption", ConsumptionId, "", "", null, "Bon consum");
            if (TransferId != null) return new CardLink("transfer", TransferId, "", "", null, "Bon transfer");
            if (NirId != null) return new CardLink("nir", NirId, "", "", null, "NIR");
            if (InventoryId != null) return new CardLink("inventory", InventoryId, "", "", null, "Inventar");
            if (InvoiceId != null) return new CardLink("invoice", InvoiceId, "", "", null, "Factură");
            if (Source == "fiscal_receipt")
            {
                var number = Reference.StartsWith("BF ", StringComparison.Ordinal) ? Reference[3..] : Reference;
                if (string.IsNullOrWhiteSpace(number))
                    return null;
                Guid? location = WarehouseId != null && locationByWarehouse.TryGetValue(WarehouseId.Value, out var found) ? found : null;
                return new CardLink("fiscal", null, number.Trim(), When.ToString("yyyy-MM-dd"), location, "Bon fiscal " + number.Trim());
            }
            return null;
        }

        private static Guid GuidOf(JsonElement row, string name) =>
            row.TryGetProperty(name, out var value) && value.TryGetGuid(out var guid) ? guid : Guid.Empty;

        private static Guid? OptionalGuid(JsonElement row, string name) =>
            row.TryGetProperty(name, out var value) && value.ValueKind != JsonValueKind.Null && value.TryGetGuid(out var guid) ? guid : null;

        private static decimal Number(JsonElement row, string name)
        {
            if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
                return 0;
            if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number))
                return number;
            return decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : 0;
        }
    }
}

static class WarehouseCardPdf
{
    public static byte[] Make(string company, string scope, string from, string to, IReadOnlyList<WarehouseCardListingView.CardModel> cards)
    {
        using var stream = new MemoryStream();
        using var document = SKDocument.CreatePdf(stream);
        var typeface = SKTypeface.FromFamilyName("Segoe UI") ?? SKTypeface.Default;
        var bold = SKTypeface.FromFamilyName("Segoe UI", SKFontStyle.Bold) ?? typeface;
        using var title = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 13, Typeface = bold };
        using var body = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 8, Typeface = typeface };
        using var head = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 8, Typeface = bold };
        const float width = 842;
        const float height = 595;
        const float margin = 28;
        var headers = new[] { "Data", "Document", "Fel", "Intrare", "Iesire", "Pret", "Stoc" };
        var widths = new[] { 108f, 140f, 100f, 70f, 70f, 62f, 62f };
        var cardIndex = 0;
        var lineIndex = 0;
        var page = 0;
        while (cardIndex < cards.Count || page == 0)
        {
            page++;
            var canvas = document.BeginPage(width, height);
            canvas.Clear(SKColors.White);
            float y = margin + 12;
            canvas.DrawText(StockListingView.Plain(company), margin, y, title);
            y += 18;
            canvas.DrawText("Fise de magazie", margin, y, title);
            y += 14;
            canvas.DrawText(StockListingView.Plain(scope) + "  ·  " + from + " - " + to, margin, y, body);
            y += 16;
            while (cardIndex < cards.Count && y < height - 48)
            {
                var card = cards[cardIndex];
                if (lineIndex == 0)
                {
                    canvas.DrawText(StockListingView.Plain(card.Code + "  " + card.Name + "  " + card.Unit), margin, y, head);
                    y += 14;
                    Draw(canvas, headers, widths, margin, y, head);
                    y += 12;
                }
                while (lineIndex < card.Lines.Count && y < height - 36)
                {
                    var line = card.Lines[lineIndex];
                    Draw(canvas, new[]
                    {
                        StockListingView.Plain(line.Date),
                        StockListingView.Plain(line.Document),
                        StockListingView.Plain(line.Kind),
                        StockListingView.Plain(line.Inbound),
                        StockListingView.Plain(line.Outbound),
                        StockListingView.Plain(line.Price),
                        StockListingView.Plain(line.Stock)
                    }, widths, margin, y, body);
                    y += 12;
                    lineIndex++;
                }
                if (lineIndex >= card.Lines.Count)
                {
                    cardIndex++;
                    lineIndex = 0;
                    y += 8;
                }
                else
                    break;
            }
            var footer = "Pagina " + page + "  ·  Document generat cu ERP Mobile by DateConta";
            canvas.DrawText(footer, width / 2 - body.MeasureText(footer) / 2, height - 18, body);
            document.EndPage();
            if (cardIndex >= cards.Count)
                break;
        }
        document.Close();
        return stream.ToArray();
    }

    private static void Draw(SKCanvas canvas, string[] values, float[] widths, float x, float y, SKPaint paint)
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
    }
}
