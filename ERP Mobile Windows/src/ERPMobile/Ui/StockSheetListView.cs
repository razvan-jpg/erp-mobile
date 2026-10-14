using System.Globalization;
using ERPMobile.Services;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;

namespace ERPMobile.Ui;

public sealed class StockSheetListView : UserControl
{
    private readonly AppSession _session;
    private readonly ComboBox _location = new() { MinWidth = 220 };
    private readonly CalendarDatePicker _date = new() { SelectedDate = DateTime.Today, Width = 160 };
    private readonly DataGrid _grid = new() { AutoGenerateColumns = false, IsReadOnly = true, CanUserSortColumns = false };
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap };
    private readonly List<LocationChoice> _locations = new();
    private readonly List<SheetRow> _sheets = new();
    private bool _loading;
    private DockPanel? _listPage;

    public StockSheetListView(AppSession session)
    {
        _session = session;
        _grid.Columns.Add(Column("Document", nameof(SheetRow.Document), 140));
        _grid.Columns.Add(Column("Foaie", nameof(SheetRow.Title), 320));
        _grid.Columns.Add(Column("Locație", nameof(SheetRow.Location), 180));
        _grid.DoubleTapped += async (_, _) => await OpenSelected();
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Avalonia.Thickness(20, 12, 20, 0) };
        bar.Children.Add(new TextBlock { Text = "Locație", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        bar.Children.Add(_location);
        bar.Children.Add(new TextBlock { Text = "Data", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        bar.Children.Add(_date);
        _location.SelectionChanged += async (_, _) =>
        {
            if (!_loading)
                await Load();
        };
        _date.SelectedDateChanged += async (_, _) =>
        {
            if (!_loading)
                await Load();
        };
        var page = new DockPanel();
        DockPanel.SetDock(bar, Dock.Top);
        DockPanel.SetDock(_status, Dock.Bottom);
        _status.Margin = new Avalonia.Thickness(20, 8);
        page.Children.Add(bar);
        page.Children.Add(_status);
        page.Children.Add(_grid);
        _listPage = page;
        Content = page;
        _ = Load();
    }

    private async Task OpenSelected()
    {
        if (_grid.SelectedItem is not SheetRow sheet)
            return;
        try
        {
            var lines = await Pages(
                "z_stock_sheet_lines",
                $"sheet_id=eq.{sheet.Id}&select=nr_crt,denumire,category,opening_qty,inflow_qty,sale_store_qty,sale_online_qty,transfer_out_qty,recipe_out_qty,price_store,price_online,value_store,value_online,profit,closing_qty,mismatch&order=nr_crt.asc");
            var grid = new DataGrid { AutoGenerateColumns = false, IsReadOnly = true, CanUserSortColumns = false };
            var rows = lines.Select(MapLine).ToList();
            grid.Columns.Add(Column("Nr", nameof(LineRow.Number), 50));
            grid.Columns.Add(Column("Denumire", nameof(LineRow.Name), 240));
            grid.Columns.Add(Column("Categorie", nameof(LineRow.Category), 120));
            grid.Columns.Add(Column("Inițial", nameof(LineRow.Opening), 80));
            grid.Columns.Add(Column("Intrări", nameof(LineRow.Inflow), 80));
            grid.Columns.Add(Column("Final", nameof(LineRow.Closing), 80));
            grid.Columns.Add(Column("Magazin", nameof(LineRow.Store), 80));
            grid.Columns.Add(Column("Online", nameof(LineRow.Online), 80));
            grid.Columns.Add(Column("Valoare", nameof(LineRow.Value), 140));
            grid.Columns.Add(Column("Profit", nameof(LineRow.Profit), 90));
            grid.LoadingRow += (_, e) =>
            {
                if (e.Row.DataContext is LineRow line && line.Closing.StartsWith("!"))
                    e.Row.Foreground = Brushes.Red;
            };
            grid.ItemsSource = rows;
            var back = new Button { Content = "← Listă" };
            var root = new DockPanel();
            var top = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12, Margin = new Avalonia.Thickness(20, 12, 20, 0) };
            top.Children.Add(back);
            top.Children.Add(new TextBlock
            {
                Text = sheet.Title + " · " + sheet.Document,
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = Brand.Brush(Brand.Navy),
                FontWeight = FontWeight.SemiBold
            });
            var foot = new TextBlock
            {
                Margin = new Avalonia.Thickness(20, 8),
                TextWrapping = TextWrapping.Wrap,
                Text = $"Glovo {sheet.Glovo}    Bolt {sheet.Bolt}    Wolt {sheet.Wolt}\nZ = {sheet.ZNumber}    Total vânzare = {sheet.Sales}    Card = {sheet.Card}    Modernă = {sheet.Modern}    Numerar = {sheet.Cash}    Bani predați = {sheet.Cash}"
            };
            back.Click += (_, _) => Content = _listPage;
            DockPanel.SetDock(top, Dock.Top);
            DockPanel.SetDock(foot, Dock.Bottom);
            root.Children.Add(top);
            root.Children.Add(foot);
            root.Children.Add(grid);
            Content = root;
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
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
        _status.Text = "Se încarcă...";
        _status.Foreground = Brand.Brush(Brand.Muted);
        try
        {
            var company = _session.CurrentCompany.Id;
            if (_locations.Count == 0)
            {
                var locations = await Pages("company_work_locations", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
                _locations.Add(new LocationChoice(null, "Toate locațiile"));
                foreach (var row in locations)
                {
                    if (row.TryGetProperty("id", out var id) && id.TryGetGuid(out var guid))
                        _locations.Add(new LocationChoice(guid, Text(row, "denumire")));
                }
                _location.ItemsSource = _locations;
                _location.SelectedIndex = 0;
            }
            var day = (_date.SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            var chosen = _location.SelectedItem as LocationChoice ?? _locations[0];
            var filter = $"company_id=eq.{company}&sheet_date=eq.{day}&select=id,work_location_id,series,numar,sheet_date,shift_no,z_number,glovo,bolt,wolt,total_vanzare,plata_card,plata_moderna,numerar&order=created_at.desc";
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
                var shown = parts.Length == 3 ? $"{parts[2]}.{parts[1]}.{parts[0]}" : date;
                names.TryGetValue(locationId ?? Guid.Empty, out var locationName);
                _sheets.Add(new SheetRow(
                    sheetId,
                    series + " " + number,
                    $"{shown} · Tura {shift} (Z {(string.IsNullOrWhiteSpace(z) ? "—" : z)})",
                    locationName ?? "",
                    string.IsNullOrWhiteSpace(z) ? "—" : z,
                    Money(row, "glovo"),
                    Money(row, "bolt"),
                    Money(row, "wolt"),
                    Money(row, "total_vanzare"),
                    Money(row, "plata_card"),
                    Money(row, "plata_moderna"),
                    Money(row, "numerar")));
            }
            _grid.ItemsSource = null;
            _grid.ItemsSource = _sheets.ToList();
            _status.Text = _sheets.Count == 0
                ? "Nu există foaie de stoc pentru data aleasă. Foaia se creează la închiderea Raportului Z."
                : $"{_sheets.Count} foi";
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

    private static LineRow MapLine(JsonElement row)
    {
        var category = Text(row, "category") switch
        {
            "finite" => "Produse finite",
            "drinks" => "Băuturi",
            _ => "Materii prime"
        };
        var mismatch = row.TryGetProperty("mismatch", out var flag) && flag.ValueKind == JsonValueKind.True;
        return new LineRow(
            ((int)Number(row, "nr_crt")).ToString(CultureInfo.InvariantCulture),
            Text(row, "denumire"),
            category,
            Qty(row, "opening_qty"),
            Qty(row, "inflow_qty"),
            (mismatch ? "! " : "") + Qty(row, "closing_qty"),
            Qty(row, "sale_store_qty"),
            Qty(row, "sale_online_qty"),
            Money(row, "value_store") + " / " + Money(row, "value_online"),
            Money(row, "profit"));
    }

    private async Task<List<JsonElement>> Pages(string table, string query)
    {
        var all = new List<JsonElement>();
        for (var from = 0; ; from += 1000)
        {
            var page = await _session.SelectRows(table, query, from, from + 999);
            if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                break;
            all.AddRange(page.EnumerateArray());
            if (page.GetArrayLength() < 1000)
                break;
        }
        return all;
    }

    private static DataGridTextColumn Column(string header, string path, double width) => new()
    {
        Header = header,
        Binding = new Avalonia.Data.Binding(path),
        Width = new DataGridLength(width)
    };

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

    private static string Qty(JsonElement row, string name) =>
        Number(row, name).ToString("0.####", CultureInfo.GetCultureInfo("ro-RO"));

    private static string Money(JsonElement row, string name) =>
        Number(row, name).ToString("0.00", CultureInfo.GetCultureInfo("ro-RO"));

    private sealed record LocationChoice(Guid? Id, string Name)
    {
        public override string ToString() => Name;
    }

    private sealed record SheetRow(
        Guid Id,
        string Document,
        string Title,
        string Location,
        string ZNumber,
        string Glovo,
        string Bolt,
        string Wolt,
        string Sales,
        string Card,
        string Modern,
        string Cash);

    private sealed record LineRow(
        string Number,
        string Name,
        string Category,
        string Opening,
        string Inflow,
        string Closing,
        string Store,
        string Online,
        string Value,
        string Profit);
}
