using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using ERPMobile.Services;
using ERPMobile.Services.Utilities;

namespace ERPMobile.Ui;

public sealed class ZettaImportWindow : Window
{
    private readonly AppSession _session;
    private readonly bool _copyOriginals;
    private readonly List<(string Name, byte[] Data)> _files = [];
    private readonly List<ZReportDraft> _reports = [];
    private readonly List<Card> _cards = [];
    private readonly TextBox _firstNumber = new() { Text = "1", Width = 80 };
    private readonly TextBlock _status;
    private readonly StackPanel _list = new() { Spacing = 10 };
    private ZettaLedger _ledger = new();

    public ZettaImportWindow(AppSession session, bool copyOriginals)
    {
        _session = session;
        _copyOriginals = copyOriginals;
        Title = copyOriginals ? "Z-uri scanate → import Zetta" : "Creare fișier import ZETTA";
        Width = 980;
        Height = 760;
        Icon = Brand.WindowIcon();
        Background = Brand.Brush(Brand.Page);
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        _status = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) };

        var load = Action("Încarcă PDF sau poze", Pick);
        var add = Action("Adaugă Z manual", AddEmpty);
        var save = Action(_copyOriginals ? "Salvează Excel și copiile" : "Salvează Excel Zetta", Save);
        var header = new StackPanel { Spacing = 8 };
        header.Children.Add(new TextBlock
        {
            Text = copyOriginals
                ? "O pagină sau o poză este un Raport Z. Numărul de mai jos devine Nr. înreg. pentru primul Z, apoi continuă. Excel-ul se salvează pe firmă, iar fișierele originale se copiază în același folder."
                : "Încărcați PDF-urile sau pozele Raport Z, corectați sumele, apoi salvați Excel-ul de notă contabilă. Dacă societatea are Setări Zetta, conturile din Excel vin de acolo.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        var numberRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        numberRow.Children.Add(new TextBlock { Text = "Nr. înreg. primului Z", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        numberRow.Children.Add(_firstNumber);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        buttons.Children.Add(load);
        buttons.Children.Add(add);
        buttons.Children.Add(save);
        header.Children.Add(numberRow);
        header.Children.Add(buttons);
        header.Children.Add(_status);

        var root = new DockPanel { Margin = new Avalonia.Thickness(16) };
        DockPanel.SetDock(header, Dock.Top);
        root.Children.Add(header);
        root.Children.Add(new ScrollViewer { Content = _list });
        Content = root;
        Opened += async (_, _) => await LoadLedger();
    }

    private async Task LoadLedger()
    {
        try
        {
            _ledger = await ZettaImportEngine.LoadLedger(_session);
            _status.Text = _ledger.HasSettings
                ? "Setările Zetta ale societății active se folosesc la conturi."
                : "Nu există setări Zetta salvate. Excel-ul folosește conturile standard (707 / 701 / 5311 / 5125 / 5113).";
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
    }

    private async void Pick()
    {
        var storage = StorageProvider;
        if (storage == null)
            return;
        var picked = await storage.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Rapoarte Z",
            AllowMultiple = true,
            FileTypeFilter =
            [
                new FilePickerFileType("PDF sau poze") { Patterns = ["*.pdf", "*.png", "*.jpg", "*.jpeg", "*.tif", "*.tiff", "*.bmp", "*.txt"] }
            ]
        });
        Sync();
        var notes = new List<string>();
        foreach (var file in picked)
        {
            await using var stream = await file.OpenReadAsync();
            using var memory = new MemoryStream();
            await stream.CopyToAsync(memory);
            var data = memory.ToArray();
            _files.Add((file.Name, data));
            var parsed = ZettaImportEngine.Read(file.Name, data, out var warning);
            if (warning.Length > 0)
                notes.Add(warning);
            if (parsed.Count == 0)
                _reports.Add(new ZReportDraft { Source = file.Name, Firma = _ledger.CompanyName, Cui = _ledger.CompanyCui, Note = "Completați acest Z manual." });
            else
            {
                foreach (var report in parsed)
                {
                    if (string.IsNullOrWhiteSpace(report.Firma))
                        report.Firma = _ledger.CompanyName;
                    if (string.IsNullOrWhiteSpace(report.Cui))
                        report.Cui = _ledger.CompanyCui;
                }
                _reports.AddRange(parsed);
            }
        }
        Rebuild();
        if (notes.Count > 0)
            _status.Text = string.Join(" ", notes);
        else if (_reports.Count > 0)
            _status.Text = _reports.Count + " Rapoarte Z citite. Verificați sumele, apoi salvați.";
    }

    private void AddEmpty()
    {
        Sync();
        _reports.Add(new ZReportDraft { Source = "Manual", Firma = _ledger.CompanyName, Cui = _ledger.CompanyCui });
        Rebuild();
    }

    private async void Save()
    {
        Sync();
        if (_reports.Count == 0)
        {
            _status.Text = "Încărcați cel puțin un Raport Z.";
            return;
        }
        if (!int.TryParse(_firstNumber.Text?.Trim(), out var first) || first < 1)
        {
            _status.Text = "Nr. înreg. trebuie să fie un număr de la 1 în sus.";
            return;
        }
        var missing = _reports.Where(report => report.ZNumber <= 0).Select(report => report.Source).ToList();
        if (missing.Count > 0)
        {
            _status.Text = "Completați numărul Z pentru: " + string.Join(", ", missing) + ".";
            return;
        }
        try
        {
            var built = ZettaImportEngine.Build(_reports, first, _ledger);
            if (built.Count == 0)
            {
                _status.Text = "Nu există sume de scris în Excel. Completați totalul, cotele sau încasările.";
                return;
            }
            var storage = StorageProvider;
            if (storage == null)
                return;
            var folders = await storage.OpenFolderPickerAsync(new FolderPickerOpenOptions { Title = "Folder pentru Excel Zetta", AllowMultiple = false });
            var folder = folders.FirstOrDefault()?.TryGetLocalPath();
            if (string.IsNullOrEmpty(folder))
                return;
            foreach (var (name, rows) in built)
                ZettaImportEngine.WriteXlsx(Path.Combine(folder, name), rows);
            if (_copyOriginals)
            {
                foreach (var (name, data) in _files)
                {
                    var target = Path.Combine(folder, name);
                    if (!File.Exists(target))
                        await File.WriteAllBytesAsync(target, data);
                }
            }
            _status.Foreground = Brushes.DarkGreen;
            _status.Text = "Salvat în " + folder + ": " + string.Join(", ", built.Select(file => file.FileName)) + ".";
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private void Sync()
    {
        foreach (var card in _cards)
            card.WriteBack();
    }

    private void Rebuild()
    {
        _cards.Clear();
        _list.Children.Clear();
        foreach (var report in _reports)
        {
            var card = new Card(report);
            _cards.Add(card);
            _list.Children.Add(card.View);
        }
    }

    private static Button Action(string text, Action action)
    {
        var button = new Button
        {
            Content = text,
            Padding = new Avalonia.Thickness(12, 8),
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        button.Click += (_, _) => action();
        return button;
    }

    private sealed class Card
    {
        private readonly ZReportDraft _report;
        private readonly Dictionary<string, TextBox> _fields = new();

        public Card(ZReportDraft report)
        {
            _report = report;
            var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,*,*,*"), RowDefinitions = new RowDefinitions("Auto,Auto,Auto,Auto,Auto") };
            Add(grid, 0, 0, "Sursă", report.Source, "source", readOnly: true);
            Add(grid, 1, 0, "Firmă", report.Firma, "firma");
            Add(grid, 2, 0, "CUI", report.Cui, "cui");
            Add(grid, 3, 0, "Locație", report.Locatie, "locatie");
            Add(grid, 0, 1, "Nr. Z", report.ZNumber == 0 ? "" : report.ZNumber.ToString(), "z");
            Add(grid, 1, 1, "Data", report.Date.ToString("dd.MM.yyyy"), "date");
            Add(grid, 2, 1, "Total vânzări", ZettaImportEngine.MoneyText(report.Total), "total");
            Add(grid, 3, 1, "Scutit / 0%", ZettaImportEngine.MoneyText(report.Vanzari0), "zero");
            Add(grid, 0, 2, "Brut 21% (A)", ZettaImportEngine.MoneyText(report.Vanzari21), "a");
            Add(grid, 1, 2, "TVA 21%", ZettaImportEngine.MoneyText(report.Tva21), "tvaa");
            Add(grid, 2, 2, "Brut 11% (B)", ZettaImportEngine.MoneyText(report.Vanzari11), "b");
            Add(grid, 3, 2, "TVA 11%", ZettaImportEngine.MoneyText(report.Tva11), "tvab");
            Add(grid, 0, 3, "Brut C", ZettaImportEngine.MoneyText(report.Vanzari11C), "c");
            Add(grid, 1, 3, "TVA C", ZettaImportEngine.MoneyText(report.Tva11C), "tvac");
            Add(grid, 2, 3, "Numerar", ZettaImportEngine.MoneyText(report.Numerar), "cash");
            Add(grid, 3, 3, "Card", ZettaImportEngine.MoneyText(report.Card), "card");
            Add(grid, 0, 4, "Plată modernă", ZettaImportEngine.MoneyText(report.PlataModerna), "modern");
            var stack = new StackPanel { Spacing = 6 };
            stack.Children.Add(grid);
            if (report.Note.Length > 0)
                stack.Children.Add(new TextBlock { Text = report.Note, Foreground = Brushes.DarkOrange, TextWrapping = TextWrapping.Wrap, FontSize = 12 });
            View = new Border
            {
                Background = Brushes.White,
                BorderBrush = Brand.Brush(Brand.Line),
                BorderThickness = new Avalonia.Thickness(1),
                CornerRadius = new Avalonia.CornerRadius(10),
                Padding = new Avalonia.Thickness(12),
                Child = stack
            };
        }

        public Control View { get; }

        public void WriteBack()
        {
            _report.Firma = Value("firma");
            _report.Cui = Value("cui");
            _report.Locatie = Value("locatie");
            _report.ZNumber = int.TryParse(Value("z"), out var z) ? z : 0;
            _report.Date = DateTime.TryParseExact(Value("date"), "dd.MM.yyyy", null, System.Globalization.DateTimeStyles.None, out var date) ? date : _report.Date;
            _report.Total = ZettaImportEngine.ParseMoney(Value("total"));
            _report.Vanzari0 = ZettaImportEngine.ParseMoney(Value("zero"));
            _report.Vanzari21 = ZettaImportEngine.ParseMoney(Value("a"));
            _report.Tva21 = ZettaImportEngine.ParseMoney(Value("tvaa"));
            _report.Vanzari11 = ZettaImportEngine.ParseMoney(Value("b"));
            _report.Tva11 = ZettaImportEngine.ParseMoney(Value("tvab"));
            _report.Vanzari11C = ZettaImportEngine.ParseMoney(Value("c"));
            _report.Tva11C = ZettaImportEngine.ParseMoney(Value("tvac"));
            _report.Numerar = ZettaImportEngine.ParseMoney(Value("cash"));
            _report.Card = ZettaImportEngine.ParseMoney(Value("card"));
            _report.PlataModerna = ZettaImportEngine.ParseMoney(Value("modern"));
        }

        private void Add(Grid grid, int column, int row, string label, string value, string key, bool readOnly = false)
        {
            var box = new TextBox { Text = value, IsReadOnly = readOnly };
            _fields[key] = box;
            var stack = new StackPanel { Spacing = 2, Margin = new Avalonia.Thickness(0, 0, 8, 6) };
            stack.Children.Add(new TextBlock { Text = label, FontSize = 11, Foreground = Brand.Brush(Brand.Muted) });
            stack.Children.Add(box);
            Grid.SetColumn(stack, column);
            Grid.SetRow(stack, row);
            grid.Children.Add(stack);
        }

        private string Value(string key) => _fields[key].Text?.Trim() ?? "";
    }
}
