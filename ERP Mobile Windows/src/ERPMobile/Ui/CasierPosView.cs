using System.Collections.Concurrent;
using System.Globalization;
using System.Text;
using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media.Imaging;
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
    private static readonly IBrush TileFill = new SolidColorBrush(Color.FromArgb(140, 255, 255, 255));
    private static readonly ConcurrentDictionary<string, Task<Bitmap?>> PhotoCache = new(StringComparer.Ordinal);
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
    private readonly TextBlock _takings = new();
    private readonly Border _shiftBlock = new()
    {
        Background = new SolidColorBrush(Color.FromArgb(170, 0, 0, 0)),
        IsVisible = false,
        IsHitTestVisible = true,
        Child = new TextBlock
        {
            Text = "Așteptați pentru închiderea turei !!!",
            FontSize = 28,
            FontWeight = FontWeight.Bold,
            Foreground = Brushes.White,
            TextAlignment = TextAlignment.Center,
            TextWrapping = TextWrapping.Wrap,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Avalonia.Thickness(32)
        }
    };
    private readonly StackPanel _cash;
    private readonly StackPanel _tabs = new() { Orientation = Orientation.Horizontal, Spacing = 6 };
    private readonly Button _cashButton;
    private Button? _emit;
    private Button _printer = new();
    private readonly Button _cardButton;
    private string? _cardAcceptedKey;
    private bool _fiscalBusy;
    private readonly Button _modernButton;
    private readonly Button _splitButton;
    private readonly TextBox _splitCashBox;
    private readonly TextBox _splitCardBox;
    private readonly TextBlock _splitHint;
    private readonly StackPanel _splitPanel = new() { Spacing = 8, IsVisible = false };
    private bool _splitFilling;
    private readonly List<Ticket> _tickets = new() { new Ticket() };
    private readonly Dictionary<Guid, List<CartAddon>> _addons = new();
    private readonly List<CatalogProduct> _catalogProducts = new();
    private readonly List<CatalogMenu> _catalogMenus = new();
    private bool _catalogIsProducts;
    private bool _catalogWithAddons = true;
    private Button _storeChannel = new();
    private Button _onlineChannel = new();
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
        ToolTip.SetTip(_back, "Înapoi la grupe");
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
        _splitCashBox = SplitAmountBox();
        _splitCardBox = SplitAmountBox();
        _splitHint = new TextBlock
        {
            Text = "Scrieți suma la numerar sau la card. Restul se pune pe cealaltă metodă.",
            FontSize = 12,
            Foreground = Brand.Brush(Brand.Muted),
            TextWrapping = TextWrapping.Wrap
        };
        _splitCashBox.TextChanged += (_, _) => OnSplitEdited(true);
        _splitCardBox.TextChanged += (_, _) => OnSplitEdited(false);
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
            Text = "Numerar = 0,00    Card = 0,00    G = 0,00    B = 0,00    W = 0,00",
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
        _splitButton = PayButton("Numerar + Card", false, () => SetPay(PayKind.Split));
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
                if (!string.IsNullOrEmpty(next) && Active.Pay == PayKind.Modern && !Active.OnlineSale)
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
        var nectarie = _session.CurrentCompany?.IsNectarie == true;
        Background = Brand.Brush(Brand.Page);
        var root = new Grid { ColumnDefinitions = new ColumnDefinitions("*,380") };
        var left = new DockPanel();

        var footer = new Border
        {
            Background = nectarie ? new SolidColorBrush(Color.FromArgb(140, 255, 255, 255)) : Brushes.White,
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
        left.Children.Add(footer);

        var header = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto"),
            Margin = new Avalonia.Thickness(20, 14)
        };
        header.Children.Add(_heading);
        var reportX = ReportButton("Raport X", filled: false, () => _ = PrintX());
        var reportZ = ReportButton("Raport Z", filled: true, () => _ = CloseZ());
        reportX.Margin = new Avalonia.Thickness(8, 0, 8, 0);
        Grid.SetColumn(reportX, 1);
        Grid.SetColumn(reportZ, 2);
        header.Children.Add(reportX);
        header.Children.Add(reportZ);
        DockPanel.SetDock(header, Dock.Top);
        left.Children.Add(header);

        var catalog = new StackPanel { Spacing = 12 };
        catalog.Children.Add(_status);
        catalog.Children.Add(_tiles);
        left.Children.Add(new ScrollViewer { Content = catalog, Margin = new Avalonia.Thickness(16) });

        var receipt = new Border
        {
            Background = Brushes.White,
            CornerRadius = new Avalonia.CornerRadius(0),
            Padding = new Avalonia.Thickness(16),
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(1, 0, 0, 0)
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
        _splitButton.Margin = new Avalonia.Thickness(0, 8, 0, 0);
        bottom.Children.Add(_splitButton);
        bottom.Children.Add(_modernChoices);
        _splitPanel.Margin = new Avalonia.Thickness(0, 10, 0, 0);
        _splitPanel.Children.Add(SplitAmountRow("Numerar", _splitCashBox, () => OpenSplitPad(true)));
        _splitPanel.Children.Add(SplitAmountRow("Card", _splitCardBox, () => OpenSplitPad(false)));
        _splitPanel.Children.Add(_splitHint);
        bottom.Children.Add(_splitPanel);

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
        ToolTip.SetTip(_emit, "Emite bonul fiscal");
        bottom.Children.Add(_emit);
        RefreshEmitButton();
        _printer = new Button
        {
            Content = FiscalNetStation.IsReady ? "FP-700 · FiscalNet" : "FP-700 · alegeți folderul Bonuri",
            FontSize = 12,
            Background = Brushes.Transparent,
            Foreground = Brand.Brush(Brand.Muted),
            BorderThickness = new Avalonia.Thickness(0),
            HorizontalAlignment = HorizontalAlignment.Center,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            Margin = new Avalonia.Thickness(0, 8, 0, 0),
            Padding = new Avalonia.Thickness(8, 4)
        };
        _printer.Click += (_, _) => _ = ChooseFiscalFolder();
        ToolTip.SetTip(_printer, "Setări folder bonuri / FiscalNet FP-700");
        bottom.Children.Add(_printer);
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
        _storeChannel = PayButton("In Store", true, () => SetPriceChannel(false));
        _onlineChannel = PayButton("On line", false, () => SetPriceChannel(true));
        _onlineChannel.Margin = new Avalonia.Thickness(8, 0, 0, 0);
        var channel = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,*"),
            Margin = new Avalonia.Thickness(0, 0, 0, 8)
        };
        channel.Children.Add(_storeChannel);
        Grid.SetColumn(_onlineChannel, 1);
        channel.Children.Add(_onlineChannel);
        linesHost.Children.Add(channel);
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
        if (nectarie)
        {
            var catalogHost = new Grid { ClipToBounds = true };
            catalogHost.Children.Add(new Image
            {
                Source = Brand.NectarieLogo,
                Stretch = Stretch.UniformToFill,
                Opacity = 0.5,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                VerticalAlignment = VerticalAlignment.Stretch,
                IsHitTestVisible = false
            });
            catalogHost.Children.Add(left);
            root.Children.Add(catalogHost);
        }
        else
        {
            root.Children.Add(left);
        }
        root.Children.Add(receipt);
        var shell = new Grid();
        shell.Children.Add(root);
        shell.Children.Add(_shiftBlock);
        Content = shell;
    }

    private async Task LoadGroups()
    {
        _catalogIsProducts = false;
        _tilesAreProducts = false;
        _tilesAreMenus = false;
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
    private bool _tilesAreProducts;
    private bool _tilesAreMenus;

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
        _catalogIsProducts = false;
        var company = RequireCompany();
        var rows = await _session.SelectRows(
            "cm_menus",
            $"company_id=eq.{company}&is_active=eq.true&select=id,name,pret_vanzare,pret_vanzare_online,cod,permite_secundare_multiple&order=sort_order.asc,name.asc");
        _catalogMenus.Clear();
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
        {
            _tiles.Children.Clear();
            _status.Text = "Grupa nu are produse.";
            return;
        }
        var photos = await MainProductPhotos(rows);
        foreach (var row in rows.EnumerateArray().OrderBy(item => Text(item, "name"), NameOrder))
        {
            if (!row.TryGetProperty("id", out var idValue) || !idValue.TryGetGuid(out var id))
                continue;
            var store = Number(row, "pret_vanzare");
            var online = row.TryGetProperty("pret_vanzare_online", out _) ? Number(row, "pret_vanzare_online") : store;
            photos.TryGetValue(id, out var photo);
            _catalogMenus.Add(new CatalogMenu
            {
                Id = id,
                Name = Text(row, "name"),
                Code = Text(row, "cod"),
                StorePrice = store,
                OnlinePrice = online,
                Multiple = row.TryGetProperty("permite_secundare_multiple", out var flag) && flag.ValueKind == JsonValueKind.True,
                Image = photo ?? ""
            });
        }
        _status.Text = "";
        PaintMenus(rebuild: true);
    }

    private void PaintMenus(bool rebuild = false)
    {
        var visible = _catalogMenus.Where(item => !Active.OnlineSale || item.OnlinePrice > 0).ToList();
        if (!rebuild && _tilesAreMenus && TryRetint(visible.Select(item => (item.StorePrice, item.OnlinePrice)).ToList()))
            return;
        _tiles.Children.Clear();
        foreach (var item in visible)
        {
            var menu = item;
            var price = Active.OnlineSale ? menu.OnlinePrice : menu.StorePrice;
            var tile = ProductTile(menu.Name, menu.Code, Ron(price), menu.Image, () =>
                _ = AskMenu(menu.Id, menu.Name, menu.StorePrice, menu.OnlinePrice, menu.Multiple));
            if (price <= 0)
                tile.Opacity = 0.4;
            _tiles.Children.Add(tile);
        }
        _tilesAreMenus = true;
        _tilesAreProducts = false;
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

    private async Task AskMenu(Guid menuId, string name, decimal storePrice, decimal onlinePrice, bool multiple)
    {
        if ((Active.OnlineSale ? onlinePrice : storePrice) <= 0)
        {
            await Tell("Prețul de vânzare este 0. Nu se poate marca pe bon.");
            return;
        }
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
                "id=in.(" + string.Join(",", ids) + ")&select=id,denumire,cota_tva,pret_vanzare,pret_vanzare_online");
            var info = new Dictionary<Guid, MenuProduct>();
            if (products.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in products.EnumerateArray())
                {
                    info[row.GetProperty("id").GetGuid()] = new MenuProduct
                    {
                        Name = Text(row, "denumire"),
                        Vat = Number(row, "cota_tva"),
                        Store = Number(row, "pret_vanzare"),
                        Online = Number(row, "pret_vanzare_online")
                    };
                }
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
            CommitMenu(name, storePrice, onlinePrice, mainId.Value, info[mainId.Value], picked, info);
        }
        catch (Exception ex)
        {
            await Tell(ex.Message);
        }
    }

    private void CommitMenu(
        string name,
        decimal storePrice,
        decimal onlinePrice,
        Guid mainId,
        MenuProduct main,
        IReadOnlyList<Guid> selectedSecondaries,
        Dictionary<Guid, MenuProduct> info)
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
                    sgr += addon.PerUnit * Chosen(addon);
            }
        }
            var price = Active.OnlineSale ? onlinePrice : storePrice;
        if (price <= 0)
        {
            _ = Tell("Prețul de vânzare este 0. Nu se poate marca pe bon.");
            return;
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
        var mainRow = MenuRow(mainId, main.Name, main.Vat, mainPrice, 0, false, block);
        mainRow.IsMenuMain = true;
        mainRow.MenuPrice = price;
        mainRow.MenuStorePrice = storePrice;
        mainRow.MenuOnlinePrice = onlinePrice;
        Active.Lines.Add(mainRow);
        foreach (var productId in selectedSecondaries)
        {
            if (!info.TryGetValue(productId, out var product))
                continue;
            var chosen = Active.OnlineSale ? product.Online : product.Store;
            var secondary = MenuRow(productId, product.Name, product.Vat, chosen, chosen, true, block);
            secondary.StorePrice = product.Store;
            secondary.OnlinePrice = product.Online;
            secondary.IsMenuSecondary = true;
            Active.Lines.Add(secondary);
        }
        ApplyPriceChannel();
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
                var charges = IsSgr(addon.Name);
                addons.Add(new CartAddon
                {
                    ProductId = addon.ProductId,
                    Name = addon.Name,
                    PerUnit = addon.PerUnit,
                    StorePrice = addon.StorePrice,
                    OnlinePrice = addon.OnlinePrice,
                    UnitPrice = charges ? Chosen(addon) : 0,
                    VatRate = addon.VatRate,
                    Charges = charges
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
            _catalogIsProducts = false;
            _catalogProducts.Clear();
            _status.Text = "Grupa nu are produse.";
            return;
        }
        var rowsTask = _session.SelectRows(
            "products",
            "id=in.(" + string.Join(",", ids) + ")&is_active=eq.true&select=id,cod,denumire,pret_vanzare,pret_vanzare_online,cota_tva,imagine_url");
        var addonsTask = LoadAddons(ids);
        await Task.WhenAll(rowsTask, addonsTask);
        var rows = await rowsTask;
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
            "id=in.(" + string.Join(",", addonIds) + ")&select=id,denumire,pret_vanzare,pret_vanzare_online,cota_tva");
        var names = new Dictionary<Guid, (string Name, decimal Store, decimal Online, decimal Vat)>();
        if (products.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in products.EnumerateArray())
                names[row.GetProperty("id").GetGuid()] = (
                    Text(row, "denumire"),
                    Number(row, "pret_vanzare"),
                    Number(row, "pret_vanzare_online"),
                    Number(row, "cota_tva"));
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
            if (list.Any(item => item.Name == addon.Name && item.StorePrice == addon.Store))
                continue;
            list.Add(new CartAddon
            {
                ProductId = addonId,
                Name = addon.Name,
                PerUnit = perUnit,
                StorePrice = addon.Store,
                OnlinePrice = addon.Online,
                UnitPrice = addon.Store,
                VatRate = addon.Vat
            });
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
        _catalogProducts.Clear();
        _catalogIsProducts = true;
        _catalogWithAddons = withAddons;
        _status.Text = rows.Count == 0 ? "Grupa nu are produse." : "";
        foreach (var row in rows)
        {
            if (!row.TryGetProperty("id", out var idValue) || !idValue.TryGetGuid(out var id))
                continue;
            _catalogProducts.Add(new CatalogProduct
            {
                Id = id,
                Name = Text(row, nameField),
                Code = codeField == null ? "" : Text(row, codeField),
                StorePrice = Number(row, "pret_vanzare"),
                OnlinePrice = Number(row, "pret_vanzare_online"),
                Vat = withAddons ? Number(row, "cota_tva") : null,
                Image = Text(row, "imagine_url")
            });
        }
        PaintCatalog(rebuild: true);
    }

    private void PaintCatalog(bool rebuild = false)
    {
        if (!_catalogIsProducts)
            return;
        var visible = _catalogProducts.Where(item => !Active.OnlineSale || item.OnlinePrice > 0).ToList();
        if (!rebuild && _tilesAreProducts && TryRetint(visible.Select(item => (item.StorePrice, item.OnlinePrice)).ToList()))
            return;
        _tiles.Children.Clear();
        foreach (var product in visible)
        {
            var item = product;
            var price = Active.OnlineSale ? item.OnlinePrice : item.StorePrice;
            var tile = ProductTile(item.Name, item.Code, Ron(price), item.Image, () =>
                AddItem(item.Id, item.Name, item.StorePrice, item.OnlinePrice, item.Vat, _catalogWithAddons));
            if (price <= 0)
                tile.Opacity = 0.4;
            _tiles.Children.Add(tile);
        }
        _tilesAreProducts = true;
        _tilesAreMenus = false;
        _fitProductColumns = true;
        FitProductColumns();
    }

    private bool TryRetint(IReadOnlyList<(decimal Store, decimal Online)> prices)
    {
        if (prices.Count == 0 || _tiles.Children.Count != prices.Count)
            return false;
        for (var i = 0; i < prices.Count; i++)
        {
            if (_tiles.Children[i] is not Button button || button.Tag is not TextBlock)
                return false;
        }
        for (var i = 0; i < prices.Count; i++)
        {
            var button = (Button)_tiles.Children[i];
            var label = (TextBlock)button.Tag!;
            var amount = Active.OnlineSale ? prices[i].Online : prices[i].Store;
            label.Text = Ron(amount);
            button.Opacity = amount <= 0 ? 0.4 : 1;
        }
        return true;
    }

    private void AddItem(Guid id, string name, decimal store, decimal online, decimal? vat, bool withAddons)
    {
        var price = Active.OnlineSale ? online : store;
        if (price <= 0)
        {
            _ = Tell("Prețul de vânzare este 0. Nu se poate marca pe bon.");
            return;
        }
        var existing = Active.Lines.Find(row => row.Id == id);
        if (existing != null)
        {
            existing.Quantity += 1;
        }
        else
        {
            var addons = withAddons && _addons.TryGetValue(id, out var list)
                ? list.Select(item => new CartAddon
                {
                    ProductId = item.ProductId,
                    Name = item.Name,
                    PerUnit = item.PerUnit,
                    StorePrice = item.StorePrice,
                    OnlinePrice = item.OnlinePrice,
                    UnitPrice = Chosen(item),
                    VatRate = item.VatRate,
                    Charges = true
                }).ToList()
                : new List<CartAddon>();
            Active.Lines.Add(new CartRow
            {
                Id = id,
                Name = name,
                UnitPrice = price,
                StorePrice = store,
                OnlinePrice = online,
                VatRate = vat,
                Quantity = 1,
                Addons = addons
            });
        }
        RefreshTabs();
        RefreshReceipt();
    }

    private void SetPriceChannel(bool online)
    {
        Active.OnlineSale = online;
        if (online)
            Active.Pay = PayKind.Modern;
        else if (Active.Pay == PayKind.Modern)
        {
            Active.Pay = PayKind.Cash;
            Active.Channel = "";
        }
        PaintPay(_storeChannel, !online);
        PaintPay(_onlineChannel, online);
        PaintPay(_cashButton, Active.Pay == PayKind.Cash);
        PaintPay(_cardButton, Active.Pay == PayKind.Card);
        PaintPay(_modernButton, Active.Pay == PayKind.Modern);
        PaintPay(_splitButton, Active.Pay == PayKind.Split);
        if (ApplyPriceChannel())
            _ = Tell("Prețul de vânzare este 0. Nu se poate marca pe bon.");
        if (_tilesAreProducts)
            PaintCatalog();
        else if (_tilesAreMenus)
            PaintMenus();
        RefreshReceipt();
    }

    private bool ApplyPriceChannel()
    {
        foreach (var line in Active.Lines)
        {
            foreach (var addon in line.Addons)
                addon.UnitPrice = addon.Charges ? Chosen(addon) : 0;
        }
        foreach (var line in Active.Lines)
        {
            if (line.MenuHeader)
                continue;
            if (line.IsMenuSecondary)
            {
                var price = Chosen(line);
                line.UnitPrice = price;
                line.DiscountAmount = price;
            }
            else if (line.IsMenuMain)
            {
                decimal sgr = 0;
                foreach (var other in Active.Lines)
                {
                    if (other.MenuBlock != line.MenuBlock)
                        continue;
                    foreach (var addon in other.Addons)
                    {
                        if (addon.Charges)
                            sgr += addon.PerUnit * addon.UnitPrice;
                    }
                }
                var menuPrice = line.MenuStorePrice == 0 && line.MenuOnlinePrice == 0
                    ? line.MenuPrice
                    : Active.OnlineSale ? line.MenuOnlinePrice : line.MenuStorePrice;
                line.MenuPrice = menuPrice;
                line.UnitPrice = Math.Max(0, menuPrice - sgr);
            }
            else
                line.UnitPrice = Chosen(line);
        }
        var before = Active.Lines.Count;
        var doomed = new HashSet<Guid>();
        foreach (var line in Active.Lines)
        {
            if (line.IsMenuMain && line.MenuPrice <= 0 && line.MenuBlock is Guid block)
                doomed.Add(block);
        }
        Active.Lines.RemoveAll(line =>
        {
            if (line.MenuBlock is Guid block && doomed.Contains(block))
                return true;
            if (line.MenuHeader || line.IsMenuMain || line.IsMenuSecondary)
                return false;
            return line.UnitPrice <= 0;
        });
        return Active.Lines.Count != before;
    }

    private decimal Chosen(CartAddon addon) => Active.OnlineSale ? addon.OnlinePrice : addon.StorePrice;

    private decimal Chosen(CartRow line) => Active.OnlineSale ? line.OnlinePrice : line.StorePrice;

    private void SetPay(PayKind pay)
    {
        if (Active.OnlineSale && pay != PayKind.Modern)
            return;
        if (!Active.OnlineSale && pay == PayKind.Modern)
            return;
        Active.Pay = pay;
        if (pay != PayKind.Modern)
            Active.Channel = "";
        PaintPay(_cashButton, pay == PayKind.Cash);
        PaintPay(_cardButton, pay == PayKind.Card);
        PaintPay(_modernButton, pay == PayKind.Modern);
        PaintPay(_splitButton, pay == PayKind.Split);
        ShowModern();
        UpdateChange();
    }

    private void SetChannel(string channel)
    {
        if (!Active.OnlineSale)
            return;
        Active.Pay = PayKind.Modern;
        Active.Channel = channel;
        PaintPay(_cashButton, false);
        PaintPay(_cardButton, false);
        PaintPay(_modernButton, true);
        PaintPay(_splitButton, false);
        ShowModern();
        UpdateChange();
    }

    private void ShowModern()
    {
        var online = Active.OnlineSale;
        _cashButton.IsEnabled = !online;
        _cardButton.IsEnabled = !online;
        _splitButton.IsEnabled = !online;
        _modernButton.IsEnabled = online;
        if (online && Active.Pay != PayKind.Modern)
        {
            Active.Pay = PayKind.Modern;
            PaintPay(_cashButton, false);
            PaintPay(_cardButton, false);
            PaintPay(_modernButton, true);
            PaintPay(_splitButton, false);
        }
        if (!online && Active.Pay == PayKind.Modern)
        {
            Active.Pay = PayKind.Cash;
            Active.Channel = "";
            PaintPay(_cashButton, true);
            PaintPay(_cardButton, false);
            PaintPay(_modernButton, false);
            _cash.IsVisible = true;
        }
        _modernChoices.IsVisible = online && Active.Pay == PayKind.Modern;
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
                _lines.Children.Add(ReceiptLine("", "Discount 100%", Money(-row.DiscountAmount), VatMark(row.VatRate, row.MenuBlock != null), addon: true));
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
        _splitPanel.IsVisible = Active.Pay == PayKind.Split;
        if (Active.Pay == PayKind.Split)
            ApplySplitRemainder();
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
        _splitCashBox.Text = Active.CashPart;
        _splitCardBox.Text = Active.CardPart;
        _loadingTicket = false;
        SyncInvoiceBox();
        ShowClientName();
        PaintPay(_cashButton, Active.Pay == PayKind.Cash);
        PaintPay(_cardButton, Active.Pay == PayKind.Card);
        PaintPay(_modernButton, Active.Pay == PayKind.Modern);
        PaintPay(_splitButton, Active.Pay == PayKind.Split);
        PaintPay(_storeChannel, !Active.OnlineSale);
        PaintPay(_onlineChannel, Active.OnlineSale);
        if (_tilesAreProducts)
            PaintCatalog();
        else if (_tilesAreMenus)
            PaintMenus();
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

    private Task OpenSplitPad(bool cash)
    {
        if (Active.Pay != PayKind.Split)
            return Task.CompletedTask;
        var box = cash ? _splitCashBox : _splitCardBox;
        return ShowKeypad(cash ? "Numerar" : "Card", box.Text ?? "", NormalizeTender, ",", "0,00", money: true, verifyCui: false, value => box.Text = value);
    }

    private static TextBox SplitAmountBox() => new()
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

    private static Control SplitAmountRow(string title, TextBox box, Func<Task> open)
    {
        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("88,*") };
        row.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 15,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            VerticalAlignment = VerticalAlignment.Center
        });
        var entry = new Border
        {
            Background = Brushes.Transparent,
            Cursor = new Cursor(StandardCursorType.Hand),
            Child = box
        };
        entry.PointerPressed += (_, e) =>
        {
            e.Handled = true;
            _ = open();
        };
        Grid.SetColumn(entry, 1);
        row.Children.Add(entry);
        return row;
    }

    private void OnSplitEdited(bool cash)
    {
        if (_loadingTicket || _splitFilling)
            return;
        _splitFilling = true;
        try
        {
            var box = cash ? _splitCashBox : _splitCardBox;
            var text = NormalizeTender(box.Text ?? "");
            Active.SplitAnchorCash = cash;
            if (cash)
                Active.CashPart = text;
            else
                Active.CardPart = text;
            if (box.Text != text)
                box.Text = text;
        }
        finally
        {
            _splitFilling = false;
        }
        ApplySplitRemainder();
    }

    private void ApplySplitRemainder()
    {
        if (_splitFilling)
            return;
        _splitFilling = true;
        try
        {
            var total = TicketTotal(Active);
            var source = Active.SplitAnchorCash ? Active.CashPart : Active.CardPart;
            var other = "";
            if (TryMoney(source, out var entered) && entered > 0 && entered < total)
                other = Money(total - entered);
            if (Active.SplitAnchorCash)
            {
                Active.CardPart = other;
                if (_splitCardBox.Text != other)
                    _splitCardBox.Text = other;
            }
            else
            {
                Active.CashPart = other;
                if (_splitCashBox.Text != other)
                    _splitCashBox.Text = other;
            }
            var problem = SplitProblem();
            _splitHint.Text = problem ?? "";
            _splitHint.Foreground = problem == null || string.IsNullOrEmpty(source)
                ? Brand.Brush(Brand.Muted)
                : Brushes.Firebrick;
            if (problem != null && string.IsNullOrEmpty(source))
                _splitHint.Text = problem;
        }
        finally
        {
            _splitFilling = false;
        }
    }

    private string? SplitProblem()
    {
        if (Active.Pay != PayKind.Split)
            return null;
        var total = TicketTotal(Active);
        var source = Active.SplitAnchorCash ? Active.CashPart : Active.CardPart;
        if (!TryMoney(source, out var entered) || entered <= 0)
            return "Scrieți suma la numerar sau la card. Restul se pune pe cealaltă metodă.";
        if (total <= 0 || entered >= total)
            return "Scrieți o sumă mai mică decât totalul. Restul se încasează cu cealaltă metodă.";
        return null;
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

    private async Task ChooseFiscalFolder()
    {
        var storage = TopLevel.GetTopLevel(this)?.StorageProvider;
        if (storage == null)
            return;
        var folders = await storage.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "Folderul Bonuri din FiscalNet",
            AllowMultiple = false
        });
        var path = folders.FirstOrDefault()?.TryGetLocalPath();
        if (string.IsNullOrEmpty(path))
            return;
        var error = FiscalNetStation.SaveBonuriFolder(path);
        _printer.Content = FiscalNetStation.IsReady ? "FP-700 · FiscalNet" : "FP-700 · alegeți folderul Bonuri";
        if (error != null)
            await Tell(error);
    }

    private async Task<string?> PickFolder(string title)
    {
        var storage = TopLevel.GetTopLevel(this)?.StorageProvider;
        if (storage == null)
            return null;
        var folders = await storage.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = title,
            AllowMultiple = false
        });
        return folders.FirstOrDefault()?.TryGetLocalPath();
    }

    private async Task<bool> Ask(string message, string accept, string decline)
    {
        var done = new TaskCompletionSource<bool>();
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
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8 };
        var no = new Button { Content = decline, Padding = new Avalonia.Thickness(14, 8) };
        var yes = new Button
        {
            Content = accept,
            Padding = new Avalonia.Thickness(14, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        no.Click += (_, _) =>
        {
            done.TrySetResult(false);
            window.Close();
        };
        yes.Click += (_, _) =>
        {
            done.TrySetResult(true);
            window.Close();
        };
        window.Closed += (_, _) => done.TrySetResult(false);
        buttons.Children.Add(no);
        buttons.Children.Add(yes);
        panel.Children.Add(buttons);
        window.Content = panel;
        if (TopLevel.GetTopLevel(this) is Window parent)
            await window.ShowDialog(parent);
        else
            window.Show();
        return await done.Task;
    }

    private async Task DischargeStock(string receiptNumber)
    {
        var totals = new Dictionary<Guid, decimal>();
        void Add(Guid? id, decimal quantity)
        {
            if (id == null || quantity <= 0)
                return;
            totals[id.Value] = totals.TryGetValue(id.Value, out var sum) ? sum + quantity : quantity;
        }
        foreach (var line in Active.Lines)
        {
            if (line.MenuHeader)
                continue;
            Add(line.ProductId ?? line.Id, line.Quantity);
            foreach (var addon in line.Addons)
                Add(addon.ProductId, addon.PerUnit * line.Quantity);
        }
        if (totals.Count == 0)
            return;
        var canal = Active.OnlineSale ? "online" : "in_store";
        var items = totals.Select(pair => new { product_id = pair.Key.ToString(), cantitate = pair.Value, canal }).ToArray();
        await _session.Rpc("pos_discharge_fiscal_receipt", new
        {
            p_work_location_id = _locationId.ToString(),
            p_receipt_number = receiptNumber,
            p_items = items
        });
    }

    private async Task EmitFiscal(string channel, string payment)
    {
        if (_fiscalBusy)
            return;
        _fiscalBusy = true;
        if (_emit != null)
            _emit.IsEnabled = false;
        try
        {
            var withInvoice = Active.PrintInvoice && !string.IsNullOrEmpty(Active.Cui);
            Guid? series = null;
            string? folder = null;
            if (withInvoice)
            {
                series = await FiscalSeries();
                if (series == null)
                {
                    await Tell("Nu există serie de factură fiscală pentru acest punct de lucru. O adăugați în Nomenclatoare → Societăți → Serii documente.");
                    return;
                }
                folder = await PickFolder("Folder pentru bon și factură");
                if (string.IsNullOrEmpty(folder))
                    return;
            }

            var amount = TicketTotal(Active);
            var tender = 0m;
            if (channel == "cash")
                TryMoney(Active.Tender, out tender);
            var split = SplitEntry();
            var built = FiscalNet.BuildReceipt(Active.Cui, FiscalLines(Active), amount, FiscalNet.PayType(channel), tender, null, split.Entered, split.IsCash);
            if (Active.Pay == PayKind.Split)
                payment = SplitLabel(built.CashTaken, built.CardTaken);
            var key = CardKey(Active);
            if (ChargesCard(channel) && built.CardTaken > 0 && _cardAcceptedKey != key)
            {
                var pos = await FiscalNetStation.SendAsync(FiscalNet.FileName("pos", false), FiscalNet.Pos(built.CardTaken), TimeSpan.FromSeconds(180));
                if (pos.BonOk == 0)
                {
                    await Tell(FiscalNet.Failure(pos, "Banca a refuzat plata. Bonul nu s-a emis."));
                    return;
                }
                if (pos.BonOk != 1)
                {
                    var accepted = await Ask(
                        "Terminalul nu a confirmat plata. Verificați POS-ul bancar și spuneți dacă plata a reușit.",
                        "Plata a reușit",
                        "Nu emite bonul");
                    if (!accepted)
                        return;
                }
                _cardAcceptedKey = key;
            }

            var slipLines = SlipLines(Active);
            var bands = VatBands(Active);
            var total = Ron(built.Payment);
            var supplier = await SupplierLines();
            var stamp = DateTime.Now;
            var shown = stamp.ToString("dd.MM.yyyy HH:mm", CultureInfo.GetCultureInfo("ro-RO"));
            var clientName = Active.ClientName;
            var bonUrl = "";
            string? bonPath = null;
            var online = System.Net.NetworkInformation.NetworkInterface.GetIsNetworkAvailable() && _session.CurrentCompany != null;
            if (online)
            {
                var target = _session.PosDocumentTarget(_session.CurrentCompany!.Id);
                bonUrl = target.Url;
                bonPath = target.Path;
            }
            if (bonPath != null)
            {
                try
                {
                    var draft = PosSlipPdf.Make(ReceiptRows(supplier, shown, clientName, payment, slipLines, total, bands, bonUrl, "FP-700"));
                    await _session.UploadPosDocument(bonPath, draft);
                }
                catch
                {
                    bonUrl = "";
                }
            }
            var receipt = FiscalNet.BuildReceipt(Active.Cui, FiscalLines(Active), amount, FiscalNet.PayType(channel), tender, bonUrl, split.Entered, split.IsCash);
            var printed = await FiscalNetStation.SendAsync(FiscalNet.FileName("bf", false), receipt.Commands, TimeSpan.FromSeconds(60));
            if (printed.BonOk != 1 || printed.Number.Length == 0)
            {
                var charged = ChargesCard(channel) && _cardAcceptedKey == key
                    ? "Cardul a fost încasat. Nu modificați bonul și apăsați din nou Emite bon, fără o plată nouă.\n"
                    : "";
                await Tell(charged + FiscalNet.Failure(printed, "Bonul nu s-a tipărit. Nu a fost salvat."));
                return;
            }
            if (channel is "cash" or "split")
                await FiscalNetStation.SendAsync(FiscalNet.FileName("ds", false), FiscalNet.OpenDrawer(), TimeSpan.FromSeconds(20));

            var stockNote = "";
            try
            {
                await DischargeStock(printed.Number);
            }
            catch (Exception ex)
            {
                stockNote = "\n" + ex.Message;
            }

            var note = "Bon fiscal nr. " + printed.Number;
            var invoiceNote = "";
            string? invoiceName = null;
            var bonName = "Bon fiscal " + stamp.ToString("yyyy-MM-dd HHmm", CultureInfo.InvariantCulture) + ".pdf";
            if (bonPath != null && bonUrl.Length > 0)
            {
                try
                {
                    var finalBon = PosSlipPdf.Make(ReceiptRows(supplier, shown, clientName, payment, slipLines, total, bands, bonUrl, note));
                    await _session.UploadPosDocument(bonPath, finalBon);
                }
                catch
                {
                    bonUrl = "";
                }
            }

            if (withInvoice && series != null && !string.IsNullOrEmpty(folder))
            {
                try
                {
                    var issued = await _session.Rpc("consume_fiscal_invoice_number", new { p_series_id = series.Value.ToString() });
                    if (issued.ValueKind != JsonValueKind.Array || issued.GetArrayLength() == 0)
                        throw new InvalidOperationException("Nu am putut rezerva numărul facturii.");
                    var row = issued[0];
                    var serie = row.GetProperty("serie").GetString() ?? "";
                    var number = row.GetProperty("issued_number").GetInt32();
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
                    var invoiceLines = InvoiceLines(Active);
                    var invoiceUrl = "";
                    string? invoicePath = null;
                    if (online && _session.CurrentCompany != null)
                    {
                        var target = _session.PosDocumentTarget(_session.CurrentCompany.Id);
                        invoiceUrl = target.Url;
                        invoicePath = target.Path;
                        try
                        {
                            var draft = PosSlipPdf.Make(InvoiceRows(supplier, serie, number, shown, clientName, clientAddress, payment, invoiceLines, total, invoiceUrl, "FP-700"));
                            await _session.UploadPosDocument(invoicePath, draft);
                        }
                        catch
                        {
                            invoiceUrl = "";
                        }
                    }
                    var text = InvoicePaper(supplier, serie, number, shown, clientName, Active.Cui, clientAddress, payment, invoiceLines, total);
                    var invoiceReply = await FiscalNetStation.SendAsync(
                        FiscalNet.FileName("ff", true),
                        FiscalNet.NonFiscal(text, invoiceUrl),
                        TimeSpan.FromSeconds(60));
                    if (invoiceReply.BonOk != 1)
                        invoiceNote = "\n" + FiscalNet.Failure(invoiceReply, "Bonul fiscal s-a emis, dar factura nu a ieșit pe imprimantă.");
                    invoiceName = "Factura " + serie + " " + number + ".pdf";
                    var bonBytes = PosSlipPdf.Make(ReceiptRows(supplier, shown, clientName, payment, slipLines, total, bands, bonUrl, note));
                    var invoiceBytes = PosSlipPdf.Make(InvoiceRows(supplier, serie, number, shown, clientName, clientAddress, payment, invoiceLines, total, invoiceUrl, invoiceReply.BonOk == 1 ? "Tipărită pe FP-700" : null));
                    await File.WriteAllBytesAsync(Path.Combine(folder, bonName), bonBytes);
                    await File.WriteAllBytesAsync(Path.Combine(folder, invoiceName), invoiceBytes);
                    if (invoicePath != null && invoiceUrl.Length > 0 && invoiceReply.BonOk == 1)
                    {
                        try
                        {
                            await _session.UploadPosDocument(invoicePath, invoiceBytes);
                        }
                        catch
                        {
                            // PDF-ul local rămâne. Codul QR de pe hârtie poate să nu se deschidă.
                        }
                    }
                }
                catch (Exception ex)
                {
                    invoiceNote = "\nBonul fiscal s-a emis. Factura nu a putut fi tipărită.\n" + ex.Message;
                }
            }

            var recap = "";
            try
            {
                await RecordSale(channel, receipt.Payment);
                await LoadTakings();
            }
            catch (Exception ex)
            {
                recap = "\n" + ex.Message;
            }
            _cardAcceptedKey = null;
            ClearSoldTicket();
            var saved = invoiceName == null ? "" : "\nAu fost salvate două fișiere:\n" + bonName + "\n" + invoiceName;
            var auth = printed.Authorization.Length > 0 ? "\nAutorizare " + printed.Authorization : "";
            await Tell(note + auth + saved + invoiceNote + stockNote + recap);
        }
        finally
        {
            _fiscalBusy = false;
            if (_emit != null)
                _emit.IsEnabled = true;
        }
    }

    private static List<string> InvoicePaper(List<string> supplier, string serie, int number, string stamp, string clientName, string cui, string clientAddress, string payment, List<InvoiceLine> lines, string total)
    {
        var text = new List<string>
        {
            "FACTURA FISCALA",
            serie + " " + number,
            stamp
        };
        text.AddRange(supplier);
        if (clientName.Length > 0)
            text.Add(clientName);
        if (cui.Length > 0)
            text.Add("CUI " + cui);
        if (clientAddress.Length > 0)
            text.Add(clientAddress);
        foreach (var line in lines)
        {
            text.Add(line.Name);
            if (line.Quantity.Length > 0)
                text.Add(line.Quantity + "  " + line.Value + "  TVA " + line.Vat + "  " + line.Rate);
        }
        var net = lines.Sum(line => line.NetAmount);
        var vat = lines.Sum(line => line.VatAmount);
        text.Add("Baza " + Ron(net));
        text.Add("TVA " + Ron(vat));
        text.Add("TOTAL " + total);
        text.Add("Incasare " + payment);
        return text;
    }

    private static List<FiscalNet.SaleLine> FiscalLines(Ticket ticket)
    {
        var lines = new List<FiscalNet.SaleLine>();
        string? menu = null;
        foreach (var line in ticket.Lines)
        {
            if (line.MenuHeader)
            {
                menu = line.Name;
                continue;
            }
            var full = line.DiscountAmount > 0 || line.ShowsDiscount;
            lines.Add(new FiscalNet.SaleLine(line.Name, line.UnitPrice, line.Quantity, FiscalNet.VatGroup(line.VatRate), full, !full, menu));
            menu = null;
            foreach (var addon in line.Addons)
            {
                if (IsSgr(addon.Name))
                    continue;
                lines.Add(new FiscalNet.SaleLine(addon.Name, addon.UnitPrice, addon.PerUnit * line.Quantity, FiscalNet.VatGroup(addon.VatRate), false, true, null));
            }
        }
        foreach (var sgr in SgrLines(ticket.Lines))
        {
            if (sgr.Quantity <= 0 || sgr.Amount <= 0)
                continue;
            lines.Add(new FiscalNet.SaleLine(sgr.Name, sgr.Amount / sgr.Quantity, sgr.Quantity, FiscalNet.VatGroup(sgr.VatRate), false, false, null));
        }
        return lines;
    }

    private static string CardKey(Ticket ticket)
    {
        var text = new StringBuilder();
        foreach (var line in ticket.Lines)
        {
            text.Append(line.Name).Append('|').Append(line.Quantity).Append('|').Append(line.UnitPrice).Append('|').Append(line.DiscountAmount).Append(';');
            foreach (var addon in line.Addons)
                text.Append(addon.Name).Append('|').Append(addon.PerUnit).Append('|').Append(addon.UnitPrice).Append(';');
        }
        text.Append(ticket.DiscountText);
        if (ticket.Pay == PayKind.Split)
            text.Append("|split|").Append(ticket.SplitAnchorCash ? "cash" : "card").Append('|').Append(ticket.CashPart).Append('|').Append(ticket.CardPart);
        return text.ToString();
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
        var splitProblem = SplitProblem();
        if (splitProblem != null)
        {
            await Tell(splitProblem);
            return;
        }
        var amount = TicketTotal(Active);
        var payment = PaymentName(Active, amount);
        if (FiscalNetStation.IsReady)
        {
            await EmitFiscal(channel, payment);
            return;
        }
        var slipLines = SlipLines(Active);
        var invoiceLines = InvoiceLines(Active);
        var bands = VatBands(Active);
        var total = Ron(amount);
        if (!(Active.PrintInvoice && !string.IsNullOrEmpty(Active.Cui)))
        {
            try
            {
                await RecordSale(channel, amount);
                await LoadTakings();
                ClearSoldTicket();
                await Tell("Imprimanta fiscală nu este legată, bonul nu s-a tipărit. Încasarea a intrat în recapitularea de la ultimul Z.");
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
                await RecordSale(channel, amount);
                await LoadTakings();
            }
            catch (Exception ex)
            {
                recap = "\n" + ex.Message;
            }
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
        if (ticket.OnlineSale)
            return ticket.Channel is "glovo" or "bolt" or "wolt" ? ticket.Channel : null;
        if (ticket.Pay == PayKind.Card)
            return "card";
        if (ticket.Pay == PayKind.Cash)
            return "cash";
        if (ticket.Pay == PayKind.Split)
            return "split";
        return null;
    }

    private static bool ChargesCard(string channel) => channel is "card" or "split";

    private (decimal? Entered, bool IsCash) SplitEntry()
    {
        if (Active.Pay != PayKind.Split)
            return (null, true);
        var text = Active.SplitAnchorCash ? Active.CashPart : Active.CardPart;
        return TryMoney(text, out var entered) ? (entered, Active.SplitAnchorCash) : (null, Active.SplitAnchorCash);
    }

    private static string SplitLabel(decimal cash, decimal card) =>
        "Numerar " + Money(cash) + " + Card " + Money(card);

    private string PaymentName(Ticket ticket, decimal amount)
    {
        if (ticket.Pay != PayKind.Split)
            return PaymentName(TakingChannel(ticket) ?? "cash");
        var text = ticket.SplitAnchorCash ? ticket.CashPart : ticket.CardPart;
        if (!TryMoney(text, out var entered))
            return "Numerar + Card";
        var parts = FiscalNet.Split(amount, entered, ticket.SplitAnchorCash);
        return SplitLabel(parts.Cash, parts.Card);
    }

    private async Task RecordSale(string channel, decimal amount)
    {
        if (Active.Pay == PayKind.Split)
        {
            var text = Active.SplitAnchorCash ? Active.CashPart : Active.CardPart;
            if (!TryMoney(text, out var entered))
                return;
            var parts = FiscalNet.Split(amount, entered, Active.SplitAnchorCash);
            await RecordTaking("cash", parts.Cash);
            await RecordTaking("card", parts.Card);
            return;
        }
        await RecordTaking(channel, amount);
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
                + "    G = " + Money(glovo)
                + "    B = " + Money(bolt)
                + "    W = " + Money(wolt);
            await Dispatcher.UIThread.InvokeAsync(() => _takings.Text = text);
        }
        catch
        {
            await Dispatcher.UIThread.InvokeAsync(() => _takings.Text = "Încasările de la ultimul Z nu au putut fi citite.");
        }
    }

    private async Task PrintX()
    {
        if (!FiscalNetStation.IsReady)
        {
            await Tell("Raportul X se va tipări la imprimanta fiscală. Încă nu este legată. Apăsați „FP-700” și alegeți folderul Bonuri.");
            return;
        }
        if (_fiscalBusy)
            return;
        _fiscalBusy = true;
        try
        {
            var reply = await FiscalNetStation.SendAsync(FiscalNet.FileName("x", false), FiscalNet.Report("X"), TimeSpan.FromSeconds(90));
            await Tell(reply.BonOk == 1
                ? "Raportul X a fost trimis la imprimantă."
                : FiscalNet.Failure(reply, "Raportul X nu s-a tipărit."));
        }
        finally
        {
            _fiscalBusy = false;
        }
    }

    private async Task CloseZ()
    {
        if (_fiscalBusy || _shiftBlock.IsVisible)
            return;
        if (!FiscalNetStation.IsReady)
        {
            await Tell("Raportul Z se tipărește la imprimanta fiscală. Încă nu este legată. Apăsați „FP-700” și alegeți folderul Bonuri.");
            return;
        }
        _fiscalBusy = true;
        _shiftBlock.IsVisible = true;
        try
        {
            var reportX = await FiscalNetStation.SendAsync(FiscalNet.FileName("x", false), FiscalNet.Report("X"), TimeSpan.FromSeconds(90));
            if (reportX.BonOk != 1)
            {
                await Tell(FiscalNet.Failure(reportX, "Raportul X nu s-a tipărit. Tura a rămas deschisă."));
                return;
            }
            var reportZ = await FiscalNetStation.SendAsync(FiscalNet.FileName("z", false), FiscalNet.Report("Z"), TimeSpan.FromSeconds(90));
            if (reportZ.BonOk != 1)
            {
                await Tell(FiscalNet.Failure(reportZ, "Raportul Z nu s-a tipărit. Încasările au rămas deschise."));
                return;
            }
            await _session.Rpc("pos_close_shift_production", new { p_work_location_id = _locationId.ToString() });
            await _session.Rpc("pos_create_z_stock_sheet", new { p_work_location_id = _locationId.ToString(), p_z_number = reportZ.Number });
            await _session.Rpc("pos_close_takings_z", new { p_work_location_id = _locationId });
            await LoadTakings();
            _shiftBlock.IsVisible = false;
            await Tell("Ziua a fost închisă cu succes.");
        }
        catch (Exception ex)
        {
            await Tell(ex.Message);
        }
        finally
        {
            _fiscalBusy = false;
            _shiftBlock.IsVisible = false;
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
        Active.Pay = Active.OnlineSale ? PayKind.Modern : PayKind.Cash;
        Active.Channel = "";
        Active.CashPart = "";
        Active.CardPart = "";
        Active.SplitAnchorCash = true;
        _loadingTicket = true;
        _cuiBox.Text = "";
        _tenderBox.Text = "";
        _splitCashBox.Text = "";
        _splitCardBox.Text = "";
        _discountBox.Text = "";
        _printInvoice.IsChecked = false;
        _loadingTicket = false;
        PaintPay(_cashButton, !Active.OnlineSale);
        PaintPay(_cardButton, false);
        PaintPay(_modernButton, Active.OnlineSale);
        PaintPay(_splitButton, false);
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
                rows.Add(("Discount 100%", MarkedAmount(Ron(-line.DiscountAmount), line.VatRate, onMenu)));
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

    private List<PosSlipPdf.Row> ReceiptRows(List<string> supplier, string stamp, string clientName, string payment, List<(string Name, string Amount)> lines, string total, List<VatBand> bands, string documentUrl, string? printedNote = null)
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
        rows.Add(PosSlipPdf.Center(printedNote ?? "PDF — imprimanta fiscală nu este conectată", 6));
        rows.Add(PosSlipPdf.Line(" "));
        rows.Add(PosSlipPdf.Center("Document generat cu ERP Mobile by DateConta", 6));
        return rows;
    }

    private List<PosSlipPdf.Row> InvoiceRows(List<string> supplier, string serie, int number, string stamp, string clientName, string clientAddress, string payment, List<InvoiceLine> lines, string total, string documentUrl, string? printedNote = null)
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
        rows.Add(PosSlipPdf.Center(printedNote ?? "80 mm · PDF — imprimanta fiscală nu este conectată", 6));
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
            Background = TileFill,
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
        ToolTip.SetTip(button, name);
        return button;
    }

    private static Control ProductTile(string name, string code, string price, string imageUrl, Action? onTap)
    {
        var button = new Button
        {
            Width = 160,
            Height = 260,
            Margin = new Avalonia.Thickness(0, 0, 8, 8),
            Background = TileFill,
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
        var priceLabel = new TextBlock
        {
            Text = price,
            FontWeight = FontWeight.Bold,
            FontSize = 13,
            Foreground = Brand.Brush(Brand.Navy),
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top,
            Background = new SolidColorBrush(Color.FromArgb(230, 255, 255, 255))
        };
        imageZone.Children.Add(priceLabel);
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
        button.Tag = priceLabel;
        if (onTap != null)
            button.Click += (_, _) => onTap();
        if (!string.IsNullOrWhiteSpace(imageUrl))
            _ = LoadPhoto(photo, imageUrl);
        var tip = string.IsNullOrWhiteSpace(code) ? $"{name} · {price}" : $"{name} ({code}) · {price}";
        ToolTip.SetTip(button, tip);
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
        ToolTip.SetTip(button, title);
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
        ToolTip.SetTip(button, title);
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
            var bitmap = await PhotoCache.GetOrAdd(url, LoadPhotoBytes);
            if (bitmap != null)
                await Dispatcher.UIThread.InvokeAsync(() => target.Source = bitmap);
        }
        catch
        {
            PhotoCache.TryRemove(url, out _);
        }
    }

    private static async Task<Bitmap?> LoadPhotoBytes(string url)
    {
        try
        {
            var bytes = await Http.GetByteArrayAsync(url);
            using var stream = new MemoryStream(bytes);
            var source = new Bitmap(stream);
            var width = source.PixelSize.Width;
            var height = source.PixelSize.Height;
            if (width <= 448 && height <= 448)
                return source;
            var scale = Math.Min(448d / width, 448d / height);
            var size = new PixelSize(Math.Max(1, (int)(width * scale)), Math.Max(1, (int)(height * scale)));
            var scaled = source.CreateScaledBitmap(size, BitmapInterpolationMode.MediumQuality);
            source.Dispose();
            return scaled;
        }
        catch
        {
            return null;
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
        Modern,
        Split
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
        public bool OnlineSale { get; set; }
        public string CashPart { get; set; } = "";
        public string CardPart { get; set; } = "";
        public bool SplitAnchorCash { get; set; } = true;
    }

    private sealed class CartAddon
    {
        public Guid? ProductId { get; init; }
        public string Name { get; init; } = "";
        public decimal PerUnit { get; init; }
        public decimal StorePrice { get; set; }
        public decimal OnlinePrice { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal VatRate { get; init; }
        public bool Charges { get; set; } = true;
    }

    private sealed class CartRow
    {
        public Guid Id { get; init; }
        public Guid? ProductId { get; init; }
        public string Name { get; init; } = "";
        public decimal UnitPrice { get; set; }
        public decimal StorePrice { get; set; }
        public decimal OnlinePrice { get; set; }
        public decimal MenuPrice { get; set; }
        public decimal MenuStorePrice { get; set; }
        public decimal MenuOnlinePrice { get; set; }
        public decimal? VatRate { get; init; }
        public int Quantity { get; set; }
        public List<CartAddon> Addons { get; init; } = new();
        public decimal DiscountAmount { get; set; }
        public bool ShowsDiscount { get; init; }
        public bool MenuHeader { get; init; }
        public bool IsMenuMain { get; set; }
        public bool IsMenuSecondary { get; set; }
        public Guid? MenuBlock { get; init; }
    }

    private sealed class CatalogMenu
    {
        public Guid Id { get; init; }
        public string Name { get; init; } = "";
        public string Code { get; init; } = "";
        public decimal StorePrice { get; init; }
        public decimal OnlinePrice { get; init; }
        public bool Multiple { get; init; }
        public string Image { get; init; } = "";
    }

    private sealed class CatalogProduct
    {
        public Guid Id { get; init; }
        public string Name { get; init; } = "";
        public string Code { get; init; } = "";
        public decimal StorePrice { get; init; }
        public decimal OnlinePrice { get; init; }
        public decimal? Vat { get; init; }
        public string Image { get; init; } = "";
    }

    private sealed class MenuProduct
    {
        public string Name { get; init; } = "";
        public decimal Vat { get; init; }
        public decimal Store { get; init; }
        public decimal Online { get; init; }
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
