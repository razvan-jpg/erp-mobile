using System.Globalization;
using ERPMobile.Services;
using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.VisualTree;

namespace ERPMobile.Ui;

public sealed class StockSheetListView : UserControl
{
    private readonly AppSession _session;
    private readonly ComboBox _location = new() { MinWidth = 220 };
    private readonly TextBlock _locationLabel = new() { Text = "Locație", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) };
    private readonly ComboBox _dayMode = new() { MinWidth = 110 };
    private readonly CalendarDatePicker _date = new() { SelectedDate = DateTime.Today, Width = 160, IsVisible = false };
    private readonly TextBox _search = new() { Watermark = "Caută foaie, Z sau locație", MinWidth = 220 };
    private readonly DataGrid _grid = new() { AutoGenerateColumns = false, IsReadOnly = true, CanUserSortColumns = false };
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap };
    private readonly List<LocationChoice> _locations = new();
    private readonly List<SheetRow> _sheets = new();
    private readonly bool _offersAll;
    private bool _loading;

    public StockSheetListView(AppSession session, bool offersAll = false)
    {
        _session = session;
        _offersAll = offersAll;
        _grid.Columns.Add(Column("Document", nameof(SheetRow.Document), 140));
        _grid.Columns.Add(Column("Foaie", nameof(SheetRow.Title), 320));
        _grid.Columns.Add(Column("Locație", nameof(SheetRow.Location), 180));
        _grid.AddHandler(
            InputElement.PointerReleasedEvent,
            OnSheetClick,
            RoutingStrategies.Bubble,
            handledEventsToo: true);
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Avalonia.Thickness(20, 12, 20, 0) };
        bar.Children.Add(_locationLabel);
        bar.Children.Add(_location);
        if (offersAll)
        {
            _dayMode.Items.Add("Toate");
            _dayMode.Items.Add("O zi");
            _dayMode.SelectedIndex = 0;
            _date.IsVisible = false;
        }
        else
        {
            _date.IsVisible = true;
        }
        bar.Children.Add(new TextBlock { Text = "Data", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        if (offersAll)
            bar.Children.Add(_dayMode);
        bar.Children.Add(_date);
        bar.Children.Add(_search);
        _search.TextChanged += (_, _) => ShowSheets();
        _location.SelectionChanged += async (_, _) =>
        {
            if (!_loading)
                await Load();
        };
        _dayMode.SelectionChanged += async (_, _) =>
        {
            _date.IsVisible = _dayMode.SelectedIndex == 1;
            if (!_loading)
                await Load();
        };
        _date.SelectedDateChanged += async (_, _) =>
        {
            if (!_loading && (!_offersAll || _dayMode.SelectedIndex == 1))
                await Load();
        };
        var page = new DockPanel();
        DockPanel.SetDock(bar, Dock.Top);
        DockPanel.SetDock(_status, Dock.Bottom);
        _status.Margin = new Avalonia.Thickness(20, 8);
        page.Children.Add(bar);
        page.Children.Add(_status);
        page.Children.Add(_grid);
        Content = page;
        _ = Load();
    }

    private async void OnSheetClick(object? sender, PointerReleasedEventArgs e)
    {
        if (e.InitialPressMouseButton != MouseButton.Left)
            return;
        if (e.Source is not Visual visual)
            return;
        var gridRow = visual as DataGridRow ?? visual.FindAncestorOfType<DataGridRow>();
        if (gridRow?.DataContext is not SheetRow sheet)
            return;
        await OpenPdf(sheet);
    }

    private async Task OpenPdf(SheetRow sheet)
    {
        try
        {
            var lines = await Pages(
                "z_stock_sheet_lines",
                $"sheet_id=eq.{sheet.Id}&select=product_id,nr_crt,denumire,category,unitate_masura,opening_qty,inflow_qty,sale_store_qty,sale_online_qty,transfer_out_qty,recipe_out_qty,price_store,price_online,value_store,value_online,profit,closing_qty,mismatch,products(cod)&order=nr_crt.asc");
            var day = sheet.SheetDate;
            var moved = lines.Select(StockSheetFormPdf.Map).Where(StockSheetFormPdf.HasMovement).ToList();
            moved.AddRange(await Guarantee(lines));
            var consumptions = await Consumptions(sheet);
            var pdf = StockSheetFormPdf.Make(
                _session.CurrentCompany?.Denumire ?? "",
                _session.CurrentCompany?.Cui,
                sheet.Location,
                sheet.Document,
                day,
                ShiftOf(sheet.Title),
                sheet.ZNumber,
                sheet.ZTime,
                moved,
                new StockSheetFormPdf.Takings(sheet.Cash, sheet.Card, sheet.Modern, sheet.Glovo, sheet.Bolt, sheet.Wolt),
                consumptions);
            var window = new StockSheetPreviewWindow(
                "Foaie de stoc " + sheet.Document,
                sheet.Title + " · " + sheet.Document + " · " + sheet.Location,
                pdf,
                StockSheetFormPdf.FileName(sheet.Document),
                moved,
                new StockSheetFormPdf.Takings(sheet.Cash, sheet.Card, sheet.Modern, sheet.Glovo, sheet.Bolt, sheet.Wolt),
                consumptions);
            if (TopLevel.GetTopLevel(this) is Window owner)
                await window.ShowDialog(owner);
            else
                window.Show();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async Task<List<StockSheetFormPdf.Line>> Guarantee(List<JsonElement> lines)
    {
        var sold = new Dictionary<Guid, (decimal Store, decimal Online)>();
        foreach (var row in lines)
        {
            if (!row.TryGetProperty("product_id", out var id) || !id.TryGetGuid(out var product))
                continue;
            var store = Number(row, "sale_store_qty");
            var online = Number(row, "sale_online_qty");
            if (store == 0 && online == 0)
                continue;
            if (sold.TryGetValue(product, out var qty))
                sold[product] = (qty.Store + store, qty.Online + online);
            else
                sold[product] = (store, online);
        }
        if (sold.Count == 0)
            return [];
        var links = await Pages(
            "product_sale_addons",
            "product_id=in.(" + string.Join(",", sold.Keys) + ")&select=product_id,cantitate,addon_product_id");
        var addonIds = links
            .Select(row => row.TryGetProperty("addon_product_id", out var id) && id.TryGetGuid(out var addon) ? addon : Guid.Empty)
            .Where(id => id != Guid.Empty)
            .Distinct()
            .ToList();
        if (addonIds.Count == 0)
            return [];
        var products = await Pages(
            "products",
            "id=in.(" + string.Join(",", addonIds) + ")&select=id,denumire,tip,pret_vanzare,pret_vanzare_online");
        var addons = products
            .Where(row => Text(row, "tip") == "garantie")
            .ToDictionary(row => row.GetProperty("id").GetGuid());
        var totals = new Dictionary<string, (decimal Store, decimal Online)>();
        foreach (var link in links)
        {
            if (!link.TryGetProperty("addon_product_id", out var addonId) || !addonId.TryGetGuid(out var addon) || !addons.TryGetValue(addon, out var product))
                continue;
            if (!link.TryGetProperty("product_id", out var parentId) || !parentId.TryGetGuid(out var parent) || !sold.TryGetValue(parent, out var qty))
                continue;
            var count = Number(link, "cantitate");
            if (count == 0)
                count = 1;
            var name = Text(product, "denumire");
            if (name.Length == 0)
                name = "Garantie SGR";
            var store = qty.Store * count * Number(product, "pret_vanzare");
            var online = qty.Online * count * Number(product, "pret_vanzare_online");
            if (totals.TryGetValue(name, out var current))
                totals[name] = (current.Store + store, current.Online + online);
            else
                totals[name] = (store, online);
        }
        return totals
            .Where(item => item.Value.Store != 0 || item.Value.Online != 0)
            .Select(item => StockSheetFormPdf.Guarantee(item.Key, item.Value.Store, item.Value.Online))
            .ToList();
    }

    private async Task<List<StockSheetFormPdf.ConsumptionRow>> Consumptions(SheetRow sheet)
    {
        var meta = await Pages("z_stock_sheets", $"id=eq.{sheet.Id}&select=warehouse_id,work_location_id,created_at");
        if (meta.Count == 0)
            return [];
        var head = meta[0];
        if (!head.TryGetProperty("warehouse_id", out var warehouseValue) || !warehouseValue.TryGetGuid(out var warehouse))
            return [];
        if (!head.TryGetProperty("work_location_id", out var locationValue) || !locationValue.TryGetGuid(out var location))
            return [];
        var end = Text(head, "created_at");
        if (end.Length == 0)
            return [];
        var encodedEnd = Uri.EscapeDataString(end);
        var previous = await Pages(
            "z_stock_sheets",
            $"work_location_id=eq.{location}&created_at=lt.{encodedEnd}&select=created_at&order=created_at.desc&limit=1");
        var start = previous.Count == 0 ? "" : Text(previous[0], "created_at");
        var newer = await Pages(
            "z_stock_sheets",
            $"work_location_id=eq.{location}&created_at=gt.{encodedEnd}&select=id&limit=1");
        var latest = newer.Count == 0;
        var moveFilter = $"warehouse_id=eq.{warehouse}&sursa=eq.consumption_voucher&tip=eq.iesire&created_at=lte.{encodedEnd}&select=consumption_voucher_id";
        if (start.Length > 0)
            moveFilter += "&created_at=gt." + Uri.EscapeDataString(start);
        var moves = await Pages("stock_movements", moveFilter);
        var deducted = new HashSet<Guid>();
        foreach (var move in moves)
        {
            if (move.TryGetProperty("consumption_voucher_id", out var voucherId) && voucherId.TryGetGuid(out var voucher))
                deducted.Add(voucher);
        }
        var voucherSelect = "id,numar,motiv,created_at,data_bon,shift_no,consumption_voucher_lines(aprobat,cantitate,unitate_masura,numar_linie,products(denumire))";
        var voucherFilter = "warehouse_id=eq." + warehouse
            + "&select=" + voucherSelect + "&order=created_at.asc";
        if (start.Length > 0)
            voucherFilter += "&created_at=gt." + Uri.EscapeDataString(start);
        if (!latest)
            voucherFilter += "&created_at=lte." + encodedEnd;
        var vouchers = await Pages("consumption_vouchers", voucherFilter);
        var have = new HashSet<Guid>();
        foreach (var voucher in vouchers)
        {
            if (voucher.TryGetProperty("id", out var id) && id.TryGetGuid(out var voucherId))
                have.Add(voucherId);
        }
        var missing = deducted.Where(id => !have.Contains(id)).ToList();
        if (missing.Count > 0)
        {
            var extra = await Pages(
                "consumption_vouchers",
                "id=in.(" + string.Join(",", missing) + ")&select=" + voucherSelect);
            vouchers.AddRange(extra);
            foreach (var voucher in extra)
            {
                if (voucher.TryGetProperty("id", out var id) && id.TryGetGuid(out var voucherId))
                    have.Add(voucherId);
            }
        }
        var sheetShift = ShiftOf(sheet.Title);
        var businessDay = BusinessDay(sheet.SheetDate, sheetShift);
        if (sheetShift is 1 or 2 && businessDay.Length > 0)
        {
            var aimed = await Pages(
                "consumption_vouchers",
                "warehouse_id=eq." + warehouse + "&shift_no=eq." + sheetShift + "&data_bon=eq." + businessDay + "&select=" + voucherSelect);
            foreach (var voucher in aimed)
            {
                if (!voucher.TryGetProperty("id", out var id) || !id.TryGetGuid(out var voucherId) || have.Contains(voucherId))
                    continue;
                have.Add(voucherId);
                vouchers.Add(voucher);
            }
        }
        var rows = new List<StockSheetFormPdf.ConsumptionRow>();
        foreach (var voucher in vouchers.OrderBy(item => Text(item, "numar"), StringComparer.Ordinal))
        {
            if (!voucher.TryGetProperty("id", out var id) || !id.TryGetGuid(out var voucherId))
                continue;
            var created = Text(voucher, "created_at");
            var inWindow = (start.Length == 0 || Later(created, start)) && !Later(created, end);
            var after = latest && Later(created, end);
            var hit = deducted.Contains(voucherId);
            var shift = ShiftNo(voucher);
            var aimed = shift == sheetShift && Text(voucher, "data_bon").StartsWith(businessDay, StringComparison.Ordinal);
            var legacy = shift == null && (inWindow || after || hit);
            if (!aimed && !legacy)
                continue;
            if (!voucher.TryGetProperty("consumption_voucher_lines", out var lines) || lines.ValueKind != JsonValueKind.Array)
                continue;
            var number = Text(voucher, "numar");
            var why = Text(voucher, "motiv").Replace('\n', ' ').Trim();
            foreach (var line in lines.EnumerateArray().OrderBy(item => Number(item, "numar_linie")))
            {
                var approved = line.TryGetProperty("aprobat", out var flag) && flag.ValueKind == JsonValueKind.True;
                if (approved && !hit && !aimed)
                    continue;
                if (!approved && !inWindow && !after && !hit && !aimed)
                    continue;
                var name = "";
                if (line.TryGetProperty("products", out var product) && product.ValueKind == JsonValueKind.Object)
                    name = Text(product, "denumire");
                rows.Add(new StockSheetFormPdf.ConsumptionRow(
                    approved,
                    number,
                    name,
                    StockFormat.Text(Number(line, "cantitate")),
                    Text(line, "unitate_masura"),
                    why));
            }
        }
        return rows.OrderBy(row => row.Approved ? 0 : 1).ThenBy(row => row.Number, StringComparer.Ordinal).ToList();

        static bool Later(string left, string right)
        {
            if (DateTimeOffset.TryParse(left, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var a)
                && DateTimeOffset.TryParse(right, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var b))
                return a > b;
            return string.CompareOrdinal(left, right) > 0;
        }
    }

    private static string BusinessDay(string sheetDate, int shift)
    {
        var day = sheetDate.Length >= 10 ? sheetDate[..10] : sheetDate;
        if (shift != 2 || !DateTime.TryParse(day, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
            return day;
        return parsed.AddDays(-1).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    }

    private static int? ShiftNo(JsonElement row)
    {
        if (!row.TryGetProperty("shift_no", out var value) || value.ValueKind != JsonValueKind.Number)
            return null;
        return value.GetInt32();
    }

    private static int ShiftOf(string title)
    {
        var marker = "Tura ";
        var at = title.IndexOf(marker, StringComparison.Ordinal);
        if (at < 0 || at + marker.Length >= title.Length)
            return 0;
        var digit = title[at + marker.Length];
        return digit is >= '1' and <= '9' ? digit - '0' : 0;
    }

    private async Task Load()
    {
        if (_session.CurrentCompany == null)
        {
            _status.Text = "Selectați o societate.";
            return;
        }
        _loading = true;
        _status.Text = "Se încarcă...";
        _status.Foreground = Brand.Brush(Brand.Muted);
        try
        {
            var company = _session.CurrentCompany.Id;
            if (_locations.Count == 0)
            {
                var locations = await Pages("company_work_locations", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
                var real = new List<LocationChoice>();
                foreach (var row in locations)
                {
                    if (row.TryGetProperty("id", out var id) && id.TryGetGuid(out var guid))
                        real.Add(new LocationChoice(guid, Text(row, "denumire")));
                }
                if (_offersAll || real.Count != 1)
                {
                    _locations.Add(new LocationChoice(null, "Toate"));
                    _locations.AddRange(real);
                    _location.IsVisible = true;
                    _locationLabel.IsVisible = true;
                }
                else if (real.Count == 1)
                {
                    _locations.Add(real[0]);
                    _location.IsVisible = false;
                    _locationLabel.IsVisible = false;
                }
                _location.ItemsSource = _locations;
                _location.SelectedIndex = 0;
            }
            var chosen = _location.SelectedItem as LocationChoice ?? _locations[0];
            var filter = $"company_id=eq.{company}&select=id,work_location_id,series,numar,sheet_date,shift_no,z_number,created_at,glovo,bolt,wolt,total_vanzare,plata_card,plata_moderna,numerar&order=created_at.desc";
            if (!_offersAll || _dayMode.SelectedIndex == 1)
            {
                var day = (_date.SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                filter += $"&sheet_date=eq.{day}";
            }
            if (chosen.Id != null)
                filter += $"&work_location_id=eq.{chosen.Id}";
            var rows = await Pages("z_stock_sheets", filter);
            var names = _locations.Where(item => item.Id != null).ToDictionary(item => item.Id!.Value, item => item.Name);
            _sheets.Clear();
            foreach (var row in rows)
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var sheetId))
                    continue;
                Guid? locationId = null;
                if (row.TryGetProperty("work_location_id", out var location) && location.TryGetGuid(out var parsed))
                    locationId = parsed;
                var series = Text(row, "series");
                var number = (int)Number(row, "numar");
                var shift = (int)Number(row, "shift_no");
                var z = Text(row, "z_number");
                var date = Text(row, "sheet_date");
                var parts = date.Split('-');
                var shownDay = DateTime.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsedDay)
                    ? parsedDay
                    : DateTime.MinValue;
                if (shownDay != DateTime.MinValue && shift == 2)
                    shownDay = shownDay.AddDays(-1);
                var shown = shownDay == DateTime.MinValue
                    ? (parts.Length == 3 ? $"{parts[2]}.{parts[1]}.{parts[0]}" : date)
                    : shownDay.ToString("dd.MM.yyyy", CultureInfo.InvariantCulture);
                var clock = Clock(Text(row, "created_at"));
                names.TryGetValue(locationId ?? Guid.Empty, out var locationName);
                var title = string.IsNullOrEmpty(clock)
                    ? $"{shown} · Tura {shift} (Z {(string.IsNullOrWhiteSpace(z) ? "—" : z)})"
                    : $"{shown} {clock} · Tura {shift} (Z {(string.IsNullOrWhiteSpace(z) ? "—" : z)})";
                _sheets.Add(new SheetRow(
                    sheetId,
                    series + " " + number,
                    title,
                    locationName ?? "",
                    date,
                    string.IsNullOrWhiteSpace(z) ? "—" : z,
                    Number(row, "glovo"),
                    Number(row, "bolt"),
                    Number(row, "wolt"),
                    Number(row, "plata_card"),
                    Number(row, "plata_moderna"),
                    Number(row, "numerar"),
                    clock));
            }
            ShowSheets();
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

    private void ShowSheets()
    {
        var query = (_search.Text ?? "").Trim();
        var shown = string.IsNullOrEmpty(query)
            ? _sheets.ToList()
            : _sheets.Where(sheet =>
                sheet.Title.Contains(query, StringComparison.OrdinalIgnoreCase)
                || sheet.Document.Contains(query, StringComparison.OrdinalIgnoreCase)
                || sheet.Location.Contains(query, StringComparison.OrdinalIgnoreCase)
                || sheet.ZNumber.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();
        _grid.ItemsSource = null;
        _grid.ItemsSource = shown;
        _status.Text = shown.Count == 0
            ? "Nu există foaie de stoc pentru filtrul ales."
            : $"{shown.Count} foi";
        _status.Foreground = Brand.Brush(Brand.Muted);
    }

    private Task<List<JsonElement>> Pages(string table, string query) =>
        _session.SelectAllPages(table, query);

    private static DataGridTextColumn Column(string header, string path, double width) => new()
    {
        Header = header,
        Binding = new Avalonia.Data.Binding(path),
        Width = new DataGridLength(width)
    };

    private static string Clock(string createdAt)
    {
        if (!DateTimeOffset.TryParse(createdAt, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var instant))
            return "";
        var zone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Bucharest");
        return TimeZoneInfo.ConvertTime(instant, zone).ToString("HH:mm", CultureInfo.InvariantCulture);
    }

    private static string Text(JsonElement row, string name) =>
        row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : "";

    private static decimal Number(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value))
            return 0;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number))
            return number;
        return decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : 0;
    }

    private sealed record LocationChoice(Guid? Id, string Name)
    {
        public override string ToString() => Name;
    }

    private sealed record SheetRow(
        Guid Id,
        string Document,
        string Title,
        string Location,
        string SheetDate,
        string ZNumber,
        decimal Glovo,
        decimal Bolt,
        decimal Wolt,
        decimal Card,
        decimal Modern,
        decimal Cash,
        string ZTime);
}
