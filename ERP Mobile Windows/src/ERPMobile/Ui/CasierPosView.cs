using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class CasierPosView : UserControl
{
    private static readonly HttpClient Http = new();
    private static readonly StringComparer NameOrder = StringComparer.Create(CultureInfo.GetCultureInfo("ro-RO"), true);
    private readonly AppSession _session;
    private readonly Guid _locationId;
    private readonly string _locationName;
    private readonly Action _exit;
    private readonly WrapPanel _tiles = new();
    private readonly TextBlock _heading;
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap };
    private readonly Button _back;
    private readonly StackPanel _lines = new() { Spacing = 2 };
    private readonly TextBlock _empty;
    private readonly TextBlock _total;
    private readonly TextBox _tenderBox;
    private readonly TextBox _discountBox;
    private readonly TextBlock _discountValue;
    private readonly TextBox _cuiBox;
    private readonly TextBlock _clientName;
    private readonly CheckBox _printInvoice;
    private readonly TextBlock _printHint;
    private readonly TextBlock _rest;
    private readonly TextBlock _short;
    private readonly Grid _modernChoices;
    private readonly Button _glovoButton;
    private readonly Button _boltButton;
    private readonly Button _woltButton;
    private readonly TextBlock _takings;
    private readonly StackPanel _cash;
    private readonly StackPanel _tabs = new() { Orientation = Orientation.Horizontal, Spacing = 6 };
    private readonly Button _cashButton;
    private Button? _emit;
    private readonly Button _cardButton;
    private readonly Button _modernButton;
    private readonly List<Ticket> _tickets = new() { new Ticket() };
    private readonly Dictionary<Guid, List<CartAddon>> _addons = new();
    private int _active;
    private bool _loadingTicket;
    private bool _padOpen;
    private string? _pendingClientName;
    private string? _pendingClientAddress;

    public CasierPosView(AppSession session, Guid locationId, string locationName, Action exit)
    {
        _session = session;
        _locationId = locationId;
        _locationName = locationName;
        _exit = exit;
        _heading = new TextBlock
        {
            Text = locationName,
            FontSize = 22,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            VerticalAlignment = VerticalAlignment.Center,
            TextWrapping = TextWrapping.Wrap
        };
        _back = new Button
        {
            Content = "Înapoi la grupe",
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White,
            FontSize = 16,
            FontWeight = FontWeight.SemiBold,
            Padding = new Avalonia.Thickness(22, 10),
            CornerRadius = new Avalonia.CornerRadius(16),
            HorizontalAlignment = HorizontalAlignment.Left,
            MinHeight = 44,
            IsVisible = false
        };
        _back.Click += (_, _) => _ = LoadGroups();
        _empty = new TextBlock
        {
            Text = "Bonul este gol.",
            Foreground = Brand.Brush(Brand.Muted),
            Margin = new Avalonia.Thickness(0, 8, 0, 8)
        };
        _total = new TextBlock
        {
            FontSize = 22,
            FontWeight = FontWeight.Bold,
            Foreground = Brand.Brush(Brand.Navy),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        _tenderBox = new TextBox
        {
            Watermark = "0,00",
            FontSize = 20,
            FontWeight = FontWeight.Bold,
            Foreground = Brand.Brush(Brand.Navy),
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            Padding = new Avalonia.Thickness(8, 4),
            IsReadOnly = true,
            IsHitTestVisible = false
        };
        _discountBox = new TextBox
        {
            Watermark = "0",
            FontSize = 20,
            FontWeight = FontWeight.Bold,
            Foreground = Brand.Brush(Brand.Navy),
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            Padding = new Avalonia.Thickness(8, 4),
            Width = 84,
            IsReadOnly = true,
            IsHitTestVisible = false
        };
        _discountValue = new TextBlock
        {
            FontSize = 16,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center
        };
        _cuiBox = new TextBox
        {
            Watermark = "CUI client, opțional",
            FontSize = 15,
            Foreground = Brand.Brush(Brand.Navy),
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            MaxLength = 12,
            Padding = new Avalonia.Thickness(8, 6),
            Margin = new Avalonia.Thickness(0, 0, 0, 8),
            IsReadOnly = true,
            IsHitTestVisible = false,
            Cursor = new Cursor(StandardCursorType.Hand)
        };
        _clientName = new TextBlock
        {
            FontSize = 14,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Avalonia.Thickness(0, 0, 0, 8),
            IsVisible = false
        };
        _printInvoice = new CheckBox
        {
            Content = "Tipărește și factură fiscală",
            FontSize = 14,
            Foreground = Brand.Brush(Brand.Navy),
            Margin = new Avalonia.Thickness(0, 0, 0, 4),
            IsVisible = false
        };
        _printHint = new TextBlock
        {
            Text = "Întâi se tipărește bonul fiscal, apoi factura fiscală pe 80 mm, cu seria casei, datele firmei și clientul de la ANAF. Factura se trimite în e-Factura.",
            FontSize = 11,
            Foreground = Brand.Brush(Brand.Muted),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Avalonia.Thickness(0, 0, 0, 8),
            IsVisible = false
        };
        _rest = new TextBlock { FontSize = 20, FontWeight = FontWeight.Bold, Foreground = Brand.Brush(Brand.Navy), HorizontalAlignment = HorizontalAlignment.Right };
        _short = new TextBlock
        {
            Text = "Suma este mai mică decât totalul.",
            FontSize = 11,
            Foreground = Brushes.Firebrick,
            TextWrapping = TextWrapping.Wrap,
            TextAlignment = TextAlignment.Right,
            HorizontalAlignment = HorizontalAlignment.Right,
            IsVisible = false
        };
        _glovoButton = PayButton("Glovo", false, () => SetChannel("glovo"));
        _boltButton = PayButton("Bolt", false, () => SetChannel("bolt"));
        _woltButton = PayButton("Wolt", false, () => SetChannel("wolt"));
        _boltButton.Margin = new Avalonia.Thickness(6, 0, 0, 0);
        _woltButton.Margin = new Avalonia.Thickness(6, 0, 0, 0);
        _modernChoices = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,*,*"),
            Margin = new Avalonia.Thickness(0, 8, 0, 0),
            IsVisible = false
        };
        Grid.SetColumn(_boltButton, 1);
        Grid.SetColumn(_woltButton, 2);
        _modernChoices.Children.Add(_glovoButton);
        _modernChoices.Children.Add(_boltButton);
        _modernChoices.Children.Add(_woltButton);
        _takings = new TextBlock
        {
            Text = "Numerar = 0,00    Card = 0,00    Glovo = 0,00    Bolt = 0,00    Wolt = 0,00",
            FontSize = 13,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            TextWrapping = TextWrapping.Wrap,
            TextAlignment = TextAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Avalonia.Thickness(190, 0)
        };
        _cash = new StackPanel();
        _cashButton = PayButton("Numerar", true, () => SetPay(PayKind.Cash));
        _cardButton = PayButton("Card", false, () => SetPay(PayKind.Card));
        _modernButton = PayButton("Modernă", false, () => SetPay(PayKind.Modern));
        _tenderBox.TextChanged += (_, _) =>
        {
            if (_loadingTicket) return;
            Active.Tender = NormalizeTender(_tenderBox.Text ?? "");
            if (_tenderBox.Text != Active.Tender)
            {
                _loadingTicket = true;
                _tenderBox.Text = Active.Tender;
                _loadingTicket = false;
            }
            UpdateChange();
        };
        _cuiBox.TextChanged += (_, _) =>
        {
            if (_loadingTicket) return;
            var next = NormalizeCui(_cuiBox.Text ?? "");
            if (_cuiBox.Text != next)
            {
                _loadingTicket = true;
                _cuiBox.Text = next;
                _loadingTicket = false;
            }
            if (next != Active.Cui || _pendingClientName != null)
            {
                Active.Cui = next;
                Active.ClientName = _pendingClientName ?? "";
                Active.ClientAddress = _pendingClientAddress ?? "";
                _pendingClientName = null;
                _pendingClientAddress = null;
                if (string.IsNullOrEmpty(next))
                    Active.PrintInvoice = false;
                if (!string.IsNullOrEmpty(next) && Active.Pay == PayKind.Modern)
                    SetPay(PayKind.Cash);
            }
            SyncInvoiceBox();
            ShowClientName();
            ShowModern();
        };
        _printInvoice.IsCheckedChanged += (_, _) =>
        {
            if (_loadingTicket) return;
            Active.PrintInvoice = _printInvoice.IsChecked == true && !string.IsNullOrEmpty(Active.Cui);
            RefreshEmitButton();
        };
        Build();
        RefreshTabs();
        RefreshReceipt();
        _tiles.SizeChanged += (_, _) => FitProductColumns();
        _ = LoadGroups();
        _ = LoadTakings();
    }

    private void Build()
    {
        Background = Brand.Brush(Brand.Page);
        var dock = new DockPanel();

        var footer = new Border
        {
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(0, 1, 0, 0),
            Padding = new Avalonia.Thickness(20, 12)
        };
        var exit = new Button
        {
            Content = "Ieșire",
            Background = Brushes.Firebrick,
            Foreground = Brushes.White,
            FontSize = 16,
            FontWeight = FontWeight.SemiBold,
            Padding = new Avalonia.Thickness(22, 10),
            CornerRadius = new Avalonia.CornerRadius(16),
            HorizontalAlignment = HorizontalAlignment.Right,
            MinHeight = 44
        };
        exit.Click += (_, _) => _exit();
        var bar = new Grid();
        bar.Children.Add(_takings);
        var edges = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
        Grid.SetColumn(exit, 2);
        edges.Children.Add(_back);
        edges.Children.Add(exit);
        bar.Children.Add(edges);
        footer.Child = bar;
        DockPanel.SetDock(footer, Dock.Bottom);
        dock.Children.Add(footer);

        var header = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto"),
            Margin = new Avalonia.Thickness(20, 14)
        };
        header.Children.Add(_heading);
        var reportX = ReportButton("Raport X", filled: false, () => _ = Tell("Raportul X se va tipări la imprimanta fiscală. Încă nu este legată."));
        var reportZ = ReportButton("Raport Z", filled: true, () => _ = CloseZ());
        reportX.Margin = new Avalonia.Thickness(8, 0, 8, 0);
        Grid.SetColumn(reportX, 1);
        Grid.SetColumn(reportZ, 2);
        header.Children.Add(reportX);
        header.Children.Add(reportZ);
        DockPanel.SetDock(header, Dock.Top);
        dock.Children.Add(header);

        var body = new Grid { ColumnDefinitions = new ColumnDefinitions("*,380"), Margin = new Avalonia.Thickness(16, 0, 16, 12) };
        var catalog = new StackPanel { Spacing = 12 };
        catalog.Children.Add(_status);
        catalog.Children.Add(_tiles);
        body.Children.Add(new ScrollViewer { Content = catalog });

        var receipt = new Border
        {
            Background = Brushes.White,
            CornerRadius = new Avalonia.CornerRadius(16),
            Padding = new Avalonia.Thickness(16),
            Margin = new Avalonia.Thickness(12, 0, 0, 0)
        };
        var receiptDock = new DockPanel();
        var bottom = new StackPanel { Spacing = 0 };
        DockPanel.SetDock(bottom, Dock.Bottom);
        var totalRow = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), Margin = new Avalonia.Thickness(0, 10, 0, 0) };
        totalRow.Children.Add(new TextBlock
        {
            Text = "Total",
            FontSize = 22,
            FontWeight = FontWeight.Bold,
            Foreground = Brand.Brush(Brand.Navy)
        });
        Grid.SetColumn(_total, 1);
        totalRow.Children.Add(_total);
        bottom.Children.Add(totalRow);

        var discountRow = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,Auto,*"), Margin = new Avalonia.Thickness(0, 10, 0, 0) };
        discountRow.Children.Add(new TextBlock
        {
            Text = "Discount %",
            FontSize = 15,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            VerticalAlignment = VerticalAlignment.Center
        });
        var discountEntry = new Border
        {
            Background = Brushes.Transparent,
            Cursor = new Cursor(StandardCursorType.Hand),
            Child = _discountBox,
            Margin = new Avalonia.Thickness(8, 0, 0, 0)
        };
        discountEntry.PointerPressed += (_, e) =>
        {
            e.Handled = true;
            _ = OpenDiscountPad();
        };
        Grid.SetColumn(discountEntry, 1);
        Grid.SetColumn(_discountValue, 2);
        discountRow.Children.Add(discountEntry);
        discountRow.Children.Add(_discountValue);
        bottom.Children.Add(discountRow);

        var pay = new Grid { ColumnDefinitions = new ColumnDefinitions("*,*,*"), Margin = new Avalonia.Thickness(0, 12, 0, 0) };
        _cardButton.Margin = new Avalonia.Thickness(6, 0, 0, 0);
        _modernButton.Margin = new Avalonia.Thickness(6, 0, 0, 0);
        Grid.SetColumn(_cardButton, 1);
        Grid.SetColumn(_modernButton, 2);
        pay.Children.Add(_cashButton);
        pay.Children.Add(_cardButton);
        pay.Children.Add(_modernButton);
        bottom.Children.Add(pay);
        bottom.Children.Add(_modernChoices);

        var cashGrid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,*"), Margin = new Avalonia.Thickness(0, 10, 0, 0) };
        var receivedStack = new StackPanel();
        receivedStack.Children.Add(new TextBlock { Text = "Primește", FontSize = 13, Foreground = Brand.Brush(Brand.Muted) });
        receivedStack.Children.Add(_tenderBox);
        var received = new Border
        {
            Background = Brushes.Transparent,
            Cursor = new Cursor(StandardCursorType.Hand),
            Child = receivedStack
        };
        received.PointerPressed += (_, e) =>
        {
            e.Handled = true;
            _ = OpenTenderPad();
        };
        var change = new StackPanel { HorizontalAlignment = HorizontalAlignment.Right };
        change.Children.Add(new TextBlock { Text = "Rest", FontSize = 13, Foreground = Brand.Brush(Brand.Muted), HorizontalAlignment = HorizontalAlignment.Right });
        change.Children.Add(_rest);
        change.Children.Add(_short);
        Grid.SetColumn(change, 1);
        cashGrid.Children.Add(received);
        cashGrid.Children.Add(change);
        _cash.Children.Add(cashGrid);
        bottom.Children.Add(_cash);

        _emit = new Button
        {
            Content = "Emite bon",
            Background = Brand.Brush(Brand.Gold),
            Foreground = Brand.Brush(Brand.Navy),
            FontSize = 18,
            FontWeight = FontWeight.Bold,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            Padding = new Avalonia.Thickness(12, 12),
            CornerRadius = new Avalonia.CornerRadius(8),
            Margin = new Avalonia.Thickness(0, 12, 0, 0)
        };
        _emit.Click += (_, _) => _ = Emit();
        bottom.Children.Add(_emit);
        RefreshEmitButton();
        bottom.Children.Add(new TextBlock
        {
            Text = "FP-700 · neconectată",
            FontSize = 12,
            Foreground = Brand.Brush(Brand.Muted),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Avalonia.Thickness(0, 8, 0, 0)
        });
        receiptDock.Children.Add(bottom);

        var linesHost = new StackPanel();
        var titleRow = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*"), Margin = new Avalonia.Thickness(0, 0, 0, 8) };
        titleRow.Children.Add(new TextBlock
        {
            Text = "Bon fiscal",
            FontSize = 22,
            FontWeight = FontWeight.Bold,
            Foreground = Brand.Brush(Brand.Navy),
            VerticalAlignment = VerticalAlignment.Center
        });
        _tabs.HorizontalAlignment = HorizontalAlignment.Right;
        Grid.SetColumn(_tabs, 1);
        titleRow.Children.Add(_tabs);
        linesHost.Children.Add(titleRow);
        var cuiHost = new Border
        {
            Background = Brushes.Transparent,
            Cursor = new Cursor(StandardCursorType.Hand),
            Child = _cuiBox
        };
        cuiHost.PointerPressed += (_, e) =>
        {
            e.Handled = true;
            _ = OpenCuiPad();
        };
        linesHost.Children.Add(cuiHost);
        linesHost.Children.Add(_clientName);
        linesHost.Children.Add(_printInvoice);
        linesHost.Children.Add(_printHint);
        linesHost.Children.Add(_empty);
        linesHost.Children.Add(_lines);
        linesHost.Children.Add(new TextBlock
        {
            Text = "A 21%   B 11%   D 0%",
            FontSize = 11,
            Foreground = Brand.Brush(Brand.Muted),
            Margin = new Avalonia.Thickness(0, 6, 0, 0)
        });
        receiptDock.Children.Add(new ScrollViewer { Content = linesHost });
        receipt.Child = receiptDock;
        Grid.SetColumn(receipt, 1);
        body.Children.Add(receipt);
        dock.Children.Add(body);
        Content = dock;
    }

    private async Task LoadGroups()
    {
        _tiles.Children.Clear();
        _fitProductColumns = false;
        _back.IsVisible = false;
        _heading.Text = _locationName;
        _status.Text = "Se încarcă grupele...";
        _status.Foreground = Brand.Brush(Brand.Muted);
        try
        {
            var company = RequireCompany();
            var rows = await _session.SelectRows(
                "cm_product_groups",
                $"company_id=eq.{company}&kind=neq.ungrouped&select=id,name,kind,sort_order&order=sort_order.asc,name.asc");
            _status.Text = "";
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                _status.Text = "Nu există grupe de catalog. Produse fără grupă nu se afișează aici.";
                return;
            }
            foreach (var row in rows.EnumerateArray().OrderBy(row => Text(row, "name"), NameOrder))
            {
                var id = row.GetProperty("id").GetGuid();
                var name = Text(row, "name");
                var kind = Text(row, "kind");
                _tiles.Children.Add(GroupTile(name, () => _ = LoadItems(id, name, kind)));
            }
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private bool _fitProductColumns;

    private void FitProductColumns()
    {
        var available = (_tiles.Parent as Layoutable)?.Bounds.Width ?? 0;
        if (!_fitProductColumns || available < 80)
            return;
        var width = (available - 40) / 4;
        if (width < 108)
            width = 108;
        foreach (var child in _tiles.Children)
        {
            if (child is Layoutable item && Math.Abs(item.Width - width) > 1)
                item.Width = width;
        }
    }

    private async Task LoadItems(Guid groupId, string groupName, string kind)
    {
        _tiles.Children.Clear();
        _back.IsVisible = true;
        _heading.Text = groupName + " · " + _locationName;
        _status.Text = "Se încarcă...";
        _status.Foreground = Brand.Brush(Brand.Muted);
        try
        {
            if (kind == "menus")
                await LoadMenus();
            else
                await LoadProducts(groupId);
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async Task LoadMenus()
    {
        var company = RequireCompany();
        var rows = await _session.SelectRows(
            "cm_menus",
            $"company_id=eq.{company}&is_active=eq.true&select=id,name,pret_vanzare,cod,permite_secundare_multiple&order=sort_order.asc,name.asc");
        _tiles.Children.Clear();
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
        {
            _status.Text = "Grupa nu are produse.";
            return;
        }
        var photos = await MainProductPhotos(rows);
        foreach (var row in rows.EnumerateArray().OrderBy(item => Text(item, "name"), NameOrder))
        {
            if (!row.TryGetProperty("id", out var idValue) || !idValue.TryGetGuid(out var id))
                continue;
            var name = Text(row, "name");
            var price = Number(row, "pret_vanzare");
            var code = Text(row, "cod");
            var multiple = row.TryGetProperty("permite_secundare_multiple", out var flag) && flag.ValueKind == JsonValueKind.True;
            photos.TryGetValue(id, out var photo);
            _tiles.Children.Add(ProductTile(name, code, Ron(price), photo ?? "", () => _ = AskMenu(id, name, price, multiple)));
        }
        _fitProductColumns = true;
        FitProductColumns();
    }

    private async Task<Dictionary<Guid, string>> MainProductPhotos(JsonElement menus)
    {
        var menuIds = new List<string>();
        if (menus.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in menus.EnumerateArray())
            {
                if (row.TryGetProperty("id", out var id) && id.TryGetGuid(out var menuId))
                    menuIds.Add(menuId.ToString());
            }
        }
        var result = new Dictionary<Guid, string>();
        if (menuIds.Count == 0)
            return result;
        var lines = await _session.SelectRows(
            "cm_menu_lines",
            "role=eq.main&menu_id=in.(" + string.Join(",", menuIds) + ")&select=menu_id,product_id");
        var productByMenu = new Dictionary<Guid, Guid>();
        if (lines.ValueKind == JsonValueKind.Array)
        {
            foreach (var line in lines.EnumerateArray())
            {
                if (line.TryGetProperty("menu_id", out var menu) && menu.TryGetGuid(out var menuId)
                    && line.TryGetProperty("product_id", out var product) && product.TryGetGuid(out var productId))
                    productByMenu[menuId] = productId;
            }
        }
        if (productByMenu.Count == 0)
            return result;
        var products = await _session.SelectRows(
            "products",
            "id=in.(" + string.Join(",", productByMenu.Values.Distinct()) + ")&select=id,imagine_url");
        var images = new Dictionary<Guid, string>();
        if (products.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in products.EnumerateArray())
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var productId))
                    continue;
                var url = Text(row, "imagine_url");
                if (url.Length > 0)
                    images[productId] = url;
            }
        }
        foreach (var pair in productByMenu)
        {
            if (images.TryGetValue(pair.Value, out var url))
                result[pair.Key] = url;
        }
        return result;
    }

    private async Task AskMenu(Guid menuId, string name, decimal price, bool multiple)
    {
        try
        {
            var lines = await _session.SelectRows(
                "cm_menu_lines",
                $"menu_id=eq.{menuId}&select=product_id,role,is_required,sort_order&order=sort_order.asc");
            if (lines.ValueKind != JsonValueKind.Array)
                return;
            Guid? mainId = null;
            var secondaryIds = new List<Guid>();
            foreach (var line in lines.EnumerateArray())
            {
                if (!line.TryGetProperty("product_id", out var product) || !product.TryGetGuid(out var productId))
                    continue;
                var role = Text(line, "role");
                if (role == "main")
                    mainId = productId;
                else if (secondaryIds.Count < 11)
                    secondaryIds.Add(productId);
            }
            if (mainId == null || secondaryIds.Count == 0)
            {
                await Tell("Completați meniul: un produs principal și un produs secundar.");
                return;
            }
            var ids = new List<Guid> { mainId.Value };
            ids.AddRange(secondaryIds);
            var products = await _session.SelectRows(
                "products",
                "id=in.(" + string.Join(",", ids) + ")&select=id,denumire,cota_tva,pret_vanzare");
            var info = new Dictionary<Guid, (string Name, decimal Vat, decimal Price)>();
            if (products.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in products.EnumerateArray())
                    info[row.GetProperty("id").GetGuid()] = (Text(row, "denumire"), Number(row, "cota_tva"), Number(row, "pret_vanzare"));
            }
            if (!info.ContainsKey(mainId.Value))
            {
                await Tell("Completați meniul: un produs principal și un produs secundar.");
                return;
            }
            await LoadAddons(ids.Select(id => id.ToString()).ToList());
            var choices = secondaryIds
                .Where(info.ContainsKey)
                .Select(id => (id, info[id].Name))
                .ToList();
            if (choices.Count == 0)
            {
                await Tell("Completați meniul: un produs principal și un produs secundar.");
                return;
            }
            var picked = await MenuSaleWindow.Ask(this, name, info[mainId.Value].Name, choices, multiple);
            if (picked == null)
                return;
            CommitMenu(name, price, mainId.Value, info[mainId.Value], picked, info);
        }
        catch (Exception ex)
        {
            await Tell(ex.Message);
        }
    }

    private void CommitMenu(
        string name,
        decimal price,
        Guid mainId,
        (string Name, decimal Vat, decimal Price) main,
        IReadOnlyList<Guid> selectedSecondaries,
        Dictionary<Guid, (string Name, decimal Vat, decimal Price)> info)
    {
        var block = Guid.NewGuid();
        var selected = new List<Guid> { mainId };
        selected.AddRange(selectedSecondaries);
        decimal sgr = 0;
        foreach (var productId in selected)
        {
            if (!_addons.TryGetValue(productId, out var addons))
                continue;
            foreach (var addon in addons)
            {
                if (IsSgr(addon.Name))
                    sgr += addon.PerUnit * addon.UnitPrice;
            }
        }
        var mainPrice = Math.Max(0, price - sgr);
        Active.Lines.Add(new CartRow
        {
            Id = block,
            Name = name,
            UnitPrice = 0,
            Quantity = 1,
            MenuHeader = true,
            MenuBlock = block
        });
        Active.Lines.Add(MenuRow(mainId, main.Name, main.Vat, mainPrice, 0, false, block));
        foreach (var productId in selectedSecondaries)
        {
            if (!info.TryGetValue(productId, out var product))
                continue;
            Active.Lines.Add(MenuRow(productId, product.Name, product.Vat, product.Price, product.Price, true, block));
        }
        RefreshTabs();
        RefreshReceipt();
    }

    private CartRow MenuRow(Guid productId, string name, decimal vat, decimal price, decimal discount, bool showDiscount, Guid block)
    {
        var addons = new List<CartAddon>();
        if (_addons.TryGetValue(productId, out var list))
        {
            foreach (var addon in list)
            {
                addons.Add(new CartAddon
                {
                    ProductId = addon.ProductId,
                    Name = addon.Name,
                    PerUnit = addon.PerUnit,
                    UnitPrice = IsSgr(addon.Name) ? addon.UnitPrice : 0,
                    VatRate = addon.VatRate
                });
            }
        }
        return new CartRow
        {
            Id = Guid.NewGuid(),
            ProductId = productId,
            Name = name,
            UnitPrice = price,
            VatRate = vat,
            Quantity = 1,
            Addons = addons,
            DiscountAmount = discount,
            ShowsDiscount = showDiscount,
            MenuBlock = block
        };
    }

    private async Task LoadProducts(Guid groupId)
    {
        var members = await _session.SelectRows(
            "cm_product_group_members",
            $"group_id=eq.{groupId}&select=product_id,sort_order&order=sort_order.asc");
        var ids = new List<string>();
        if (members.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in members.EnumerateArray())
                ids.Add(row.GetProperty("product_id").GetGuid().ToString());
        }
        if (ids.Count == 0)
        {
            _status.Text = "Grupa nu are produse.";
            return;
        }
        var rows = await _session.SelectRows(
            "products",
            "id=in.(" + string.Join(",", ids) + ")&is_active=eq.true&select=id,cod,denumire,pret_vanzare,cota_tva,imagine_url");
        await LoadAddons(ids);
        var list = rows.ValueKind == JsonValueKind.Array
            ? rows.EnumerateArray().OrderBy(row => Text(row, "denumire"), NameOrder).ToList()
            : new List<JsonElement>();
        ShowProductTiles(list, nameField: "denumire", codeField: "cod", withAddons: true);
    }

    private async Task LoadAddons(IReadOnlyList<string> productIds)
    {
        if (productIds.Count == 0)
            return;
        var links = await _session.SelectRows(
            "product_sale_addons",
            "product_id=in.(" + string.Join(",", productIds) + ")&select=product_id,addon_product_id,cantitate");
        if (links.ValueKind != JsonValueKind.Array || links.GetArrayLength() == 0)
            return;
        var addonIds = new HashSet<string>();
        foreach (var row in links.EnumerateArray())
            addonIds.Add(row.GetProperty("addon_product_id").GetGuid().ToString());
        var products = await _session.SelectRows(
            "products",
            "id=in.(" + string.Join(",", addonIds) + ")&select=id,denumire,pret_vanzare,cota_tva");
        var names = new Dictionary<Guid, (string Name, decimal Price, decimal Vat)>();
        if (products.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in products.EnumerateArray())
                names[row.GetProperty("id").GetGuid()] = (Text(row, "denumire"), Number(row, "pret_vanzare"), Number(row, "cota_tva"));
        }
        foreach (var row in links.EnumerateArray())
        {
            var parent = row.GetProperty("product_id").GetGuid();
            var addonId = row.GetProperty("addon_product_id").GetGuid();
            if (!names.TryGetValue(addonId, out var addon))
                continue;
            var perUnit = Number(row, "cantitate");
            if (perUnit <= 0)
                continue;
            if (!_addons.TryGetValue(parent, out var list))
            {
                list = new List<CartAddon>();
                _addons[parent] = list;
            }
            if (list.Any(item => item.Name == addon.Name && item.UnitPrice == addon.Price))
                continue;
            list.Add(new CartAddon { ProductId = addonId, Name = addon.Name, PerUnit = perUnit, UnitPrice = addon.Price, VatRate = addon.Vat });
        }
    }

    private void ShowProductTiles(JsonElement rows, string nameField, string? codeField, bool withAddons)
    {
        if (rows.ValueKind != JsonValueKind.Array)
            return;
        ShowProductTiles(rows.EnumerateArray().OrderBy(row => Text(row, nameField), NameOrder).ToList(), nameField, codeField, withAddons);
    }

    private void ShowProductTiles(IReadOnlyList<JsonElement> rows, string nameField, string? codeField, bool withAddons)
    {
        _status.Text = rows.Count == 0 ? "Grupa nu are produse." : "";
        foreach (var row in rows)
        {
            var name = Text(row, nameField);
            var code = codeField == null ? "" : Text(row, codeField);
            var amount = Number(row, "pret_vanzare");
            decimal? vat = withAddons ? Number(row, "cota_tva") : null;
            var image = Text(row, "imagine_url");
            Guid? id = row.TryGetProperty("id", out var idValue) && idValue.TryGetGuid(out var parsed) ? parsed : null;
            Action? tap = id is Guid key
                ? () => AddItem(key, name, amount, vat, withAddons)
                : null;
            _tiles.Children.Add(ProductTile(name, code, Ron(amount), image, tap));
        }
        _fitProductColumns = true;
        FitProductColumns();
    }

    private void AddItem(Guid id, string name, decimal price, decimal? vat, bool withAddons)
    {
        var existing = Active.Lines.Find(row => row.Id == id);
        if (existing != null)
        {
            existing.Quantity += 1;
        }
        else
        {
            var addons = withAddons && _addons.TryGetValue(id, out var list)
                ? list.Select(item => new CartAddon { Name = item.Name, PerUnit = item.PerUnit, UnitPrice = item.UnitPrice, VatRate = item.VatRate }).ToList()
                : new List<CartAddon>();
            Active.Lines.Add(new CartRow { Id = id, Name = name, UnitPrice = price, VatRate = vat, Quantity = 1, Addons = addons });
        }
        RefreshTabs();
        RefreshReceipt();
    }

    private void SetPay(PayKind pay)
    {
        if (pay == PayKind.Modern && !string.IsNullOrEmpty(Active.Cui))
            return;
        Active.Pay = pay;
        if (pay != PayKind.Modern)
            Active.Channel = "";
        PaintPay(_cashButton, pay == PayKind.Cash);
        PaintPay(_cardButton, pay == PayKind.Card);
        PaintPay(_modernButton, pay == PayKind.Modern);
        ShowModern();
        UpdateChange();
    }

    private void SetChannel(string channel)
    {
        if (!string.IsNullOrEmpty(Active.Cui))
            return;
        Active.Pay = PayKind.Modern;
        Active.Channel = channel;
        PaintPay(_cashButton, false);
        PaintPay(_cardButton, false);
        PaintPay(_modernButton, true);
        ShowModern();
        UpdateChange();
    }

    private void ShowModern()
    {
        var locked = !string.IsNullOrEmpty(Active.Cui);
        _modernButton.IsEnabled = !locked;
        if (locked && Active.Pay == PayKind.Modern)
        {
            Active.Pay = PayKind.Cash;
            Active.Channel = "";
            PaintPay(_cashButton, true);
            PaintPay(_cardButton, false);
            PaintPay(_modernButton, false);
            _cash.IsVisible = true;
        }
        _modernChoices.IsVisible = !locked && Active.Pay == PayKind.Modern;
        PaintPay(_glovoButton, Active.Channel == "glovo");
        PaintPay(_boltButton, Active.Channel == "bolt");
        PaintPay(_woltButton, Active.Channel == "wolt");
    }

    private void RefreshReceipt()
    {
        _lines.Children.Clear();
        foreach (var row in Active.Lines)
        {
            var amount = row.MenuHeader ? "" : Money(row.UnitPrice * row.Quantity);
            var letter = row.MenuHeader ? "" : VatMark(row.VatRate, row.MenuBlock != null);
            Action? remove = row.MenuBlock == null || row.MenuHeader ? () => RemoveLine(row.Id) : null;
            _lines.Children.Add(ReceiptLine(ShownQty(row.Quantity), row.Name, amount, letter, addon: false, remove));
            if (row.DiscountAmount > 0 || row.ShowsDiscount)
                _lines.Children.Add(ReceiptLine("", "Discount 100%", Money(-row.DiscountAmount), "", addon: true));
            foreach (var addon in row.Addons)
            {
                if (IsSgr(addon.Name))
                    continue;
                var addonAmount = addon.PerUnit * row.Quantity * addon.UnitPrice;
                _lines.Children.Add(ReceiptLine("", addon.Name, Money(addonAmount), VatMark(addon.VatRate, row.MenuBlock != null), addon: true));
            }
        }
        foreach (var sgr in SgrLines(Active.Lines))
            _lines.Children.Add(ReceiptLine(QtyText(sgr.Quantity), sgr.Name, Money(sgr.Amount), VatMark(sgr.VatRate, sgr.FromMenu), addon: true));
        var discount = PercentCuts(Active).Discount;
        if (discount > 0)
            _lines.Children.Add(ReceiptLine("", DiscountTitle(Active), Money(-discount), "", addon: true));
        _empty.IsVisible = Active.Lines.Count == 0;
        UpdateChange();
    }

    private void RemoveLine(Guid id)
    {
        var row = Active.Lines.Find(line => line.Id == id);
        if (row?.MenuBlock is Guid block)
            Active.Lines.RemoveAll(line => line.MenuBlock == block);
        else
            Active.Lines.RemoveAll(line => line.Id == id);
        RefreshTabs();
        RefreshReceipt();
    }

    private void UpdateChange()
    {
        var total = TicketTotal(Active);
        _total.Text = Ron(total);
        var sale = PercentCuts(Active);
        _discountValue.Text = sale.Discount > 0 ? Money(-sale.Discount) : "";
        var cash = Active.Pay == PayKind.Cash;
        _cash.IsVisible = cash;
        ShowModern();
        if (!cash)
        {
            _short.IsVisible = false;
            return;
        }
        if (!TryMoney(Active.Tender, out var received) || received <= 0)
        {
            _rest.Text = Money(0);
            _short.IsVisible = false;
            return;
        }
        if (received < total)
        {
            _rest.Text = Money(0);
            _short.IsVisible = true;
            return;
        }
        _rest.Text = Money(received - total);
        _short.IsVisible = false;
    }

    private void RefreshTabs()
    {
        _tabs.Children.Clear();
        for (var i = 0; i < _tickets.Count; i++)
        {
            var index = i;
            var ticket = _tickets[i];
            var selected = index == _active;
            var button = new Button
            {
                Content = (index + 1).ToString(CultureInfo.InvariantCulture) + (ticket.Lines.Count > 0 ? " •" : ""),
                Background = selected ? Brand.Brush(Brand.Navy) : Brushes.White,
                Foreground = selected ? Brushes.White : Brand.Brush(Brand.Navy),
                BorderBrush = Brand.Brush(Brand.Navy),
                BorderThickness = new Avalonia.Thickness(1),
                FontWeight = FontWeight.Bold,
                Padding = new Avalonia.Thickness(10, 4),
                CornerRadius = new Avalonia.CornerRadius(8)
            };
            button.Click += (_, _) => ShowTicket(index);
            _tabs.Children.Add(button);
            if (ticket.Lines.Count == 0 && _tickets.Count > 1)
            {
                var close = new Button
                {
                    Content = "×",
                    Background = Brushes.Transparent,
                    Foreground = Brand.Brush(Brand.Muted),
                    Padding = new Avalonia.Thickness(2, 0),
                    BorderThickness = new Avalonia.Thickness(0)
                };
                close.Click += (_, _) => CloseTicket(index);
                _tabs.Children.Add(close);
            }
        }
        if (_tickets.Count < 4)
        {
            var add = new Button
            {
                Content = "+",
                Background = Brushes.White,
                Foreground = Brand.Brush(Brand.Navy),
                BorderBrush = Brand.Brush(Brand.Navy),
                BorderThickness = new Avalonia.Thickness(1),
                FontWeight = FontWeight.Bold,
                Padding = new Avalonia.Thickness(10, 4),
                CornerRadius = new Avalonia.CornerRadius(8)
            };
            add.Click += (_, _) => OpenTicket();
            _tabs.Children.Add(add);
        }
    }

    private void ShowTicket(int index)
    {
        if (index < 0 || index >= _tickets.Count)
            return;
        _active = index;
        _loadingTicket = true;
        _cuiBox.Text = Active.Cui;
        _tenderBox.Text = Active.Tender;
        _discountBox.Text = Active.DiscountText;
        _printInvoice.IsChecked = Active.PrintInvoice && !string.IsNullOrEmpty(Active.Cui);
        _loadingTicket = false;
        SyncInvoiceBox();
        ShowClientName();
        PaintPay(_cashButton, Active.Pay == PayKind.Cash);
        PaintPay(_cardButton, Active.Pay == PayKind.Card);
        PaintPay(_modernButton, Active.Pay == PayKind.Modern);
        ShowModern();
        RefreshTabs();
        RefreshReceipt();
    }

    private void OpenTicket()
    {
        if (_tickets.Count >= 4)
        {
            _ = Tell("Sunt deschise deja 4 bonuri. Închideți unul gol sau emiteți un bon ca să eliberați locul.");
            return;
        }
        _tickets.Add(new Ticket());
        ShowTicket(_tickets.Count - 1);
    }

    private void CloseTicket(int index)
    {
        if (_tickets.Count < 2 || index < 0 || index >= _tickets.Count || _tickets[index].Lines.Count > 0)
            return;
        _tickets.RemoveAt(index);
        if (_active >= _tickets.Count)
            _active = _tickets.Count - 1;
        else if (index < _active)
            _active -= 1;
        ShowTicket(_active);
    }

    private Ticket Active => _tickets[_active];

    private Task OpenDiscountPad() =>
        ShowKeypad("Discount %", Active.DiscountText, NormalizePercent, ",", "0", money: false, verifyCui: false, value =>
        {
            Active.DiscountText = value;
            _discountBox.Text = value;
            RefreshReceipt();
        });

    private Task OpenTenderPad()
    {
        if (Active.Pay != PayKind.Cash)
            return Task.CompletedTask;
        return ShowKeypad("Sumă primită", Active.Tender, NormalizeTender, ",", "0,00", money: true, verifyCui: false, value => _tenderBox.Text = value);
    }

    private Task OpenCuiPad() =>
        ShowKeypad("CUI client", Active.Cui, NormalizeCui, "RO", "CUI", money: false, verifyCui: true, value => _cuiBox.Text = value);

    private async Task ShowKeypad(
        string title,
        string initial,
        Func<string, string> normalize,
        string sideKey,
        string placeholder,
        bool money,
        bool verifyCui,
        Action<string> commitValue)
    {
        if (_padOpen)
            return;
        _padOpen = true;
        try
        {
            var value = initial;
            var checking = false;
            var closed = false;
            var window = new Window
            {
                Title = title,
                Width = 360,
                SizeToContent = SizeToContent.Height,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                CanResize = false,
                Topmost = true,
                Icon = Brand.WindowIcon(),
                Background = Brushes.White
            };
            var display = new TextBlock
            {
                FontSize = 36,
                FontWeight = FontWeight.Bold,
                Foreground = Brand.Brush(Brand.Navy),
                HorizontalAlignment = HorizontalAlignment.Right,
                Margin = new Avalonia.Thickness(8, 4, 8, 0)
            };
            var restLine = new TextBlock
            {
                FontSize = 16,
                HorizontalAlignment = HorizontalAlignment.Right,
                Margin = new Avalonia.Thickness(8, 0, 8, 8),
                IsVisible = money
            };
            void RefreshPad()
            {
                display.Text = string.IsNullOrEmpty(value) ? placeholder : value;
                display.Opacity = string.IsNullOrEmpty(value) ? 0.35 : 1;
                if (!money)
                    return;
                var total = TicketTotal(Active);
                if (TryMoney(value, out var received) && received > 0 && received < total)
                {
                    restLine.Text = "Sumă insuficientă";
                    restLine.Foreground = Brushes.Firebrick;
                    return;
                }
                var change = TryMoney(value, out received) && received >= total ? received - total : 0;
                restLine.Text = "Rest  " + Money(change);
                restLine.Foreground = Brand.Brush(Brand.Navy);
            }
            void Push(string text)
            {
                value = normalize(value + text);
                RefreshPad();
            }
            void PushSide()
            {
                if (sideKey == "RO")
                {
                    if (!value.StartsWith("RO", StringComparison.Ordinal))
                        value = normalize("RO" + value);
                }
                else
                    value = normalize(value + sideKey);
                RefreshPad();
            }
            void Backspace()
            {
                if (value.Length > 0)
                    value = value[..^1];
                RefreshPad();
            }
            Grid keys;
            async Task Commit()
            {
                if (checking || closed)
                    return;
                if (!verifyCui || string.IsNullOrEmpty(value))
                {
                    commitValue(value);
                    window.Close();
                    return;
                }

                checking = true;
                keys.IsEnabled = false;
                restLine.IsVisible = true;
                restLine.Text = "Se verifică la ANAF...";
                restLine.Foreground = Brand.Brush(Brand.Muted);
                var result = await AnafCui.Check(value);
                checking = false;
                if (closed)
                    return;
                keys.IsEnabled = true;
                if (result.Result == AnafCui.CheckResult.Valid)
                {
                    var shown = result.FiscalCode.Length > 0 ? result.FiscalCode : normalize(value);
                    _pendingClientName = result.Name;
                    _pendingClientAddress = result.Address;
                    commitValue(shown);
                    window.Close();
                    return;
                }

                restLine.IsVisible = false;
                var shownCui = result.FiscalCode.Length > 0 ? result.FiscalCode : normalize(value);
                var blocked = result.Result == AnafCui.CheckResult.Blocked;
                var keepEditing = blocked
                    ? await AskCuiBlocked(window, result.Name, shownCui, result.Status)
                    : await AskCuiFix(window, result.Result == AnafCui.CheckResult.Unavailable);
                if (closed)
                    return;
                if (keepEditing)
                {
                    RefreshPad();
                    return;
                }
                commitValue("");
                window.Close();
            }

            keys = new Grid
            {
                ColumnDefinitions = new ColumnDefinitions("*,*,*"),
                RowDefinitions = new RowDefinitions("Auto,Auto,Auto,Auto,Auto"),
                Margin = new Avalonia.Thickness(8, 0, 8, 12)
            };
            void Place(Control control, int column, int row, int columnSpan = 1)
            {
                Grid.SetColumn(control, column);
                Grid.SetRow(control, row);
                if (columnSpan > 1)
                    Grid.SetColumnSpan(control, columnSpan);
                keys.Children.Add(control);
            }
            string[,] digits =
            {
                { "7", "8", "9" },
                { "4", "5", "6" },
                { "1", "2", "3" }
            };
            for (var row = 0; row < 3; row++)
            {
                for (var column = 0; column < 3; column++)
                {
                    var digit = digits[row, column];
                    Place(PadKey(digit, () => Push(digit)), column, row);
                }
            }
            Place(PadKey(sideKey, PushSide), 0, 3);
            Place(PadKey("0", () => Push("0")), 1, 3);
            Place(PadKey("⌫", Backspace), 2, 3);
            Place(PadKey("Enter", () => _ = Commit(), accent: true), 0, 4, 3);

            var root = new StackPanel();
            root.Children.Add(display);
            root.Children.Add(restLine);
            root.Children.Add(keys);
            window.Content = root;
            window.Closed += (_, _) => closed = true;
            RefreshPad();
            window.KeyDown += (_, e) =>
            {
                if (e.Key is >= Key.D0 and <= Key.D9)
                    Push(((int)e.Key - (int)Key.D0).ToString());
                else if (e.Key is >= Key.NumPad0 and <= Key.NumPad9)
                    Push(((int)e.Key - (int)Key.NumPad0).ToString());
                else if (money && e.Key is Key.OemComma or Key.OemPeriod or Key.Decimal)
                    Push(",");
                else if (!money && e.Key is Key.R)
                    PushSide();
                else if (e.Key == Key.Back)
                    Backspace();
                else if (e.Key is Key.Enter or Key.Return)
                    _ = Commit();
                else
                    return;
                e.Handled = true;
            };
            if (TopLevel.GetTopLevel(this) is Window parent)
                await window.ShowDialog(parent);
            else
                window.Show();
        }
        finally
        {
            _padOpen = false;
        }
    }

    private static async Task<bool> AskCuiFix(Window owner, bool unavailable)
    {
        var window = new Window
        {
            Title = "CUI client",
            Width = 480,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            CanResize = false,
            Topmost = true,
            Icon = Brand.WindowIcon(),
            Background = Brushes.White
        };
        var keepEditing = true;
        var panel = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 16 };
        panel.Children.Add(new TextBlock
        {
            Text = unavailable
                ? "Nu am putut verifica CUI-ul la ANAF. Puteți corecta și încerca din nou, sau reveniți în bon fără CUI."
                : "CUI-ul completat nu este corect.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Navy)
        });
        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Spacing = 8
        };
        var drop = new Button { Content = "Fără CUI", Padding = new Avalonia.Thickness(14, 8) };
        var fix = new Button
        {
            Content = "Corectează",
            Padding = new Avalonia.Thickness(14, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        drop.Click += (_, _) =>
        {
            keepEditing = false;
            window.Close();
        };
        fix.Click += (_, _) =>
        {
            keepEditing = true;
            window.Close();
        };
        buttons.Children.Add(drop);
        buttons.Children.Add(fix);
        panel.Children.Add(buttons);
        window.Content = panel;
        await window.ShowDialog(owner);
        return keepEditing;
    }

    private static async Task<bool> AskCuiBlocked(Window owner, string name, string cui, string status)
    {
        var window = new Window
        {
            Title = "CUI client",
            Width = 520,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            CanResize = false,
            Topmost = true,
            Icon = Brand.WindowIcon(),
            Background = Brushes.White
        };
        var keepEditing = true;
        var panel = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 16 };
        panel.Children.Add(new TextBlock
        {
            Text = "Nu se poate emite BF / FF pentru clientul " + name + " cu CUI " + cui + ", deoarece starea lui este: " + status,
            TextWrapping = TextWrapping.Wrap,
            FontWeight = FontWeight.Bold,
            Foreground = Brushes.Red
        });
        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Spacing = 8
        };
        var drop = new Button { Content = "Fără CUI", Padding = new Avalonia.Thickness(14, 8) };
        var fix = new Button
        {
            Content = "Corectează",
            Padding = new Avalonia.Thickness(14, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        drop.Click += (_, _) =>
        {
            keepEditing = false;
            window.Close();
        };
        fix.Click += (_, _) =>
        {
            keepEditing = true;
            window.Close();
        };
        buttons.Children.Add(drop);
        buttons.Children.Add(fix);
        panel.Children.Add(buttons);
        window.Content = panel;
        await window.ShowDialog(owner);
        return keepEditing;
    }

    private static Button PadKey(string label, Action action, bool accent = false)
    {
        var button = new Button
        {
            Content = label,
            FontSize = accent ? 18 : 26,
            FontWeight = FontWeight.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            MinHeight = accent ? 56 : 68,
            Margin = new Avalonia.Thickness(4),
            Background = accent ? Brand.Brush(Brand.Gold) : Brushes.White,
            Foreground = Brand.Brush(Brand.Navy),
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(1),
            CornerRadius = new Avalonia.CornerRadius(10)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private async Task Emit()
    {
        if (Active.Lines.Count == 0)
        {
            await Tell("Adăugați produse pe bon.");
            return;
        }
        var channel = TakingChannel(Active);
        if (channel == null)
        {
            await Tell("Alegeți Glovo, Bolt sau Wolt.");
            return;
        }
        var amount = TicketTotal(Active);
        var payment = PaymentName(channel);
        var slipLines = SlipLines(Active);
        var invoiceLines = InvoiceLines(Active);
        var bands = VatBands(Active);
        var stock = StockCuts(Active);
        var total = Ron(amount);
        if (!(Active.PrintInvoice && !string.IsNullOrEmpty(Active.Cui)))
        {
            try
            {
                await RecordTaking(channel, amount);
                var stockNote = await ConsumeStock(stock);
                await LoadTakings();
                ClearSoldTicket();
                await Tell("Imprimanta fiscală nu este legată, bonul nu s-a tipărit. Încasarea a intrat în recapitularea de la ultimul Z." + stockNote);
            }
            catch (Exception ex)
            {
                await Tell(ex.Message);
            }
            return;
        }
        try
        {
            var series = await FiscalSeries();
            if (series == null)
            {
                await Tell("Nu există serie de factură fiscală pentru acest punct de lucru. O adăugați în Nomenclatoare → Societăți → Serii documente.");
                return;
            }
            var storage = TopLevel.GetTopLevel(this)?.StorageProvider;
            if (storage == null)
                return;
            var folders = await storage.OpenFolderPickerAsync(new FolderPickerOpenOptions
            {
                Title = "Folder pentru bon și factură",
                AllowMultiple = false
            });
            var folder = folders.FirstOrDefault()?.TryGetLocalPath();
            if (string.IsNullOrEmpty(folder))
                return;
            var issued = await _session.Rpc("consume_fiscal_invoice_number", new { p_series_id = series.Value.ToString() });
            if (issued.ValueKind != JsonValueKind.Array || issued.GetArrayLength() == 0)
                throw new InvalidOperationException("Nu am putut rezerva numărul facturii.");
            var row = issued[0];
            var serie = row.GetProperty("serie").GetString() ?? "";
            var number = row.GetProperty("issued_number").GetInt32();
            var clientName = Active.ClientName;
            var clientAddress = Active.ClientAddress;
            if (string.IsNullOrEmpty(clientName) || string.IsNullOrEmpty(clientAddress))
            {
                var lookup = await AnafCui.Check(Active.Cui);
                if (lookup.Result == AnafCui.CheckResult.Valid)
                {
                    if (string.IsNullOrEmpty(clientName)) clientName = lookup.Name;
                    if (string.IsNullOrEmpty(clientAddress)) clientAddress = lookup.Address;
                }
            }
            var supplier = await SupplierLines();
            var stamp = DateTime.Now;
            var shown = stamp.ToString("dd.MM.yyyy HH:mm", CultureInfo.GetCultureInfo("ro-RO"));
            var fileStamp = stamp.ToString("yyyy-MM-dd HHmm", CultureInfo.InvariantCulture);
            var bonName = "Bon fiscal " + fileStamp + ".pdf";
            var invoiceName = "Factura " + serie + " " + number + ".pdf";
            if (_session.CurrentCompany == null)
                throw new InvalidOperationException("Selectați societatea.");
            var companyId = _session.CurrentCompany.Id;
            var online = System.Net.NetworkInformation.NetworkInterface.GetIsNetworkAvailable();
            var bonUrl = "";
            var invoiceUrl = "";
            string? bonPath = null;
            string? invoicePath = null;
            if (online)
            {
                var bonTarget = _session.PosDocumentTarget(companyId);
                var invoiceTarget = _session.PosDocumentTarget(companyId);
                bonUrl = bonTarget.Url;
                invoiceUrl = invoiceTarget.Url;
                bonPath = bonTarget.Path;
                invoicePath = invoiceTarget.Path;
            }
            var bonBytes = PosSlipPdf.Make(ReceiptRows(supplier, shown, clientName, payment, slipLines, total, bands, bonUrl));
            var invoiceBytes = PosSlipPdf.Make(InvoiceRows(supplier, serie, number, shown, clientName, clientAddress, payment, invoiceLines, total, invoiceUrl));
            if (bonPath != null && invoicePath != null)
            {
                try
                {
                    await _session.UploadPosDocument(bonPath, bonBytes);
                    await _session.UploadPosDocument(invoicePath, invoiceBytes);
                }
                catch
                {
                    bonBytes = PosSlipPdf.Make(ReceiptRows(supplier, shown, clientName, payment, slipLines, total, bands, ""));
                    invoiceBytes = PosSlipPdf.Make(InvoiceRows(supplier, serie, number, shown, clientName, clientAddress, payment, invoiceLines, total, ""));
                }
            }
            await File.WriteAllBytesAsync(Path.Combine(folder, bonName), bonBytes);
            await File.WriteAllBytesAsync(Path.Combine(folder, invoiceName), invoiceBytes);
            var recap = "";
            try
            {
                await RecordTaking(channel, amount);
                await LoadTakings();
            }
            catch (Exception ex)
            {
                recap = "\n" + ex.Message;
            }
            recap += await ConsumeStock(stock);
            ClearSoldTicket();
            await Tell("Au fost salvate două fișiere:\n" + bonName + "\n" + invoiceName + recap);
        }
        catch (Exception ex)
        {
            await Tell(ex.Message);
        }
    }

    private async Task<Guid?> FiscalSeries()
    {
        if (_session.CurrentCompany == null)
            return null;
        var rows = await _session.SelectRows(
            "document_series",
            "company_id=eq." + _session.CurrentCompany.Id
            + "&work_location_id=eq." + _locationId
            + "&kind=eq.factura_fiscala_casa&is_active=eq.true&select=id&limit=1");
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            return null;
        var id = rows[0].GetProperty("id").GetString() ?? "";
        return Guid.TryParse(id, out var guid) ? guid : null;
    }

    private static string? TakingChannel(Ticket ticket)
    {
        if (ticket.Pay == PayKind.Card)
            return "card";
        if (ticket.Pay == PayKind.Cash)
            return "cash";
        return ticket.Channel is "glovo" or "bolt" or "wolt" ? ticket.Channel : null;
    }

    private static string PaymentName(string channel) => channel switch
    {
        "card" => "Card",
        "glovo" => "Glovo",
        "bolt" => "Bolt",
        "wolt" => "Wolt",
        _ => "Numerar"
    };

    private async Task RecordTaking(string channel, decimal amount)
    {
        if (amount <= 0)
            return;
        await _session.Rpc("pos_record_taking", new
        {
            p_work_location_id = _locationId,
            p_channel = channel,
            p_amount = amount.ToString("0.00", CultureInfo.InvariantCulture)
        });
    }

    private async Task LoadTakings()
    {
        try
        {
            var rows = await _session.Rpc("pos_open_takings", new { p_work_location_id = _locationId });
            decimal cash = 0, card = 0, glovo = 0, bolt = 0, wolt = 0;
            if (rows.ValueKind == JsonValueKind.Array && rows.GetArrayLength() > 0)
            {
                var row = rows[0];
                cash = Number(row, "cash");
                card = Number(row, "card");
                glovo = Number(row, "glovo");
                bolt = Number(row, "bolt");
                wolt = Number(row, "wolt");
            }
            var text = "Numerar = " + Money(cash)
                + "    Card = " + Money(card)
                + "    Glovo = " + Money(glovo)
                + "    Bolt = " + Money(bolt)
                + "    Wolt = " + Money(wolt);
            await Dispatcher.UIThread.InvokeAsync(() => _takings.Text = text);
        }
        catch
        {
            await Dispatcher.UIThread.InvokeAsync(() => _takings.Text = "Încasările de la ultimul Z nu au putut fi citite.");
        }
    }

    private async Task CloseZ()
    {
        try
        {
            await _session.Rpc("pos_close_takings_z", new { p_work_location_id = _locationId });
            await LoadTakings();
            await Tell("Imprimanta nu este legată, raportul Z nu s-a tipărit. Încasările de până acum au fost închise.");
        }
        catch (Exception ex)
        {
            await Tell(ex.Message);
        }
    }

    private void RefreshEmitButton()
    {
        if (_emit == null)
            return;
        _emit.Content = Active.PrintInvoice && !string.IsNullOrEmpty(Active.Cui) ? "Emite bon și FF" : "Emite bon";
    }

    private void ClearSoldTicket()
    {
        Active.Lines.Clear();
        Active.Cui = "";
        Active.ClientName = "";
        Active.ClientAddress = "";
        Active.Tender = "";
        Active.DiscountText = "";
        Active.PrintInvoice = false;
        Active.Pay = PayKind.Cash;
        Active.Channel = "";
        _loadingTicket = true;
        _cuiBox.Text = "";
        _tenderBox.Text = "";
        _discountBox.Text = "";
        _printInvoice.IsChecked = false;
        _loadingTicket = false;
        PaintPay(_cashButton, true);
        PaintPay(_cardButton, false);
        PaintPay(_modernButton, false);
        ShowClientName();
        SyncInvoiceBox();
        RefreshReceipt();
    }

    private async Task<List<string>> SupplierLines()
    {
        var lines = new List<string>();
        if (_session.CurrentCompany == null)
            return lines;
        var rows = await _session.SelectRows(
            "companies",
            "id=eq." + _session.CurrentCompany.Id + "&select=denumire,cui,adresa,hq_street,hq_street_number,hq_city,hq_county&limit=1");
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
        {
            lines.Add(_session.CurrentCompany.Denumire);
            return lines;
        }
        var row = rows[0];
        lines.Add(Text(row, "denumire"));
        var cui = Text(row, "cui");
        if (cui.Length > 0)
            lines.Add("CUI " + cui);
        var address = Text(row, "adresa");
        if (address.Length == 0)
        {
            var street = string.Join(" ", new[] { Text(row, "hq_street"), Text(row, "hq_street_number") }.Where(part => part.Length > 0));
            var place = string.Join(", ", new[] { Text(row, "hq_city"), Text(row, "hq_county") }.Where(part => part.Length > 0));
            address = string.Join(", ", new[] { street, place }.Where(part => part.Length > 0));
        }
        if (address.Length > 0)
            lines.Add(address);
        return lines;
    }

    private static List<(string Name, string Amount)> SlipLines(Ticket ticket)
    {
        var rows = new List<(string, string)>();
        foreach (var line in ticket.Lines)
        {
            if (line.MenuHeader)
            {
                rows.Add((LineLabel(line.Quantity, line.Name), ""));
                continue;
            }
            var onMenu = line.MenuBlock != null;
            var amount = Ron(line.UnitPrice * line.Quantity);
            rows.Add((LineLabel(line.Quantity, line.Name), MarkedAmount(amount, line.VatRate, onMenu)));
            if (line.DiscountAmount > 0 || line.ShowsDiscount)
                rows.Add(("Discount 100%", Ron(-line.DiscountAmount)));
            foreach (var addon in line.Addons)
            {
                if (IsSgr(addon.Name))
                    continue;
                rows.Add((addon.Name, MarkedAmount(Ron(addon.PerUnit * line.Quantity * addon.UnitPrice), addon.VatRate, onMenu)));
            }
        }
        foreach (var sgr in SgrLines(ticket.Lines))
            rows.Add((QtyText(sgr.Quantity) + " " + sgr.Name, MarkedAmount(Ron(sgr.Amount), sgr.VatRate, sgr.FromMenu)));
        var discount = PercentCuts(ticket).Discount;
        if (discount > 0)
            rows.Add((DiscountTitle(ticket), Ron(-discount)));
        return rows;
    }

    private readonly record struct InvoiceLine(string Name, string Quantity, string UnitNet, string Value, string Vat, decimal NetAmount, decimal VatAmount, string Rate = "");

    private static List<InvoiceLine> InvoiceLines(Ticket ticket)
    {
        var rows = new List<InvoiceLine>();
        foreach (var line in ticket.Lines)
        {
            if (line.MenuHeader)
            {
                rows.Add(new InvoiceLine(line.Name, "", "", "", "", 0, 0));
                continue;
            }
            rows.Add(InvoiceFigure(line.Name, line.Quantity, line.UnitPrice * line.Quantity, line.VatRate));
            if (line.DiscountAmount > 0 || line.ShowsDiscount)
                rows.Add(InvoiceFigure("Discount 100%", line.Quantity, -line.DiscountAmount, line.VatRate));
            foreach (var addon in line.Addons)
            {
                if (IsSgr(addon.Name))
                    continue;
                var quantity = addon.PerUnit * line.Quantity;
                rows.Add(InvoiceFigure(addon.Name, quantity, quantity * addon.UnitPrice, addon.VatRate));
            }
        }
        foreach (var sgr in SgrLines(ticket.Lines))
            rows.Add(InvoiceFigure(sgr.Name, sgr.Quantity, sgr.Amount, sgr.VatRate));
        var title = DiscountTitle(ticket);
        foreach (var cut in PercentCuts(ticket).Cuts)
        {
            if (cut.Gross != 0)
                rows.Add(InvoiceFigure(title, 1, -cut.Gross, cut.Rate));
        }
        return rows;
    }

    private static InvoiceLine InvoiceFigure(string name, decimal quantity, decimal gross, decimal? rate)
    {
        var rounded = RoundMoney(gross);
        var vat = ExtractedVat(rounded, rate);
        var net = rounded - vat;
        var unit = quantity == 0 ? 0 : RoundMoney(net / quantity);
        var percent = (rate ?? 0).ToString("0.##", CultureInfo.GetCultureInfo("ro-RO")) + "%";
        return new InvoiceLine(name, QtyText(quantity), Money(unit), Money(net), Money(vat), net, vat, percent);
    }

    private static decimal ExtractedVat(decimal gross, decimal? rate)
    {
        var percent = rate ?? 0;
        if (percent <= 0 || gross == 0)
            return 0;
        return RoundMoney(gross * percent / (percent + 100));
    }

    private static string MarkedAmount(string amount, decimal? vat, bool marked)
    {
        if (!marked)
            return amount;
        var mark = VatMark(vat, true);
        return mark.Length == 0 ? amount : mark + "  " + amount;
    }

    private static string VatMark(decimal? rate, bool detailed)
    {
        var letter = VatLetter(rate);
        if (!detailed || letter.Length == 0 || rate == null)
            return letter;
        return letter + " " + rate.Value.ToString("0.##", CultureInfo.GetCultureInfo("ro-RO")) + "%";
    }

    private static List<(Guid ProductId, decimal Quantity)> StockCuts(Ticket ticket)
    {
        var totals = new Dictionary<Guid, decimal>();
        foreach (var line in ticket.Lines)
        {
            if (line.ProductId is not Guid productId)
                continue;
            totals[productId] = totals.GetValueOrDefault(productId) + line.Quantity;
            foreach (var addon in line.Addons)
            {
                if (addon.ProductId is not Guid addonId)
                    continue;
                totals[addonId] = totals.GetValueOrDefault(addonId) + addon.PerUnit * line.Quantity;
            }
        }
        return totals.Where(pair => pair.Value > 0).Select(pair => (pair.Key, pair.Value)).ToList();
    }

    private async Task<string> ConsumeStock(List<(Guid ProductId, decimal Quantity)> items)
    {
        if (items.Count == 0)
            return "";
        try
        {
            var payload = items.Select(item => new Dictionary<string, object>
            {
                ["product_id"] = item.ProductId,
                ["cantitate"] = item.Quantity.ToString(CultureInfo.InvariantCulture)
            }).ToList();
            await _session.Rpc("pos_consume_stock", new Dictionary<string, object> { ["p_items"] = payload });
            return "";
        }
        catch (Exception ex)
        {
            return "\n" + ex.Message;
        }
    }

    private List<PosSlipPdf.Row> ReceiptRows(List<string> supplier, string stamp, string clientName, string payment, List<(string Name, string Amount)> lines, string total, List<VatBand> bands, string documentUrl)
    {
        var rows = new List<PosSlipPdf.Row> { PosSlipPdf.Title("BON FISCAL") };
        rows.AddRange(supplier.Select(line => PosSlipPdf.Center(line, 7)));
        rows.Add(PosSlipPdf.Center(_locationName, 7));
        rows.Add(PosSlipPdf.Center(stamp));
        rows.Add(PosSlipPdf.Line(" "));
        rows.Add(PosSlipPdf.Line("CUI client " + Active.Cui));
        if (clientName.Length > 0)
            rows.Add(PosSlipPdf.Line(clientName, bold: true));
        rows.Add(PosSlipPdf.Line(" "));
        foreach (var line in lines)
            rows.Add(PosSlipPdf.Pair(line.Name, line.Amount));
        rows.Add(PosSlipPdf.Line(" "));
        rows.Add(PosSlipPdf.Pair("TOTAL", total, bold: true));
        foreach (var band in bands)
        {
            rows.Add(PosSlipPdf.Pair("BRUT " + band.Letter, Ron(band.Gross)));
            rows.Add(PosSlipPdf.Pair("TVA " + band.Rate + "%", Ron(band.Vat)));
        }
        rows.Add(PosSlipPdf.Line(payment));
        if (Active.Pay == PayKind.Cash && Active.Tender.Length > 0)
            rows.Add(PosSlipPdf.Line("Primește " + Active.Tender));
        rows.Add(PosSlipPdf.Line(" "));
            if (!string.IsNullOrEmpty(documentUrl))
                rows.Add(PosSlipPdf.Qr(documentUrl));
        rows.Add(PosSlipPdf.Center("PDF — imprimanta fiscală nu este conectată", 6));
        rows.Add(PosSlipPdf.Line(" "));
        rows.Add(PosSlipPdf.Center("Document generat cu ERP Mobile by DateConta", 6));
        return rows;
    }

    private List<PosSlipPdf.Row> InvoiceRows(List<string> supplier, string serie, int number, string stamp, string clientName, string clientAddress, string payment, List<InvoiceLine> lines, string total, string documentUrl)
    {
        var rows = new List<PosSlipPdf.Row>
        {
            PosSlipPdf.Title("FACTURĂ FISCALĂ"),
            PosSlipPdf.Center(serie + " " + number, 10),
            PosSlipPdf.Center(stamp),
            PosSlipPdf.Line(" "),
            PosSlipPdf.Line("FURNIZOR", bold: true)
        };
        rows.AddRange(supplier.Select(line => PosSlipPdf.Line(line, 7)));
        rows.Add(PosSlipPdf.Line(" "));
        rows.Add(PosSlipPdf.Line("CLIENT", bold: true));
        if (clientName.Length > 0)
            rows.Add(PosSlipPdf.Line(clientName, bold: true));
        rows.Add(PosSlipPdf.Line("CUI " + Active.Cui));
        if (clientAddress.Length > 0)
            rows.Add(PosSlipPdf.Line(clientAddress, 7));
        rows.Add(PosSlipPdf.Line(" "));
        rows.Add(PosSlipPdf.Cells(new[] { "Cant.", "Preț f. TVA", "Valoare", "TVA", "%" }, 6));
        foreach (var line in lines)
        {
            rows.Add(PosSlipPdf.Line(line.Name, bold: true));
            if (line.Quantity.Length > 0)
                rows.Add(PosSlipPdf.Cells(new[] { line.Quantity, line.UnitNet, line.Value, line.Vat, line.Rate }));
        }
        rows.Add(PosSlipPdf.Line(" "));
        var net = lines.Sum(line => line.NetAmount);
        var vat = lines.Sum(line => line.VatAmount);
        rows.Add(PosSlipPdf.Pair("Baza", Ron(net)));
        rows.Add(PosSlipPdf.Pair("TVA", Ron(vat)));
        rows.Add(PosSlipPdf.Pair("TOTAL", total, bold: true));
        rows.Add(PosSlipPdf.Line("Încasare: " + payment));
        rows.Add(PosSlipPdf.Line(" "));
            if (!string.IsNullOrEmpty(documentUrl))
                rows.Add(PosSlipPdf.Qr(documentUrl));
        rows.Add(PosSlipPdf.Center("80 mm · PDF — imprimanta fiscală nu este conectată", 6));
        rows.Add(PosSlipPdf.Line(" "));
        rows.Add(PosSlipPdf.Center("Document generat cu ERP Mobile by DateConta", 6));
        return rows;
    }

    private void ShowClientName()
    {
        var name = Active.ClientName;
        _clientName.Text = name;
        _clientName.IsVisible = name.Length > 0;
    }

    private void SyncInvoiceBox()
    {
        var hasCui = !string.IsNullOrEmpty(Active.Cui);
        _printInvoice.IsVisible = hasCui;
        _printHint.IsVisible = hasCui;
        if (!hasCui && _printInvoice.IsChecked == true)
        {
            _loadingTicket = true;
            _printInvoice.IsChecked = false;
            _loadingTicket = false;
        }
        RefreshEmitButton();
    }

    private async Task Tell(string message)
    {
        var window = new Window
        {
            Title = "POS",
            Width = 480,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            CanResize = false,
            Icon = Brand.WindowIcon(),
            Background = Brushes.White
        };
        var panel = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 16 };
        panel.Children.Add(new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Navy) });
        var ok = new Button
        {
            Content = "OK",
            HorizontalAlignment = HorizontalAlignment.Right,
            Padding = new Avalonia.Thickness(18, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        ok.Click += (_, _) => window.Close();
        panel.Children.Add(ok);
        window.Content = panel;
        if (TopLevel.GetTopLevel(this) is Window parent)
            await window.ShowDialog(parent);
        else
            window.Show();
    }

    private static Button GroupTile(string name, Action open)
    {
        var button = new Button
        {
            Width = 220,
            Height = 140,
            Margin = new Avalonia.Thickness(0, 0, 12, 12),
            Background = Brushes.White,
            CornerRadius = new Avalonia.CornerRadius(14),
            HorizontalContentAlignment = HorizontalAlignment.Center,
            VerticalContentAlignment = VerticalAlignment.Center
        };
        button.Content = new TextBlock
        {
            Text = name,
            FontSize = 18,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            TextWrapping = TextWrapping.Wrap,
            TextAlignment = TextAlignment.Center,
            Margin = new Avalonia.Thickness(12)
        };
        button.Click += (_, _) => open();
        return button;
    }

    private static Control ProductTile(string name, string code, string price, string imageUrl, Action? onTap)
    {
        var button = new Button
        {
            Width = 160,
            Height = 260,
            Margin = new Avalonia.Thickness(0, 0, 8, 8),
            Background = Brushes.White,
            Padding = new Avalonia.Thickness(10),
            CornerRadius = new Avalonia.CornerRadius(14),
            HorizontalContentAlignment = HorizontalAlignment.Stretch,
            VerticalContentAlignment = VerticalAlignment.Stretch
        };
        var grid = new Grid { RowDefinitions = new RowDefinitions("*,Auto") };
        var imageZone = new Grid { Height = 140 };
        var photo = new Image
        {
            Width = 112,
            Height = 112,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        imageZone.Children.Add(photo);
        imageZone.Children.Add(new TextBlock
        {
            Text = price,
            FontWeight = FontWeight.Bold,
            FontSize = 13,
            Foreground = Brand.Brush(Brand.Navy),
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top,
            Background = Brushes.White
        });
        grid.Children.Add(imageZone);
        var title = new StackPanel
        {
            Spacing = 2,
            Margin = new Avalonia.Thickness(0, 8, 0, 0)
        };
        title.Children.Add(new TextBlock
        {
            Text = name,
            TextAlignment = TextAlignment.Center,
            TextWrapping = TextWrapping.Wrap,
            MaxHeight = 60,
            FontSize = 14,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            HorizontalAlignment = HorizontalAlignment.Stretch
        });
        if (!string.IsNullOrWhiteSpace(code))
        {
            title.Children.Add(new TextBlock
            {
                Text = code,
                FontSize = 12,
                Foreground = Brand.Brush(Brand.Muted),
                TextAlignment = TextAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Stretch
            });
        }
        Grid.SetRow(title, 1);
        grid.Children.Add(title);
        button.Content = grid;
        if (onTap != null)
            button.Click += (_, _) => onTap();
        if (!string.IsNullOrWhiteSpace(imageUrl))
            _ = LoadPhoto(photo, imageUrl);
        return button;
    }

    private static Button ReportButton(string title, bool filled, Action action)
    {
        var button = new Button
        {
            Content = title,
            Background = filled ? Brand.Brush(Brand.Navy) : Brushes.White,
            Foreground = filled ? Brushes.White : Brand.Brush(Brand.Navy),
            BorderBrush = Brand.Brush(Brand.Navy),
            BorderThickness = new Avalonia.Thickness(filled ? 0 : 1),
            FontWeight = FontWeight.SemiBold,
            Padding = new Avalonia.Thickness(16, 10),
            CornerRadius = new Avalonia.CornerRadius(10),
            VerticalAlignment = VerticalAlignment.Center
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static Button PayButton(string title, bool selected, Action action)
    {
        var button = new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            FontWeight = FontWeight.SemiBold,
            FontSize = 13,
            Padding = new Avalonia.Thickness(4, 12),
            CornerRadius = new Avalonia.CornerRadius(8),
            BorderBrush = Brand.Brush(Brand.Navy),
            BorderThickness = new Avalonia.Thickness(1)
        };
        PaintPay(button, selected);
        button.Click += (_, _) => action();
        return button;
    }

    private static void PaintPay(Button button, bool selected)
    {
        button.Background = selected ? Brand.Brush(Brand.Navy) : Brushes.White;
        button.Foreground = selected ? Brushes.White : Brand.Brush(Brand.Navy);
    }

    private static Control ReceiptLine(string qty, string name, string amount, string vat, bool addon, Action? remove = null)
    {
        var color = addon ? Brand.Brush(Brand.Muted) : Brand.Brush(Brand.Navy);
        var vatWidth = vat.Length > 1 ? "52" : "18";
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("22,*," + vatWidth + ",Auto,28"), Margin = new Avalonia.Thickness(0, 2) };
        grid.Children.Add(new TextBlock { Text = qty, Foreground = color, FontSize = addon ? 14 : 15 });
        var label = new TextBlock { Text = name, Foreground = color, TextWrapping = TextWrapping.Wrap, FontSize = addon ? 14 : 15 };
        Grid.SetColumn(label, 1);
        var letter = new TextBlock { Text = vat, Foreground = color, FontSize = 12, FontWeight = FontWeight.Bold, HorizontalAlignment = HorizontalAlignment.Right };
        Grid.SetColumn(letter, 2);
        var value = new TextBlock { Text = amount, Foreground = color, FontSize = addon ? 14 : 15 };
        Grid.SetColumn(value, 3);
        grid.Children.Add(label);
        grid.Children.Add(letter);
        grid.Children.Add(value);
        if (remove != null)
        {
            var button = new Button
            {
                Content = "×",
                Background = Brushes.Transparent,
                Foreground = Brushes.Firebrick,
                FontWeight = FontWeight.Bold,
                FontSize = 16,
                Padding = new Avalonia.Thickness(4, 0),
                BorderThickness = new Avalonia.Thickness(0),
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            ToolTip.SetTip(button, "Șterge de pe bon");
            button.Click += (_, _) => remove();
            Grid.SetColumn(button, 4);
            grid.Children.Add(button);
        }
        return grid;
    }

    private static async Task LoadPhoto(Image target, string url)
    {
        try
        {
            var bytes = await Http.GetByteArrayAsync(url);
            var bitmap = new Avalonia.Media.Imaging.Bitmap(new MemoryStream(bytes));
            await Dispatcher.UIThread.InvokeAsync(() => target.Source = bitmap);
        }
        catch
        {
            // Produsul rămâne fără poză dacă adresa nu poate fi citită.
        }
    }

    private Guid RequireCompany()
    {
        if (_session.CurrentCompany == null)
            throw new InvalidOperationException("Selectați o societate.");
        return _session.CurrentCompany.Id;
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

    private static string Money(decimal value) =>
        value.ToString("0.00", CultureInfo.GetCultureInfo("ro-RO"));

    private static string Ron(decimal value) => Money(value) + " RON";

    private static decimal TicketTotal(Ticket ticket) =>
        Subtotal(ticket) - PercentCuts(ticket).Discount;

    private static decimal Subtotal(Ticket ticket)
    {
        decimal total = 0;
        foreach (var row in ticket.Lines)
        {
            total += row.UnitPrice * row.Quantity - row.DiscountAmount;
            foreach (var addon in row.Addons)
                total += addon.PerUnit * row.Quantity * addon.UnitPrice;
        }
        return total;
    }

    private static decimal DiscountPercent(Ticket ticket)
    {
        if (!TryMoney(ticket.DiscountText, out var percent) || percent <= 0)
            return 0;
        return Math.Min(100, percent);
    }

    private static string DiscountTitle(Ticket ticket)
    {
        var percent = DiscountPercent(ticket);
        return "Discount " + percent.ToString("0.##", CultureInfo.GetCultureInfo("ro-RO")) + "%";
    }

    private readonly record struct PercentCut(int Rate, decimal Gross);

    private readonly record struct SaleCuts(decimal Discount, List<PercentCut> Cuts, List<VatBand> Bands);

    private static SaleCuts PercentCuts(Ticket ticket)
    {
        decimal grossA = 0, grossB = 0, grossD = 0;
        decimal sgrA = 0, sgrB = 0, sgrD = 0;
        void Add(decimal? rate, decimal amount, bool discountable)
        {
            var letter = VatLetter(rate);
            if (letter == "A")
            {
                if (discountable) grossA += amount;
                else sgrA += amount;
            }
            else if (letter == "B")
            {
                if (discountable) grossB += amount;
                else sgrB += amount;
            }
            else if (discountable)
                grossD += amount;
            else
                sgrD += amount;
        }
        foreach (var line in ticket.Lines)
        {
            if (line.MenuHeader)
                continue;
            Add(line.VatRate, line.UnitPrice * line.Quantity - line.DiscountAmount, true);
            foreach (var addon in line.Addons)
                Add(addon.VatRate, addon.PerUnit * line.Quantity * addon.UnitPrice, !IsSgr(addon.Name));
        }
        var percent = DiscountPercent(ticket);
        decimal Share(decimal gross) => percent <= 0 || gross == 0 ? 0 : RoundMoney(gross * percent / 100);
        var cutA = Share(grossA);
        var cutB = Share(grossB);
        var cutD = Share(grossD);
        var target = percent > 0 ? RoundMoney((grossA + grossB + grossD) * percent / 100) : 0;
        var drift = target - (cutA + cutB + cutD);
        if (drift != 0)
        {
            if (grossA >= grossB && grossA >= grossD && grossA != 0)
                cutA += drift;
            else if (grossB >= grossD && grossB != 0)
                cutB += drift;
            else if (grossD != 0)
                cutD += drift;
        }
        cutA = Math.Min(Math.Max(0, cutA), grossA);
        cutB = Math.Min(Math.Max(0, cutB), grossB);
        cutD = Math.Min(Math.Max(0, cutD), grossD);
        var cuts = new List<PercentCut>();
        if (cutA != 0) cuts.Add(new PercentCut(21, cutA));
        if (cutB != 0) cuts.Add(new PercentCut(11, cutB));
        if (cutD != 0) cuts.Add(new PercentCut(0, cutD));
        var bands = new List<VatBand>();
        var netA = grossA - cutA + sgrA;
        var netB = grossB - cutB + sgrB;
        var netD = grossD - cutD + sgrD;
        if (netA != 0) bands.Add(MakeBand("A", 21, netA));
        if (netB != 0) bands.Add(MakeBand("B", 11, netB));
        if (netD != 0) bands.Add(MakeBand("D", 0, netD));
        return new SaleCuts(cutA + cutB + cutD, cuts, bands);
    }

    private static string NormalizePercent(string raw)
    {
        var result = "";
        var separator = false;
        var decimals = 0;
        foreach (var character in raw)
        {
            if (char.IsDigit(character))
            {
                if (separator)
                {
                    if (decimals >= 2)
                        continue;
                    decimals++;
                }
                result += character;
            }
            else if ((character == ',' || character == '.') && !separator && result.Length > 0)
            {
                result += ',';
                separator = true;
            }
            if (result.Length >= 6)
                break;
        }
        if (TryMoney(result, out var number) && number > 100)
            return "100";
        return result;
    }

    private static bool TryMoney(string? text, out decimal value)
    {
        value = 0;
        if (string.IsNullOrWhiteSpace(text))
            return false;
        var normalized = text.Trim().Replace(',', '.');
        return decimal.TryParse(normalized, NumberStyles.Number, CultureInfo.InvariantCulture, out value);
    }

    private static string NormalizeTender(string raw)
    {
        var result = "";
        var separator = false;
        foreach (var character in raw)
        {
            if (char.IsDigit(character))
                result += character;
            else if ((character == ',' || character == '.') && !separator)
            {
                result += ',';
                separator = true;
            }
            if (result.Length >= 12)
                break;
        }
        return result;
    }

    private static string NormalizeCui(string raw)
    {
        var result = "";
        foreach (var character in raw.ToUpperInvariant())
        {
            if (char.IsLetterOrDigit(character))
                result += character;
            if (result.Length >= 12)
                break;
        }
        return result;
    }

    private static string ShownQty(int quantity) =>
        quantity > 1 ? quantity.ToString(CultureInfo.InvariantCulture) : "";

    private static string LineLabel(int quantity, string name) =>
        quantity > 1 ? quantity.ToString(CultureInfo.InvariantCulture) + " " + name : name;

    private readonly record struct VatBand(string Letter, int Rate, decimal Gross, decimal Vat);

    private static List<VatBand> VatBands(Ticket ticket) => PercentCuts(ticket).Bands;

    private static VatBand MakeBand(string letter, int rate, decimal gross)
    {
        var vat = rate == 0 ? 0 : RoundMoney(gross * rate / (100 + rate));
        return new VatBand(letter, rate, gross, vat);
    }

    private static decimal RoundMoney(decimal value) =>
        Math.Round(value, 2, MidpointRounding.AwayFromZero);

    private static bool IsSgr(string name) => name.Contains("SGR", StringComparison.OrdinalIgnoreCase);

    private readonly record struct SgrLine(string Name, decimal Quantity, decimal Amount, decimal VatRate, bool FromMenu);

    private static List<SgrLine> SgrLines(IEnumerable<CartRow> rows)
    {
        var groups = new List<(string Key, string Name, decimal Price, decimal Vat, decimal Quantity, bool FromMenu)>();
        foreach (var row in rows)
        {
            foreach (var addon in row.Addons)
            {
                if (!IsSgr(addon.Name))
                    continue;
                var key = addon.Name.ToUpperInvariant()
                    + "|" + addon.UnitPrice.ToString(CultureInfo.InvariantCulture)
                    + "|" + addon.VatRate.ToString(CultureInfo.InvariantCulture);
                var quantity = addon.PerUnit * row.Quantity;
                var index = groups.FindIndex(item => item.Key == key);
                if (index < 0)
                    groups.Add((key, addon.Name, addon.UnitPrice, addon.VatRate, quantity, row.MenuBlock != null));
                else
                {
                    var item = groups[index];
                    groups[index] = (item.Key, item.Name, item.Price, item.Vat, item.Quantity + quantity, item.FromMenu || row.MenuBlock != null);
                }
            }
        }
        return groups.Select(item => new SgrLine(item.Name, item.Quantity, item.Quantity * item.Price, item.Vat, item.FromMenu)).ToList();
    }

    private static string QtyText(decimal quantity) =>
        quantity == decimal.Truncate(quantity)
            ? decimal.Truncate(quantity).ToString(CultureInfo.InvariantCulture)
            : quantity.ToString("0.##", CultureInfo.InvariantCulture);

    private static string VatLetter(decimal? rate)
    {
        if (rate == null)
            return "";
        if (rate >= 19)
            return "A";
        if (rate >= 9)
            return "B";
        return "D";
    }

    private enum PayKind
    {
        Cash,
        Card,
        Modern
    }

    private sealed class Ticket
    {
        public List<CartRow> Lines { get; } = new();
        public PayKind Pay { get; set; } = PayKind.Cash;
        public string Channel { get; set; } = "";
        public string Tender { get; set; } = "";
        public string DiscountText { get; set; } = "";
        public string Cui { get; set; } = "";
        public string ClientName { get; set; } = "";
        public string ClientAddress { get; set; } = "";
        public bool PrintInvoice { get; set; }
    }

    private sealed class CartAddon
    {
        public Guid? ProductId { get; init; }
        public string Name { get; init; } = "";
        public decimal PerUnit { get; init; }
        public decimal UnitPrice { get; init; }
        public decimal VatRate { get; init; }
    }

    private sealed class CartRow
    {
        public Guid Id { get; init; }
        public Guid? ProductId { get; init; }
        public string Name { get; init; } = "";
        public decimal UnitPrice { get; init; }
        public decimal? VatRate { get; init; }
        public int Quantity { get; set; }
        public List<CartAddon> Addons { get; init; } = new();
        public decimal DiscountAmount { get; init; }
        public bool ShowsDiscount { get; init; }
        public bool MenuHeader { get; init; }
        public Guid? MenuBlock { get; init; }
    }
}

sealed class MenuSaleWindow : Window
{
    private readonly bool _multiple;
    private readonly HashSet<Guid> _selected = new();
    private readonly TextBlock _error = new() { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
    public IReadOnlyList<Guid>? Confirmed { get; private set; }

    private MenuSaleWindow(string title, string main, IReadOnlyList<(Guid Id, string Name)> secondaries, bool multiple)
    {
        _multiple = multiple;
        Title = title;
        Width = 460;
        Height = 520;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Icon = Brand.WindowIcon();
        Background = Brand.Brush(Brand.Page);
        var root = new DockPanel { Margin = new Avalonia.Thickness(16) };
        var actions = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var cancel = new Button { Content = "Renunță", Padding = new Avalonia.Thickness(12, 8) };
        cancel.Click += (_, _) => Close();
        var ok = new Button
        {
            Content = "Adaugă pe bon",
            Padding = new Avalonia.Thickness(12, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        ok.Click += (_, _) =>
        {
            if (_multiple ? _selected.Count == 0 : _selected.Count != 1)
            {
                _error.Text = _multiple
                    ? "Alegeți cel puțin un produs secundar."
                    : "Alegeți un singur produs secundar.";
                return;
            }
            Confirmed = _selected.ToList();
            Close();
        };
        actions.Children.Add(cancel);
        actions.Children.Add(ok);
        DockPanel.SetDock(actions, Dock.Bottom);
        root.Children.Add(actions);
        DockPanel.SetDock(_error, Dock.Bottom);
        root.Children.Add(_error);
        var list = new StackPanel { Spacing = 8 };
        list.Children.Add(new TextBlock { Text = "Produs principal", FontWeight = FontWeight.SemiBold });
        list.Children.Add(new TextBlock { Text = main, TextWrapping = TextWrapping.Wrap });
        list.Children.Add(new TextBlock { Text = "Produse secundare", FontWeight = FontWeight.SemiBold, Margin = new Avalonia.Thickness(0, 8, 0, 0) });
        list.Children.Add(new TextBlock
        {
            Text = _multiple ? "Alegeți cel puțin un produs secundar." : "Alegeți un singur produs secundar.",
            Foreground = Brand.Brush(Brand.Muted),
            TextWrapping = TextWrapping.Wrap
        });
        foreach (var item in secondaries)
        {
            var id = item.Id;
            ToggleButton box = _multiple
                ? new CheckBox { Content = item.Name }
                : new RadioButton { Content = item.Name, GroupName = "menu-secondary" };
            box.IsCheckedChanged += (_, _) =>
            {
                if (box.IsChecked == true)
                    _selected.Add(id);
                else
                    _selected.Remove(id);
            };
            list.Children.Add(box);
        }
        root.Children.Add(new ScrollViewer { Content = list });
        Content = root;
    }

    public static async Task<IReadOnlyList<Guid>?> Ask(Control owner, string title, string main, IReadOnlyList<(Guid Id, string Name)> secondaries, bool multiple)
    {
        var window = new MenuSaleWindow(title, main, secondaries, multiple);
        if (TopLevel.GetTopLevel(owner) is Window parent)
            await window.ShowDialog(parent);
        return window.Confirmed;
    }
}
