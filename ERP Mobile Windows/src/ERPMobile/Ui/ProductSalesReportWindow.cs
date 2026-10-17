using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Services;

namespace ERPMobile.Ui;

sealed class ProductSalesReportWindow : UserControl
{
    private readonly AppSession _session;
    private readonly Guid _locationId;
    private readonly TextBlock _title = new()
    {
        Text = "Raport Produse",
        FontSize = 22,
        FontWeight = FontWeight.SemiBold,
        Foreground = Brand.Brush(Brand.Navy),
        VerticalAlignment = VerticalAlignment.Center
    };
    private readonly StackPanel _zList = new() { Spacing = 8 };
    private readonly StackPanel _productList = new() { Spacing = 2 };
    private readonly ScrollViewer _zScroll;
    private readonly ScrollViewer _productScroll;
    private readonly TextBlock _status = new()
    {
        Foreground = Brand.Brush(Brand.Navy),
        FontSize = 16,
        TextWrapping = TextWrapping.Wrap,
        Margin = new Avalonia.Thickness(20, 8, 20, 12)
    };
    private readonly Action _close;
    private readonly Button _print;
    private bool _showingProducts;
    private bool _printing;
    private List<ProductRow> _rows = new();

    public ProductSalesReportWindow(AppSession session, Guid locationId, Action close)
    {
        _session = session;
        _locationId = locationId;
        _close = close;
        HorizontalAlignment = HorizontalAlignment.Stretch;
        VerticalAlignment = VerticalAlignment.Stretch;
        Background = Brand.Brush(Brand.Page);
        ZIndex = 40;

        _zList.Children.Add(ZButton("Z curent · În lucru - Neînchis", () => _ = ShowProducts(null, "Z curent · În lucru - Neînchis"), open: true));
        _zScroll = new ScrollViewer
        {
            Content = _zList,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            Margin = new Avalonia.Thickness(20, 0, 20, 8)
        };
        _productScroll = new ScrollViewer
        {
            Content = _productList,
            IsVisible = false,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            Margin = new Avalonia.Thickness(20, 0, 20, 8),
            Background = Brushes.White
        };

        var back = BarButton("Înapoi", false, Back);
        _print = BarButton("Print", false, () => _ = PrintProducts());
        _print.IsVisible = false;
        var closeButton = BarButton("Închide", true, _close);
        var header = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto,Auto"),
            Margin = new Avalonia.Thickness(20, 16)
        };
        Grid.SetColumn(_title, 1);
        Grid.SetColumn(_print, 2);
        Grid.SetColumn(closeButton, 3);
        _title.Margin = new Avalonia.Thickness(16, 0);
        _print.Margin = new Avalonia.Thickness(0, 0, 12, 0);
        header.Children.Add(back);
        header.Children.Add(_title);
        header.Children.Add(_print);
        header.Children.Add(closeButton);

        var host = new Grid();
        host.Children.Add(_zScroll);
        host.Children.Add(_productScroll);
        var page = new Grid
        {
            RowDefinitions = new RowDefinitions("Auto,*,Auto"),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };
        Grid.SetRow(header, 0);
        Grid.SetRow(host, 1);
        Grid.SetRow(_status, 2);
        page.Children.Add(header);
        page.Children.Add(host);
        page.Children.Add(_status);
        Content = page;
        _ = LoadSheets();
    }

    private void Back()
    {
        if (!_showingProducts)
        {
            _close();
            return;
        }
        _showingProducts = false;
        _productScroll.IsVisible = false;
        _zScroll.IsVisible = true;
        _title.Text = "Raport Produse";
        _status.Text = "";
        _status.Foreground = Brand.Brush(Brand.Muted);
        _print.IsVisible = false;
        _rows = new();
    }

    private async Task LoadSheets()
    {
        if (_session.CurrentCompany == null)
        {
            _status.Text = "Selectați o societate.";
            _status.Foreground = Brushes.Firebrick;
            return;
        }
        _status.Text = "Se încarcă...";
        try
        {
            var rows = await _session.SelectAllPages(
                "z_stock_sheets",
                $"company_id=eq.{_session.CurrentCompany.Id}&work_location_id=eq.{_locationId}&select=id,sheet_date,shift_no,z_number&order=created_at.desc");
            var choices = new List<(Guid? Id, string Label, bool Open)>
            {
                (null, "Z curent · În lucru - Neînchis", true)
            };
            foreach (var row in rows)
            {
                if (!ReadGuid(row, "id", out var sheetId))
                    continue;
                var number = Text(row, "z_number");
                if (string.IsNullOrWhiteSpace(number))
                    number = "—";
                var shift = row.TryGetProperty("shift_no", out var shiftValue) && shiftValue.TryGetInt32(out var shiftNo) ? shiftNo : 0;
                var label = $"Z {number} · {ShownDate(Text(row, "sheet_date"), shift)} · tura {shift}";
                choices.Add((sheetId, label, false));
            }
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                _zList.Children.Clear();
                foreach (var choice in choices)
                    _zList.Children.Add(ZButton(choice.Label, () => _ = ShowProducts(choice.Id, choice.Label), choice.Open));
                _status.Text = "";
            });
        }
        catch (Exception ex)
        {
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                _status.Text = ex.Message;
                _status.Foreground = Brushes.Firebrick;
            });
        }
    }

    private async Task ShowProducts(Guid? sheetId, string label)
    {
        _showingProducts = true;
        _title.Text = label;
        _zScroll.IsVisible = false;
        _productScroll.IsVisible = true;
        _productList.Children.Clear();
        _rows = new();
        _print.IsVisible = false;
        _status.Text = "Se încarcă...";
        _status.Foreground = Brand.Brush(Brand.Navy);
        try
        {
            var payload = sheetId == null
                ? await _session.Rpc("pos_sold_products", new { p_work_location_id = _locationId.ToString() })
                : await _session.Rpc("pos_sold_products", new { p_work_location_id = _locationId.ToString(), p_sheet_id = sheetId.Value.ToString() });
            var rows = new List<ProductRow>();
            if (payload.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in payload.EnumerateArray())
                    rows.Add(new ProductRow(
                        Group(row),
                        Order(row),
                        Text(row, "cod"),
                        Text(row, "denumire"),
                        Text(row, "um"),
                        Number(row, "cantitate"),
                        Number(row, "pret"),
                        Number(row, "valoare")));
            }
            await Dispatcher.UIThread.InvokeAsync(() => ShowRows(rows, payload.ValueKind == JsonValueKind.Array ? "" : payload.ToString()));
        }
        catch (Exception ex)
        {
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                _productList.Children.Clear();
                _productList.Children.Add(Message(ex.Message, error: true));
                _status.Text = ex.Message;
                _status.Foreground = Brushes.Firebrick;
            });
        }
    }

    private void ShowRows(List<ProductRow> rows, string raw)
    {
        _productList.Children.Clear();
        _productList.Children.Add(ProductLine("Cod", "Produs", "UM", "Cantitate", "Preț", "Total", header: true));
        if (rows.Count == 0)
        {
            var text = string.IsNullOrEmpty(raw) ? "Nu sunt produse vândute în acest Z." : raw;
            _productList.Children.Add(Message(text, error: !string.IsNullOrEmpty(raw)));
            _status.Text = text;
            _status.Foreground = string.IsNullOrEmpty(raw) ? Brand.Brush(Brand.Navy) : Brushes.Firebrick;
            return;
        }
        decimal grand = 0;
        foreach (var band in rows.GroupBy(row => row.Group))
        {
            var lines = band.ToList();
            var subtotal = lines.Sum(row => row.Value);
            grand += subtotal;
            _productList.Children.Add(Banner(lines[0].Group, grand: false));
            foreach (var row in lines)
                _productList.Children.Add(ProductLine(row.Code, row.Name, row.Unit, StockFormat.Text(row.Quantity), Money(row.Price), Money(row.Value), header: false));
            _productList.Children.Add(Summary("Subtotal", Money(subtotal), grand: false));
        }
        _productList.Children.Add(Summary("Total general", Money(grand), grand: true));
        _rows = rows;
        _print.IsVisible = true;
        _status.Text = rows.Count + " produse";
        _status.Foreground = Brand.Brush(Brand.Navy);
    }

    private async Task PrintProducts()
    {
        if (_printing || _rows.Count == 0)
            return;
        if (!FiscalNetStation.IsReady)
        {
            _status.Text = "Casa de marcat nu este legată. Apăsați „FP-700” și alegeți folderul Bonuri.";
            _status.Foreground = Brushes.Firebrick;
            return;
        }
        _printing = true;
        _print.IsEnabled = false;
        try
        {
            var lines = new List<string> { "Raport produse", _title.Text ?? "" };
            decimal grand = 0;
            foreach (var band in _rows.GroupBy(row => row.Group))
            {
                var group = band.ToList();
                var subtotal = group.Sum(row => row.Value);
                grand += subtotal;
                lines.Add(group[0].Group);
                foreach (var row in group)
                {
                    lines.Add(StockFormat.Text(row.Quantity) + " " + row.Unit + "  " + row.Code);
                    if (!string.IsNullOrWhiteSpace(row.Name))
                        lines.Add(row.Name);
                    lines.Add("Pret " + Money(row.Price) + "  Total " + Money(row.Value));
                }
                lines.Add("Subtotal " + Money(subtotal));
            }
            lines.Add("TOTAL " + Money(grand));
            var reply = await FiscalNetStation.SendAsync(FiscalNet.FileName("rp", true), FiscalNet.NonFiscal(lines, null), TimeSpan.FromSeconds(90));
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                if (reply.BonOk != 1)
                {
                    _status.Text = FiscalNet.Failure(reply, "Lista nu s-a listat.");
                    _status.Foreground = Brushes.Firebrick;
                }
                else
                {
                    _status.Text = "Lista a fost listată.";
                    _status.Foreground = Brand.Brush(Brand.Navy);
                }
            });
        }
        catch (Exception ex)
        {
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                _status.Text = ex.Message;
                _status.Foreground = Brushes.Firebrick;
            });
        }
        finally
        {
            _printing = false;
            await Dispatcher.UIThread.InvokeAsync(() => _print.IsEnabled = true);
        }
    }

    private static Control ProductLine(string code, string name, string unit, string quantity, string price, string total, bool header)
    {
        var line = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("110,*,70,110,110,130"),
            MinHeight = header ? 36 : 48,
            Margin = new Avalonia.Thickness(12, 0)
        };
        var weight = header ? FontWeight.Bold : FontWeight.SemiBold;
        var size = header ? 15.0 : 18.0;
        AddCell(line, code, 0, size, weight, header, false);
        AddCell(line, name, 1, size, weight, header, false);
        AddCell(line, unit, 2, size, weight, header, false);
        AddCell(line, quantity, 3, size, weight, header, true);
        AddCell(line, price, 4, size, weight, header, true);
        AddCell(line, total, 5, size, weight, header, true);
        return new Border
        {
            Background = header ? Brand.Brush(Brand.Navy) : Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(0, 0, 0, 1),
            Child = line,
            Padding = new Avalonia.Thickness(0, 6)
        };
    }

    private static Control Banner(string title, bool grand) => new Border
    {
        Background = Brand.Brush(Brand.Navy),
        Child = new TextBlock
        {
            Text = title,
            FontSize = 18,
            FontWeight = FontWeight.Bold,
            Foreground = Brushes.White,
            Margin = new Avalonia.Thickness(20, 10)
        }
    };

    private static Control Summary(string title, string amount, bool grand)
    {
        var line = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,130"),
            Margin = new Avalonia.Thickness(12, 0)
        };
        AddCell(line, title, 0, 18, FontWeight.Bold, grand, false);
        AddCell(line, amount, 1, 18, FontWeight.Bold, grand, true);
        return new Border
        {
            Background = grand ? Brand.Brush(Brand.Navy) : new SolidColorBrush(Color.FromRgb(236, 239, 244)),
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(0, 0, 0, 1),
            Child = line,
            Padding = new Avalonia.Thickness(0, 8)
        };
    }

    private static void AddCell(Grid line, string text, int column, double size, FontWeight weight, bool header, bool trailing)
    {
        var block = new TextBlock
        {
            Text = text,
            FontSize = size,
            FontWeight = weight,
            Foreground = header ? Brushes.White : Brand.Brush(Brand.Navy),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = trailing ? global::Avalonia.Layout.HorizontalAlignment.Right : global::Avalonia.Layout.HorizontalAlignment.Left,
            TextAlignment = trailing ? TextAlignment.Right : TextAlignment.Left,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Avalonia.Thickness(8, 0)
        };
        Grid.SetColumn(block, column);
        line.Children.Add(block);
    }

    private static TextBlock Message(string text, bool error) => new()
    {
        Text = text,
        FontSize = 18,
        TextWrapping = TextWrapping.Wrap,
        Margin = new Avalonia.Thickness(8, 16),
        Foreground = error ? Brushes.Firebrick : Brand.Brush(Brand.Navy)
    };

    private static Button ZButton(string label, Action action, bool open)
    {
        var button = new Button
        {
            Content = label,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Background = open ? Brand.Brush(Brand.Navy) : Brushes.White,
            Foreground = open ? Brushes.White : Brand.Brush(Brand.Navy),
            BorderBrush = Brand.Brush(Brand.Navy),
            BorderThickness = new Avalonia.Thickness(open ? 0 : 1),
            FontSize = 18,
            FontWeight = FontWeight.SemiBold,
            MinHeight = 64,
            Padding = new Avalonia.Thickness(18, 12),
            CornerRadius = new Avalonia.CornerRadius(12)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static Button BarButton(string title, bool filled, Action action)
    {
        var button = new Button
        {
            Content = title,
            Background = filled ? Brand.Brush(Brand.Navy) : Brushes.White,
            Foreground = filled ? Brushes.White : Brand.Brush(Brand.Navy),
            BorderBrush = Brand.Brush(Brand.Navy),
            BorderThickness = new Avalonia.Thickness(filled ? 0 : 1),
            FontSize = 18,
            FontWeight = FontWeight.SemiBold,
            Padding = new Avalonia.Thickness(22, 12),
            MinHeight = 52,
            CornerRadius = new Avalonia.CornerRadius(10)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static bool ReadGuid(JsonElement row, string name, out Guid id)
    {
        id = Guid.Empty;
        if (!row.TryGetProperty(name, out var value))
            return false;
        var text = value.ValueKind == JsonValueKind.String ? value.GetString() : value.ToString();
        return Guid.TryParse(text, out id);
    }

    private static string ShownDate(string iso, int shift)
    {
        var parts = iso.Split('-');
        if (parts.Length != 3 || !int.TryParse(parts[0], out var year) || !int.TryParse(parts[1], out var month) || !int.TryParse(parts[2], out var day))
            return iso;
        var date = new DateTime(year, month, day);
        if (shift == 2)
            date = date.AddDays(-1);
        return date.ToString("dd.MM.yyyy", CultureInfo.InvariantCulture);
    }

    private static decimal Number(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value))
            return 0;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number))
            return number;
        return decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : 0;
    }

    private static string Money(decimal value) =>
        value.ToString("0.00", CultureInfo.GetCultureInfo("ro-RO"));

    private static string Group(JsonElement row)
    {
        var name = Text(row, "grupa");
        return string.IsNullOrWhiteSpace(name) ? "Fără grupă" : name;
    }

    private static int Order(JsonElement row) =>
        row.TryGetProperty("grupa_ordine", out var value) && value.TryGetInt32(out var order) ? order : 100000;

    private static string Text(JsonElement row, string name) =>
        row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : "";

    private sealed record ProductRow(string Group, int Order, string Code, string Name, string Unit, decimal Quantity, decimal Price, decimal Value);
}
