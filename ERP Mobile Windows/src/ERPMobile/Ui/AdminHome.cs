using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using Avalonia.VisualTree;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class AdminHome : UserControl
{
    private readonly AppSession _session;
    private readonly Action _home;
    private readonly Border _host = new();

    public AdminHome(AppSession session, Action home)
    {
        _session = session;
        _home = home;
        Content = _host;
        ShowTiles();
    }

    private void ShowTiles()
    {
        var wrap = new WrapPanel();
        wrap.Children.Add(SectionHome.Tile("Vânzări", "Bonuri, rapoarte Z și facturi emise, pe toate punctele de lucru.", () => Open(Sales())));
        wrap.Children.Add(SectionHome.Tile("Foi de stoc", "Foile de stoc de la toate punctele, cu dată și căutare.", () => Open(new StockSheetListView(_session, offersAll: true))));
        wrap.Children.Add(SectionHome.Tile("Bonuri de consum", "Bonurile făcute de casieri. Le aprobați pe tot bonul sau pe linii.", () => Open(new AdminConsumptions(_session, ShowTiles))));
        wrap.Children.Add(SectionHome.Tile("Listări", "Listări de stoc, fișe de magazie și cele care urmează.", () => Open(ListingsHub())));
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12 };
        page.Children.Add(Back("← Acasă", () => Dispatcher.UIThread.Post(_home)));
        page.Children.Add(wrap);
        _host.Child = new ScrollViewer { Content = page };
    }


    private Control ListingsHub()
    {
        var wrap = new WrapPanel();
        wrap.Children.Add(SectionHome.Tile("Listări stocuri", "Stocul firmei la deschidere, cu filtre, PDF și listare.", () => Open(new StockListingView(_session, () => Open(ListingsHub())))));
        wrap.Children.Add(SectionHome.Tile("Listări fișe magazie", "Bifați articolele, punctele și perioada. Fișa se deschide pe tot ecranul.", () => Open(new WarehouseCardListingView(_session, () => Open(ListingsHub())))));
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12 };
        page.Children.Add(Back("← Administrator", ShowTiles));
        page.Children.Add(new TextBlock { Text = "Listări", FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        page.Children.Add(wrap);
        return new ScrollViewer { Content = page };
    }

    private Control Sales()
    {
        var host = new ContentControl();
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Avalonia.Thickness(16, 12, 16, 0) };
        var receipts = Tab("Bonuri");
        var reports = Tab("Z-uri");
        var invoices = Tab("Facturi");
        receipts.Click += (_, _) =>
        {
            Mark(receipts, reports, invoices);
            host.Content = new SalesReceiptsByZView(_session, companyWide: true);
        };
        reports.Click += (_, _) =>
        {
            Mark(reports, receipts, invoices);
            host.Content = new AdminZReports(_session);
        };
        invoices.Click += (_, _) =>
        {
            Mark(invoices, receipts, reports);
            host.Content = new SalesInvoicesView(_session, adminFilters: true);
        };
        bar.Children.Add(receipts);
        bar.Children.Add(reports);
        bar.Children.Add(invoices);
        var page = new DockPanel();
        var back = Back("← Administrator", ShowTiles);
        DockPanel.SetDock(back, Dock.Top);
        DockPanel.SetDock(bar, Dock.Top);
        page.Children.Add(back);
        page.Children.Add(bar);
        page.Children.Add(host);
        Mark(receipts, reports, invoices);
        host.Content = new SalesReceiptsByZView(_session, companyWide: true);
        return page;
    }

    private void Open(Control page) => _host.Child = page;

    private Button Back(string title, Action action)
    {
        var button = new Button
        {
            Content = title,
            Margin = new Avalonia.Thickness(20, 12, 20, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brushes.White
        };
        button.Click += (_, _) => Dispatcher.UIThread.Post(action);
        return button;
    }

    private static Button Tab(string title) => new()
    {
        Content = title,
        Padding = new Avalonia.Thickness(14, 8)
    };

    private static void Mark(Button selected, params Button[] others)
    {
        selected.Background = Brand.Brush(Brand.Navy);
        selected.Foreground = Brushes.White;
        foreach (var other in others)
        {
            other.Background = Brushes.Transparent;
            other.Foreground = Brand.Brush(Brand.Navy);
        }
    }
}

public sealed class AdminZReports : UserControl
{
    private readonly AppSession _session;
    private readonly ComboBox _location = new() { MinWidth = 200 };
    private readonly ComboBox _dayMode = new() { MinWidth = 110 };
    private readonly CalendarDatePicker _date = new() { SelectedDate = DateTime.Today, Width = 160, IsVisible = false };
    private readonly TextBox _search = new() { Watermark = "Caută Z sau punct", MinWidth = 220 };
    private readonly DataGrid _grid = new() { AutoGenerateColumns = false, IsReadOnly = true, CanUserSortColumns = false };
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), Margin = new Avalonia.Thickness(20, 8) };
    private readonly List<Row> _rows = new();

    public AdminZReports(AppSession session)
    {
        _session = session;
        _grid.Columns.Add(Column("Z", nameof(Row.Number), 80));
        _grid.Columns.Add(Column("Data", nameof(Row.Date), 150));
        _grid.Columns.Add(Column("Punct", nameof(Row.Place), 180));
        _grid.Columns.Add(Column("Vânzări", nameof(Row.Total), 110));
        _grid.Columns.Add(Column("Numerar", nameof(Row.Cash), 110));
        _grid.Columns.Add(Column("Card", nameof(Row.Card), 110));
        _grid.Columns.Add(Column("Modernă", nameof(Row.Modern), 110));
        _grid.AddHandler(InputElement.PointerReleasedEvent, OnClick, Avalonia.Interactivity.RoutingStrategies.Bubble, handledEventsToo: true);
        _search.TextChanged += (_, _) => Show();
        _dayMode.Items.Add("Toate");
        _dayMode.Items.Add("O zi");
        _dayMode.SelectedIndex = 0;
        _location.SelectionChanged += (_, _) => Show();
        _dayMode.SelectionChanged += (_, _) =>
        {
            _date.IsVisible = _dayMode.SelectedIndex == 1;
            Show();
        };
        _date.SelectedDateChanged += (_, _) =>
        {
            if (_dayMode.SelectedIndex == 1)
                Show();
        };
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Avalonia.Thickness(20, 12, 20, 0) };
        bar.Children.Add(_location);
        bar.Children.Add(_dayMode);
        bar.Children.Add(_date);
        bar.Children.Add(_search);
        var page = new DockPanel();
        DockPanel.SetDock(bar, Dock.Top);
        DockPanel.SetDock(_status, Dock.Bottom);
        page.Children.Add(bar);
        page.Children.Add(_status);
        page.Children.Add(_grid);
        Content = page;
        _ = Load();
    }

    private async Task Load()
    {
        if (_session.CurrentCompany == null)
        {
            _status.Text = "Selectați o societate.";
            return;
        }
        try
        {
            var places = await _session.SelectAllPages(
                "company_work_locations",
                $"company_id=eq.{_session.CurrentCompany.Id}&select=id,denumire");
            var names = new Dictionary<Guid, string>();
            var choices = new List<PlaceChoice>();
            foreach (var place in places)
            {
                if (place.TryGetProperty("id", out var id) && id.TryGetGuid(out var guid))
                {
                    var name = Text(place, "denumire");
                    names[guid] = name;
                    choices.Add(new PlaceChoice(guid, name));
                }
            }
            var rows = await _session.SelectAllPages(
                "z_stock_sheets",
                $"company_id=eq.{_session.CurrentCompany.Id}&select=id,z_number,sheet_date,shift_no,created_at,numerar,plata_card,plata_moderna,work_location_id&order=created_at.desc");
            _rows.Clear();
            foreach (var row in rows)
            {
                var number = Text(row, "z_number").Trim();
                if (number.Length == 0 || !row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var sheetId))
                    continue;
                Guid? locationId = row.TryGetProperty("work_location_id", out var location) && location.TryGetGuid(out var parsed) ? parsed : null;
                var place = locationId != null && names.TryGetValue(locationId.Value, out var placeName) ? placeName : "";
                var shift = row.TryGetProperty("shift_no", out var shiftValue) && shiftValue.TryGetInt32(out var shiftNo) ? shiftNo : 1;
                var cash = Amount(row, "numerar");
                var card = Amount(row, "plata_card");
                var modern = Amount(row, "plata_moderna");
                var when = Shown(Text(row, "sheet_date"), shift, Text(row, "created_at"));
                _rows.Add(new Row(
                    sheetId,
                    number,
                    when,
                    Text(row, "sheet_date").Split('T')[0],
                    locationId,
                    place,
                    Ron(cash + card + modern),
                    Ron(cash),
                    Ron(card),
                    Ron(modern),
                    cash,
                    card,
                    modern));
            }
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                _location.Items.Clear();
                _location.Items.Add(new PlaceChoice(null, "Toate punctele"));
                foreach (var choice in choices)
                    _location.Items.Add(choice);
                _location.SelectedIndex = 0;
                Show();
            });
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async void OnClick(object? sender, PointerReleasedEventArgs e)
    {
        if (e.InitialPressMouseButton != MouseButton.Left)
            return;
        if (e.Source is not Visual visual)
            return;
        var gridRow = visual as DataGridRow ?? visual.FindAncestorOfType<DataGridRow>();
        if (gridRow?.DataContext is not Row row || _session.CurrentCompany == null)
            return;
        var number = int.TryParse(row.Number, out var value) ? value.ToString("0000") : row.Number;
        var bands = await VatBands(row.Id);
        var pdf = ZReportSlipPdf.MakePos(
            _session.CurrentCompany.Denumire,
            _session.CurrentCompany.Cui ?? "",
            row.Place,
            row.Date,
            number,
            row.CashValue,
            row.CardValue,
            row.ModernValue,
            bands.Brut21,
            bands.Tva21,
            bands.Brut11,
            bands.Tva11,
            bands.Brut0,
            bands.Tva0);
        var window = new PdfFileWindow(
            "Raport Z " + number,
            row.Place + "\n" + row.Date + "\nNumerar " + row.Cash + "\nCard " + row.Card + "\nModernă " + row.Modern + "\nTotal " + row.Total,
            pdf,
            "Raport Z " + number + ".pdf");
        window.Show();
    }

    private async Task<(decimal Brut21, decimal Tva21, decimal Brut11, decimal Tva11, decimal Brut0, decimal Tva0)> VatBands(Guid sheetId)
    {
        try
        {
            var json = await _session.Rpc("pos_sheet_vat_bands", new { p_sheet_id = sheetId.ToString() });
            if (json.ValueKind == JsonValueKind.Array && json.GetArrayLength() > 0)
            {
                var row = json[0];
                return (Band(row, "brut_21"), Band(row, "tva_21"), Band(row, "brut_11"), Band(row, "tva_11"), Band(row, "brut_0"), Band(row, "tva_0"));
            }
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
        return (0, 0, 0, 0, 0, 0);
    }

    private static decimal Band(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value))
            return 0;
        decimal number;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out number))
            return number;
        var text = value.ValueKind == JsonValueKind.String ? value.GetString() : value.ToString();
        return decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out number) ? number : 0;
    }

    private void Show()
    {
        var query = (_search.Text ?? "").Trim();
        var day = _dayMode.SelectedIndex == 1
            ? (_date.SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
            : null;
        var place = _location.SelectedItem as PlaceChoice;
        var shown = _rows.Where(row =>
            (day == null || row.SheetDay == day)
            && (place?.Id == null || row.LocationId == place.Id)
            && (query.Length == 0
                || row.Number.Contains(query, StringComparison.OrdinalIgnoreCase)
                || row.Place.Contains(query, StringComparison.OrdinalIgnoreCase)
                || row.Date.Contains(query, StringComparison.OrdinalIgnoreCase))).ToList();
        _grid.ItemsSource = null;
        _grid.ItemsSource = shown;
        _status.Text = shown.Count == 0
            ? "Nu sunt rapoarte Z emise de POS pentru filtrul ales."
            : $"{shown.Count} rapoarte Z";
        _status.Foreground = Brand.Brush(Brand.Muted);
    }

    private static string Text(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.ToString();
    }

    private static string Shown(string iso, int shift, string createdAt)
    {
        var day = iso.Split('T')[0];
        var parts = day.Split('-');
        var shown = parts.Length == 3 ? $"{parts[2]}.{parts[1]}.{parts[0]}" : iso;
        if (shift == 2 && parts.Length == 3
            && DateTime.TryParse(day, CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
            shown = date.AddDays(-1).ToString("dd.MM.yyyy", CultureInfo.InvariantCulture);
        var clock = "";
        if (DateTimeOffset.TryParse(createdAt, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var moment))
        {
            var zone = TimeZoneInfo.FindSystemTimeZoneById(
                OperatingSystem.IsWindows() ? "GTB Standard Time" : "Europe/Bucharest");
            clock = " " + TimeZoneInfo.ConvertTime(moment, zone).ToString("HH:mm", CultureInfo.InvariantCulture);
        }
        return shown + clock + " · tura " + shift;
    }

    private static decimal Amount(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value))
            return 0;
        decimal number = 0;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out number))
            return number;
        decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out number);
        return number;
    }

    private static string Ron(decimal amount) =>
        amount.ToString("0.00", CultureInfo.GetCultureInfo("ro-RO"));

    private static DataGridTextColumn Column(string header, string path, double width) => new()
    {
        Header = header,
        Binding = new Avalonia.Data.Binding(path),
        Width = new DataGridLength(width)
    };

    private sealed record PlaceChoice(Guid? Id, string Name)
    {
        public override string ToString() => Name;
    }

    private sealed record Row(
        Guid Id,
        string Number,
        string Date,
        string SheetDay,
        Guid? LocationId,
        string Place,
        string Total,
        string Cash,
        string Card,
        string Modern,
        decimal CashValue,
        decimal CardValue,
        decimal ModernValue);
}

public sealed class AdminConsumptions : UserControl
{
    private readonly AppSession _session;
    private readonly Action _back;
    private readonly Border _host = new();
    private readonly TextBox _search = new() { Watermark = "Caută număr, punct sau motiv", MinWidth = 240 };
    private readonly ComboBox _location = new() { MinWidth = 200 };
    private List<Item> _items = new();

    public AdminConsumptions(AppSession session, Action back)
    {
        _session = session;
        _back = back;
        Content = _host;
        _ = Load();
    }

    private async Task Load()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10 };
        page.Children.Add(Back("← Administrator", _back));
        page.Children.Add(new TextBlock { Text = "Bonuri de consum", FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        var filters = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var dayMode = new ComboBox { MinWidth = 110 };
        dayMode.Items.Add("Toate");
        dayMode.Items.Add("O zi");
        dayMode.SelectedIndex = 0;
        var date = new CalendarDatePicker { SelectedDate = DateTime.Today, Width = 160, IsVisible = false };
        filters.Children.Add(_location);
        filters.Children.Add(dayMode);
        filters.Children.Add(date);
        filters.Children.Add(_search);
        page.Children.Add(filters);
        var list = new StackPanel { Spacing = 8 };
        page.Children.Add(list);
        _host.Child = new ScrollViewer { Content = page };
        if (_session.CurrentCompany == null)
        {
            list.Children.Add(Muted("Selectați o societate."));
            return;
        }
        try
        {
            var places = await _session.SelectAllPages(
                "company_work_locations",
                $"company_id=eq.{_session.CurrentCompany.Id}&is_active=eq.true&select=id,denumire&order=denumire.asc");
            var names = new Dictionary<Guid, string>();
            _location.Items.Clear();
            _location.Items.Add(new Choice(null, "Toate punctele"));
            foreach (var place in places)
            {
                if (!place.TryGetProperty("id", out var id) || !id.TryGetGuid(out var guid))
                    continue;
                var name = Text(place, "denumire");
                names[guid] = name;
                _location.Items.Add(new Choice(guid, name));
            }
            _location.SelectedIndex = 0;
            var warehouses = await _session.SelectAllPages(
                "company_warehouses",
                $"company_id=eq.{_session.CurrentCompany.Id}&select=id,denumire,work_location_id");
            var warehousePlace = new Dictionary<Guid, (string Name, Guid? Location)>();
            foreach (var warehouse in warehouses)
            {
                if (!warehouse.TryGetProperty("id", out var id) || !id.TryGetGuid(out var guid))
                    continue;
                Guid? location = warehouse.TryGetProperty("work_location_id", out var loc) && loc.TryGetGuid(out var locationId) ? locationId : null;
                warehousePlace[guid] = (Text(warehouse, "denumire"), location);
            }
            var rows = await _session.SelectAllPages(
                "consumption_vouchers",
                $"company_id=eq.{_session.CurrentCompany.Id}&select=id,numar,data_bon,shift_no,motiv,status,warehouse_id&order=data_bon.desc");
            _items = new List<Item>();
            foreach (var row in rows)
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var voucherId))
                    continue;
                Guid? warehouseId = row.TryGetProperty("warehouse_id", out var warehouse) && warehouse.TryGetGuid(out var parsed) ? parsed : null;
                var depot = "";
                Guid? locationId = null;
                if (warehouseId != null && warehousePlace.TryGetValue(warehouseId.Value, out var known))
                {
                    depot = known.Name;
                    locationId = known.Location;
                }
                var place = locationId != null && names.TryGetValue(locationId.Value, out var placeName) ? placeName : depot;
                _items.Add(new Item(voucherId, Text(row, "numar"), Text(row, "data_bon"), ShiftLabel(row), Text(row, "motiv"), Text(row, "status"), place, locationId));
            }
            void Paint() => Fill(list, dayMode, date);
            _location.SelectionChanged += (_, _) => Paint();
            dayMode.SelectionChanged += (_, _) =>
            {
                date.IsVisible = dayMode.SelectedIndex == 1;
                Paint();
            };
            date.SelectedDateChanged += (_, _) =>
            {
                if (dayMode.SelectedIndex == 1)
                    Paint();
            };
            _search.TextChanged += (_, _) => Paint();
            Paint();
        }
        catch (Exception ex)
        {
            list.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private void Fill(StackPanel list, ComboBox dayMode, CalendarDatePicker date)
    {
        list.Children.Clear();
        var query = (_search.Text ?? "").Trim();
        var place = _location.SelectedItem as Choice;
        var day = dayMode.SelectedIndex == 1
            ? (date.SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
            : null;
        var shown = _items.Where(item =>
        {
            if (day != null && !item.Date.StartsWith(day, StringComparison.Ordinal))
                return false;
            if (place?.Id != null && item.LocationId != place.Id)
                return false;
            if (query.Length == 0)
                return true;
            return item.Number.Contains(query, StringComparison.OrdinalIgnoreCase)
                || item.Place.Contains(query, StringComparison.OrdinalIgnoreCase)
                || item.Reason.Contains(query, StringComparison.OrdinalIgnoreCase);
        }).ToList();
        var pending = shown.Where(item => item.Status != "approved").ToList();
        var done = shown.Where(item => item.Status == "approved").ToList();
        AddGroup(list, "De aprobat", pending);
        AddGroup(list, "Finalizate", done);
    }

    private void AddGroup(StackPanel list, string title, List<Item> items)
    {
        list.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 18,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            Margin = new Avalonia.Thickness(0, 8, 0, 0)
        });
        if (items.Count == 0)
        {
            list.Children.Add(Muted("Niciun bon."));
            return;
        }
        foreach (var item in items)
        {
            var chosen = item;
            list.Children.Add(SectionHome.Tile(
                "BC " + chosen.Number + " · " + Status(chosen.Status),
                chosen.Place + " · " + Shown(chosen.Date) + (string.IsNullOrWhiteSpace(chosen.Shift) ? "" : " · " + chosen.Shift) + (string.IsNullOrWhiteSpace(chosen.Reason) ? "" : " · " + chosen.Reason),
                () => Dispatcher.UIThread.Post(() => _ = Detail(chosen.Id))));
        }
    }

    private async Task Detail(Guid id)
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 760 };
        page.Children.Add(Back("← Bonuri de consum", () => Dispatcher.UIThread.Post(() => _ = Load())));
        var status = new TextBlock { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var headers = await _session.SelectRows("consumption_vouchers", $"id=eq.{id}&select=numar,data_bon,shift_no,motiv,status");
            if (headers.ValueKind != JsonValueKind.Array || headers.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Bonul nu mai există."));
                return;
            }
            var header = headers[0];
            var voucherStatus = Text(header, "status");
            page.Children.Add(new TextBlock
            {
                Text = "BC " + Text(header, "numar") + " · " + Shown(Text(header, "data_bon")) + (string.IsNullOrWhiteSpace(ShiftLabel(header)) ? "" : " · " + ShiftLabel(header)) + " · " + Status(voucherStatus),
                FontSize = 18,
                FontWeight = FontWeight.SemiBold,
                Foreground = Brand.Brush(Brand.Navy),
                TextWrapping = TextWrapping.Wrap
            });
            page.Children.Add(Muted(Text(header, "motiv")));
            var lines = await _session.SelectRows(
                "consumption_voucher_lines",
                $"voucher_id=eq.{id}&select=id,cantitate,unitate_masura,aprobat,product:products(denumire)&order=numar_linie.asc");
            var checks = new List<(Guid Id, CheckBox Box)>();
            if (lines.ValueKind == JsonValueKind.Array)
            {
                foreach (var line in lines.EnumerateArray())
                {
                    var lineId = line.GetProperty("id").GetGuid();
                    var approved = line.TryGetProperty("aprobat", out var flag) && flag.ValueKind == JsonValueKind.True;
                    var name = "";
                    if (line.TryGetProperty("product", out var product) && product.ValueKind == JsonValueKind.Object)
                        name = Text(product, "denumire");
                    var box = new CheckBox
                    {
                        Content = name + "  ·  " + Text(line, "cantitate") + " " + Text(line, "unitate_masura"),
                        IsChecked = approved || voucherStatus == "draft"
                    };
                    checks.Add((lineId, box));
                    page.Children.Add(box);
                }
            }
            page.Children.Add(status);
            page.Children.Add(Action("Aprobă tot", async () =>
            {
                if (!await ConfirmDialog.Ask(this, "Aprobarea scade stocul și recalculează foile de la data bonului."))
                    return;
                await _session.Rpc("approve_consumption_voucher", new { p_voucher_id = id.ToString(), p_approve_all = true, p_line_ids = Array.Empty<string>() });
                await Detail(id);
            }, status));
            page.Children.Add(Action("Salvează liniile bifate", async () =>
            {
                var ids = checks.Where(item => item.Box.IsChecked == true).Select(item => item.Id.ToString()).ToArray();
                if (ids.Length == 0)
                {
                    status.Text = "Bifați cel puțin o linie. Liniile nebifate rămân neaprobate.";
                    return;
                }
                if (!await ConfirmDialog.Ask(this, "Se aprobă doar liniile bifate. Cele nebifate rămân neaprobate și nu se scad din stoc."))
                    return;
                await _session.Rpc("approve_consumption_voucher", new { p_voucher_id = id.ToString(), p_approve_all = false, p_line_ids = ids });
                await Detail(id);
            }, status));
            if (voucherStatus != "draft")
            {
                page.Children.Add(Action("Redeschide", async () =>
                {
                    if (!await ConfirmDialog.Ask(this, "Redeschiderea pune înapoi stocul scăzut și recalculează foile."))
                        return;
                    await _session.Rpc("reopen_consumption_voucher", new { p_voucher_id = id.ToString() });
                    await Detail(id);
                }, status));
            }
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
        }
    }

    private static Button Action(string title, Func<Task> run, TextBlock status)
    {
        var button = new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Left,
            Padding = new Avalonia.Thickness(14, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        button.Click += (_, _) => Dispatcher.UIThread.Post(async () =>
        {
            try
            {
                await run();
            }
            catch (Exception ex)
            {
                status.Text = ex.Message;
            }
        });
        return button;
    }

    private static Button Back(string title, Action action)
    {
        var button = new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brushes.White
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static TextBlock Muted(string text) => new()
    {
        Text = text,
        TextWrapping = TextWrapping.Wrap,
        Foreground = Brand.Brush(Brand.Muted)
    };

    private static string Status(string value) => value switch
    {
        "approved" => "Aprobat",
        "partial" => "Aprobat parțial",
        "draft" => "Neaprobat",
        _ => value
    };

    private static string Shown(string iso)
    {
        var day = iso.Split('T')[0];
        var parts = day.Split('-');
        return parts.Length == 3 ? $"{parts[2]}.{parts[1]}.{parts[0]}" : iso;
    }

    private static string Text(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.ToString();
    }

    private sealed record Choice(Guid? Id, string Name)
    {
        public override string ToString() => Name;
    }

    private sealed record Item(Guid Id, string Number, string Date, string Shift, string Reason, string Status, string Place, Guid? LocationId);

    private static string ShiftLabel(JsonElement row)
    {
        if (!row.TryGetProperty("shift_no", out var value) || value.ValueKind != JsonValueKind.Number)
            return "";
        return value.GetInt32() switch
        {
            1 => "1 — ziua",
            2 => "2 — noapte",
            _ => ""
        };
    }
}

sealed class PdfFileWindow : Window
{
    private readonly byte[] _pdf;
    private readonly string _fileName;

    public PdfFileWindow(string title, string body, byte[] pdf, string fileName)
    {
        _pdf = pdf;
        _fileName = fileName;
        Title = title;
        Topmost = true;
        Width = 460;
        Height = 320;
        CanResize = false;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = Brand.Brush(Brand.Page);
        Icon = Brand.WindowIcon();
        var print = new Button { Content = "Listează", Padding = new Avalonia.Thickness(14, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White };
        var save = new Button { Content = "Descarcă PDF", Padding = new Avalonia.Thickness(14, 8), Background = Brushes.White };
        var close = new Button { Content = "Închide", Padding = new Avalonia.Thickness(14, 8), Background = Brushes.White };
        print.Click += (_, _) => Open(print: true);
        save.Click += async (_, _) => await Save();
        close.Click += (_, _) => Close();
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        bar.Children.Add(print);
        bar.Children.Add(save);
        bar.Children.Add(close);
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 16 };
        page.Children.Add(new TextBlock { Text = title, FontSize = 20, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        page.Children.Add(new TextBlock { Text = body, TextWrapping = TextWrapping.Wrap, FontSize = 16 });
        page.Children.Add(bar);
        Content = page;
        Open(print: false);
    }

    private void Open(bool print)
    {
        var path = Path.Combine(Path.GetTempPath(), _fileName);
        File.WriteAllBytes(path, _pdf);
        var info = new ProcessStartInfo(path) { UseShellExecute = true };
        if (print)
            info.Verb = "print";
        Process.Start(info);
    }

    private async Task Save()
    {
        var saved = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "Salvează PDF",
            SuggestedFileName = _fileName,
            DefaultExtension = "pdf",
            FileTypeChoices = [new FilePickerFileType("PDF") { Patterns = ["*.pdf"] }]
        });
        var path = saved?.TryGetLocalPath();
        if (string.IsNullOrEmpty(path))
            return;
        await File.WriteAllBytesAsync(path, _pdf);
    }
}
