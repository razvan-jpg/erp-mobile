using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Controls.Templates;
using Avalonia.Data;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using ERPMobile.Services;
using SkiaSharp;

namespace ERPMobile.Ui;

public sealed class ReorderNeedView : UserControl
{
    private readonly AppSession _session;
    private readonly ComboBox _warehouse = new() { MinWidth = 220 };
    private readonly DataGrid _grid = new() { AutoGenerateColumns = false, IsReadOnly = false, CanUserSortColumns = false };
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap };
    private readonly List<NeedLine> _lines = new();
    private bool _loading;

    public ReorderNeedView(AppSession session)
    {
        _session = session;
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Avalonia.Thickness(20, 12, 20, 0) };
        bar.Children.Add(new TextBlock { Text = "Gestiune", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        bar.Children.Add(_warehouse);
        var print = new Button { Content = "Tipărește", Padding = new Avalonia.Thickness(12, 6) };
        var export = new Button { Content = "Export PDF", Padding = new Avalonia.Thickness(12, 6), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White };
        print.Click += async (_, _) => await Print();
        export.Click += async (_, _) => await Export();
        var add = new Button { Content = "Adaugă articol", Padding = new Avalonia.Thickness(12, 6) };
        add.Click += async (_, _) => await ShowAdd();
        bar.Children.Add(print);
        bar.Children.Add(export);
        bar.Children.Add(add);
        _warehouse.SelectionChanged += async (_, _) =>
        {
            if (!_loading)
                await Load();
        };
        AddColumn("Categorie", nameof(NeedLine.Category), 150, true);
        AddColumn("Cod", nameof(NeedLine.Code), 90, true);
        AddColumn("Denumire", nameof(NeedLine.Name), 240, true);
        AddColumn("UM", nameof(NeedLine.Unit), 60, true);
        AddColumn("Stoc real", nameof(NeedLine.CurrentText), 90, true);
        AddColumn("Stoc minim", nameof(NeedLine.MinimumText), 90, true);
        AddColumn("Stoc optim", nameof(NeedLine.OptimalText), 90, true);
        _grid.Columns.Add(new DataGridTemplateColumn
        {
            Header = EditableHeader("De comandat"),
            Width = new DataGridLength(140),
            IsReadOnly = true,
            CellTemplate = new FuncDataTemplate<NeedLine>((line, _) =>
            {
                if (line == null)
                    return new TextBlock();
                var box = new TextBox
                {
                    Text = line.OrderText,
                    Padding = new Avalonia.Thickness(8, 4),
                    Background = new SolidColorBrush(Color.Parse("#FFF6E0")),
                    BorderBrush = Brand.Brush(Brand.Gold),
                    BorderThickness = new Avalonia.Thickness(1.5),
                    CornerRadius = new Avalonia.CornerRadius(6),
                    HorizontalAlignment = HorizontalAlignment.Stretch,
                    HorizontalContentAlignment = HorizontalAlignment.Right,
                    FontWeight = FontWeight.SemiBold
                };
                ToolTip.SetTip(box, "Se poate modifica");
                box.TextChanged += (_, _) => line.OrderText = box.Text ?? "";
                box.LostFocus += (_, _) => box.Text = line.OrderText;
                return box;
            })
        });
        _grid.Columns.Add(new DataGridTemplateColumn
        {
            Header = " ",
            Width = new DataGridLength(48),
            CellTemplate = new FuncDataTemplate<NeedLine>((line, _) =>
            {
                var button = new Button
                {
                    Content = "🗑",
                    Background = Brushes.Transparent,
                    Foreground = Brushes.Firebrick,
                    BorderThickness = new Avalonia.Thickness(0)
                };
                button.Click += (_, _) =>
                {
                    if (line == null)
                        return;
                    _lines.Remove(line);
                    Rebind();
                };
                return button;
            })
        });
        _grid.ItemsSource = _lines;
        var root = new DockPanel();
        DockPanel.SetDock(bar, Dock.Top);
        DockPanel.SetDock(_status, Dock.Top);
        _status.Margin = new Avalonia.Thickness(20, 8, 20, 8);
        root.Children.Add(bar);
        root.Children.Add(_status);
        root.Children.Add(_grid);
        Content = root;
        _ = Load();
    }

    private static StackPanel EditableHeader(string title)
    {
        var header = new StackPanel { Spacing = 0 };
        header.Children.Add(new TextBlock { Text = title, FontWeight = FontWeight.SemiBold });
        header.Children.Add(new TextBlock { Text = "se modifică", FontSize = 11, Foreground = Brand.Brush(Brand.Gold) });
        return header;
    }

    private void AddColumn(string header, string binding, double width, bool readOnly)
    {
        _grid.Columns.Add(new DataGridTextColumn
        {
            Header = header,
            Binding = new Binding(binding) { Mode = readOnly ? BindingMode.OneWay : BindingMode.TwoWay },
            Width = new DataGridLength(width),
            IsReadOnly = readOnly
        });
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
        try
        {
            var company = _session.CurrentCompany.Id;
            if (_warehouse.Items.Count == 0)
            {
                _warehouse.Items.Add(new WarehouseChoice(null, "Toate gestiunile"));
                var warehouses = await Pages("company_warehouses", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
                foreach (var row in warehouses)
                {
                    if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var guid))
                        continue;
                    _warehouse.Items.Add(new WarehouseChoice(guid, Text(row, "denumire")));
                }
                _warehouse.SelectedIndex = 0;
            }
            var selected = _warehouse.SelectedItem as WarehouseChoice;
            var products = await Pages(
                "products",
                $"company_id=eq.{company}&is_active=eq.true&tip=not.in.(produs_finit,birotica)&cantitate_minima=gt.0&select=id,denumire,cod,unitate_masura,tip,cantitate_minima,cantitate_optima&order=denumire.asc");
            var stockQuery = selected?.Id is Guid warehouseId
                ? $"company_id=eq.{company}&warehouse_id=eq.{warehouseId}&select=product_id,cantitate"
                : $"company_id=eq.{company}&select=product_id,cantitate";
            var stockTable = selected?.Id == null ? "product_stocks" : "warehouse_product_stocks";
            var stock = await Pages(stockTable, stockQuery);
            var quantities = new Dictionary<Guid, decimal>();
            foreach (var row in stock)
            {
                if (row.TryGetProperty("product_id", out var id) && id.TryGetGuid(out var productId))
                    quantities[productId] = Number(row, "cantitate");
            }
            _lines.Clear();
            foreach (var row in products)
            {
                if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var productId))
                    continue;
                var minimum = Number(row, "cantitate_minima");
                var current = quantities.TryGetValue(productId, out var qty) ? qty : 0;
                if (current >= minimum)
                    continue;
                var kind = Text(row, "tip");
                if (kind == "birotica")
                    continue;
                var optimal = Number(row, "cantitate_optima");
                var order = Math.Max(0, optimal - current);
                _lines.Add(new NeedLine(productId, Text(row, "cod"), Text(row, "denumire"), Text(row, "unitate_masura"), kind, current, minimum, optimal, order));
            }
            SortLines();
            Rebind();
            _status.Text = _lines.Count == 0
                ? "Nu există articole cu stocul sub minim. Puteți adăuga articole, inclusiv birotică."
                : "Lista e pe categorii. De comandat se poate modifica. " + _lines.Count + " articole.";
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

    private async Task<List<JsonElement>> Pages(string table, string query)
    {
        var rows = new List<JsonElement>();
        var from = 0;
        while (true)
        {
            var page = await _session.SelectRows(table, query, from, from + 999);
            if (page.ValueKind != JsonValueKind.Array || page.GetArrayLength() == 0)
                break;
            foreach (var row in page.EnumerateArray())
                rows.Add(row);
            if (page.GetArrayLength() < 1000)
                break;
            from += 1000;
        }
        return rows;
    }

    private void SortLines()
    {
        _lines.Sort((left, right) =>
        {
            var rank = left.CategoryRank.CompareTo(right.CategoryRank);
            return rank != 0 ? rank : string.Compare(left.Name, right.Name, StringComparison.CurrentCultureIgnoreCase);
        });
    }

    private void Rebind()
    {
        _grid.ItemsSource = null;
        _grid.ItemsSource = _lines;
    }

    private async Task ShowAdd()
    {
        if (_session.CurrentCompany == null)
            return;
        var company = _session.CurrentCompany.Id;
        var selected = _warehouse.SelectedItem as WarehouseChoice;
        var window = new Window
        {
            Title = "Adaugă articol",
            Width = 560,
            Height = 520,
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var search = new TextBox { Watermark = "Denumire sau cod", Margin = new Avalonia.Thickness(12) };
        var list = new ListBox { Margin = new Avalonia.Thickness(12, 0, 12, 12) };
        var add = new Button { Content = "Adaugă în listă", Margin = new Avalonia.Thickness(12), HorizontalAlignment = HorizontalAlignment.Left, IsEnabled = false };
        var hits = new List<NeedLine>();
        var generation = 0;
        list.SelectionChanged += (_, _) => add.IsEnabled = list.SelectedItem is NeedLine;
        search.TextChanged += async (_, _) =>
        {
            var token = ++generation;
            var term = new string((search.Text ?? "").Where(ch => char.IsLetterOrDigit(ch) || ch == ' ' || ch == '-').ToArray()).Trim();
            if (term.Length < 1)
            {
                hits.Clear();
                list.ItemsSource = null;
                return;
            }
            await Task.Delay(250);
            if (token != generation)
                return;
            try
            {
                var encoded = Uri.EscapeDataString(term);
                var found = await _session.SelectRows(
                    "products",
                    $"company_id=eq.{company}&is_active=eq.true&tip=neq.produs_finit&or=(denumire.ilike.*{encoded}*,cod.ilike.*{encoded}*)&select=id,denumire,cod,unitate_masura,tip,cantitate_minima,cantitate_optima&order=denumire.asc",
                    0,
                    39);
                if (token != generation || found.ValueKind != JsonValueKind.Array)
                    return;
                var ids = new List<Guid>();
                foreach (var row in found.EnumerateArray())
                {
                    if (row.TryGetProperty("id", out var id) && id.TryGetGuid(out var productId))
                        ids.Add(productId);
                }
                var quantities = new Dictionary<Guid, decimal>();
                if (ids.Count > 0)
                {
                    var stockFilter = selected?.Id is Guid warehouseId
                        ? $"company_id=eq.{company}&warehouse_id=eq.{warehouseId}&product_id=in.({string.Join(",", ids)})&select=product_id,cantitate"
                        : $"company_id=eq.{company}&product_id=in.({string.Join(",", ids)})&select=product_id,cantitate";
                    var stockTable = selected?.Id == null ? "product_stocks" : "warehouse_product_stocks";
                    var stock = await _session.SelectRows(stockTable, stockFilter, 0, 999);
                    if (stock.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var row in stock.EnumerateArray())
                        {
                            if (row.TryGetProperty("product_id", out var id) && id.TryGetGuid(out var productId))
                                quantities[productId] = Number(row, "cantitate");
                        }
                    }
                }
                hits.Clear();
                foreach (var row in found.EnumerateArray())
                {
                    if (!row.TryGetProperty("id", out var id) || !id.TryGetGuid(out var productId))
                        continue;
                    if (_lines.Any(line => line.ProductId == productId))
                        continue;
                    var current = quantities.TryGetValue(productId, out var qty) ? qty : 0;
                    var optimal = Number(row, "cantitate_optima");
                    hits.Add(new NeedLine(productId, Text(row, "cod"), Text(row, "denumire"), Text(row, "unitate_masura"), Text(row, "tip"), current, Number(row, "cantitate_minima"), optimal, Math.Max(0, optimal - current)));
                }
                hits.Sort((left, right) =>
                {
                    var rank = left.CategoryRank.CompareTo(right.CategoryRank);
                    return rank != 0 ? rank : string.Compare(left.Name, right.Name, StringComparison.CurrentCultureIgnoreCase);
                });
                list.ItemsSource = null;
                list.ItemsSource = hits;
            }
            catch (Exception ex)
            {
                _status.Text = ex.Message;
                _status.Foreground = Brushes.Firebrick;
            }
        };
        add.Click += (_, _) =>
        {
            if (list.SelectedItem is NeedLine line && _lines.All(existing => existing.ProductId != line.ProductId))
            {
                _lines.Add(line);
                SortLines();
                Rebind();
                _status.Text = "Articol adăugat. Cantitatea de comandat se poate modifica.";
                _status.Foreground = Brand.Brush(Brand.Muted);
            }
            window.Close();
        };
        var root = new DockPanel();
        DockPanel.SetDock(search, Dock.Top);
        DockPanel.SetDock(add, Dock.Bottom);
        root.Children.Add(search);
        root.Children.Add(add);
        root.Children.Add(list);
        window.Content = root;
        if (TopLevel.GetTopLevel(this) is Window owner)
            await window.ShowDialog(owner);
        else
            window.Show();
    }

    private async Task Export()
    {
        if (_lines.Count == 0)
            return;
        var storage = TopLevel.GetTopLevel(this)?.StorageProvider;
        if (storage == null)
            return;
        var saved = await storage.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "Salvează necesarul de comandă",
            SuggestedFileName = "Necesar-comanda.pdf",
            DefaultExtension = "pdf",
            FileTypeChoices = [new FilePickerFileType("PDF") { Patterns = ["*.pdf"] }]
        });
        var path = saved?.TryGetLocalPath();
        if (string.IsNullOrEmpty(path))
            return;
        await File.WriteAllBytesAsync(path, Pdf());
        _status.Text = "PDF salvat.";
        _status.Foreground = Brand.Brush(Brand.Muted);
    }

    private async Task Print()
    {
        if (_lines.Count == 0)
            return;
        var path = Path.Combine(Path.GetTempPath(), "Necesar-comanda.pdf");
        await File.WriteAllBytesAsync(path, Pdf());
        if (!OperatingSystem.IsWindows())
        {
            _status.Text = "Tipărirea este disponibilă pe Windows. PDF-ul este salvat temporar.";
            return;
        }
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

    private byte[] Pdf()
    {
        var warehouse = (_warehouse.SelectedItem as WarehouseChoice)?.Name ?? "Toate gestiunile";
        return ReorderNeedPdf.Make(_session.CurrentCompany?.Denumire ?? "Societate", warehouse, _lines);
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

    private sealed record WarehouseChoice(Guid? Id, string Name)
    {
        public override string ToString() => Name;
    }

    public sealed class NeedLine
    {
        public NeedLine(Guid productId, string code, string name, string unit, string kind, decimal current, decimal minimum, decimal optimal, decimal order)
        {
            ProductId = productId;
            Code = code;
            Name = name;
            Unit = unit;
            Kind = kind;
            Current = current;
            Minimum = minimum;
            Optimal = optimal;
            Order = order;
        }

        public Guid ProductId { get; }
        public string Code { get; }
        public string Name { get; }
        public string Unit { get; }
        public string Kind { get; }
        public string Category => CategoryName(Kind);
        public int CategoryRank => CategoryOrder(Kind);
        public decimal Current { get; }
        public decimal Minimum { get; }
        public decimal Optimal { get; }
        public decimal Order { get; set; }
        public string CurrentText => Amount(Current);
        public string MinimumText => Amount(Minimum);
        public string OptimalText => Amount(Optimal);
        public string OrderText
        {
            get => Amount(Order);
            set
            {
                var text = (value ?? "").Trim().Replace(" ", "");
                if (decimal.TryParse(text, NumberStyles.Number, CultureInfo.GetCultureInfo("ro-RO"), out var parsed)
                    || decimal.TryParse(text.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out parsed))
                    Order = Math.Max(0, parsed);
            }
        }

        public override string ToString() => Category + " · " + Name + (string.IsNullOrEmpty(Code) ? "" : " · " + Code);

        private static string Amount(decimal value) => value.ToString("0.####", CultureInfo.GetCultureInfo("ro-RO"));

        private static int CategoryOrder(string kind)
        {
            var order = new[]
            {
                "marfa", "materie_prima", "ambalaj", "materiale_consumabile", "materiale_curatenie",
                "birotica", "servicii", "garantie", "obiect_inventar"
            };
            var index = Array.IndexOf(order, kind);
            return index < 0 ? order.Length : index;
        }

        private static string CategoryName(string kind) => kind switch
        {
            "marfa" => "Marfa",
            "materie_prima" => "Materie prima",
            "produs_finit" => "Produs finit",
            "ambalaj" => "Ambalaj",
            "materiale_consumabile" => "Materiale consumabile",
            "materiale_curatenie" => "Materiale curatenie",
            "birotica" => "Birotica",
            "servicii" => "Servicii",
            "garantie" => "Garantie",
            "obiect_inventar" => "Obiect de inventar",
            _ => kind
        };
    }
}

static class ReorderNeedPdf
{
    public static byte[] Make(string company, string warehouse, IReadOnlyList<ReorderNeedView.NeedLine> lines)
    {
        using var stream = new MemoryStream();
        using var document = SKDocument.CreatePdf(stream);
        var typeface = SKTypeface.FromFamilyName("Segoe UI") ?? SKTypeface.Default;
        var bold = SKTypeface.FromFamilyName("Segoe UI", SKFontStyle.Bold) ?? typeface;
        using var title = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 16, Typeface = bold };
        using var body = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 9, Typeface = typeface };
        using var head = new SKPaint { Color = SKColors.Black, IsAntialias = true, TextSize = 9, Typeface = bold };
        using var linePaint = new SKPaint { Color = SKColors.LightGray, StrokeWidth = 0.6f, IsStroke = true };
        const float width = 595;
        const float height = 842;
        const float margin = 36;
        var headers = new[] { "Cod", "Denumire", "UM", "Stoc real", "Minim", "Optim", "De comandat" };
        var widths = new[] { 70f, 150f, 40f, 65f, 60f, 60f, 75f };
        var page = 0;
        var index = 0;
        while (index < lines.Count || page == 0)
        {
            page++;
            var canvas = document.BeginPage(width, height);
            canvas.Clear(SKColors.White);
            float y = margin;
            canvas.DrawText(company, margin, y, title);
            y += 22;
            canvas.DrawText("Necesar comandă · " + warehouse, margin, y, body);
            y += 16;
            canvas.DrawText(DateTime.Now.ToString("dd.MM.yyyy HH:mm"), margin, y, body);
            y += 16;
            DrawRow(canvas, headers, widths, margin, y, head);
            y += 16;
            var lastCategory = "";
            while (index < lines.Count && y < height - 48)
            {
                var line = lines[index];
                if (line.Category != lastCategory)
                {
                    if (y > height - 70)
                        break;
                    canvas.DrawText(line.Category, margin, y, head);
                    y += 14;
                    lastCategory = line.Category;
                }
                DrawRow(canvas, new[] { line.Code, line.Name, line.Unit, line.CurrentText, line.MinimumText, line.OptimalText, line.OrderText }, widths, margin, y, body);
                canvas.DrawLine(margin, y + 4, margin + widths.Sum(), y + 4, linePaint);
                y += 14;
                index++;
            }
            canvas.DrawText("pag. " + page + "  ·  Document generat cu ERP Mobile by DateConta", margin, height - 24, body);
            document.EndPage();
            if (index >= lines.Count)
                break;
        }
        document.Close();
        return stream.ToArray();
    }

    private static void DrawRow(SKCanvas canvas, string[] values, float[] widths, float x, float y, SKPaint paint)
    {
        var cursor = x;
        for (var i = 0; i < values.Length; i++)
        {
            var text = values[i] ?? "";
            if (text.Length > 42)
                text = text[..39] + "...";
            canvas.DrawText(text, cursor, y, paint);
            cursor += widths[i];
        }
    }
}
