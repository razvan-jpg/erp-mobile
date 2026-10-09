using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using ERPMobile.Services;
using ERPMobile.Services.Utilities;

namespace ERPMobile.Ui;

public sealed class UtilitiesHome : UserControl
{
    public UtilitiesHome(AppSession session)
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 10, MaxWidth = 640 };
        page.Children.Add(new TextBlock
        {
            Text = "Instrumente rapide pentru import Zetta, arhive MT940, stat NextUp din notă PDF și extragere Rapoarte Z.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        page.Children.Add(Tool("Creare fișier import ZETTA", "Scanează Z-uri (poze/PDF) și generează Excel pentru import Zetta.", () => Open(new ZettaImportWindow(session, copyOriginals: false))));
        page.Children.Add(Tool("Z-uri scanate → import Zetta", "Încarcă poze sau PDF-uri cu Rapoarte Z și creează fișierul de import.", () => Open(new ZettaImportWindow(session, copyOriginals: true))));
        page.Children.Add(Tool("Creare arhivă fișiere MT940", "Extrase bancă → fișiere MT940 zilnice arhivate ZIP.", () => Open(new Mt940Window(session))));
        page.Children.Add(Tool("Creare fișier import stat în NextUp din notă contabilă PDF", "Încarcă PDF-ul notei de salarii și generează Excel-ul NextUp.", () => Open(new PayrollWindow(session))));
        page.Children.Add(Tool("Extragere Rapoarte Z din Casa de Marcat", "Descarcă rapoartele Z din casa de marcat și le salvează PDF.", () => Pending(this, "Extragere Rapoarte Z", "Legătura cu casa de marcat (BINA) este încă doar în aplicația Mac. Pe Windows nu se conectează încă la casă.")));
        Content = new ScrollViewer { Content = page };
    }

    private Window? Window() => TopLevel.GetTopLevel(this) as Window;

    private void Open(Window window)
    {
        if (Window() is { } owner)
            window.Show(owner);
        else
            window.Show();
    }

    private static Button Tool(string title, string subtitle, Action open)
    {
        var stack = new StackPanel { Spacing = 2 };
        stack.Children.Add(new TextBlock { Text = title, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy), TextWrapping = TextWrapping.Wrap });
        stack.Children.Add(new TextBlock { Text = subtitle, Foreground = Brand.Brush(Brand.Muted), FontSize = 12, TextWrapping = TextWrapping.Wrap });
        var button = new Button
        {
            Content = stack,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Padding = new Avalonia.Thickness(14, 12),
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            CornerRadius = new Avalonia.CornerRadius(10)
        };
        button.Click += (_, _) => open();
        return button;
    }

    private static async void Pending(Control owner, string title, string message)
    {
        var window = new Window
        {
            Title = title,
            Width = 480,
            Height = 220,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Icon = Brand.WindowIcon(),
            Background = Brushes.White,
            Content = new TextBlock { Text = message, Margin = new Avalonia.Thickness(20), TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Navy) }
        };
        if (TopLevel.GetTopLevel(owner) is Window parent)
            await window.ShowDialog(parent);
        else
            window.Show();
    }
}

public sealed class Mt940Window : Window
{
    private readonly AppSession _session;
    private readonly List<(string Name, byte[] Data)> _files = [];
    private readonly TextBlock _filesText;
    private readonly TextBlock _status;

    public Mt940Window(AppSession session)
    {
        _session = session;
        Title = "Creare arhivă fișiere MT940";
        Width = 640;
        Height = 460;
        Icon = Brand.WindowIcon();
        Background = Brand.Brush(Brand.Page);
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        _filesText = new TextBlock { Text = "Niciun extras încărcat.", TextWrapping = TextWrapping.Wrap };
        _status = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) };
        var add = Action("Încarcă extrase", Pick);
        var save = Action("Generează și salvează", Generate);
        var root = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12 };
        root.Children.Add(new TextBlock
        {
            Text = "Acceptă PDF, CSV sau MT940 lunar și generează câte un fișier MT940 pe zi, plus arhiva ZIP.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        root.Children.Add(add);
        root.Children.Add(_filesText);
        root.Children.Add(save);
        root.Children.Add(_status);
        Content = root;
    }

    private async void Pick()
    {
        var storage = StorageProvider;
        if (storage == null)
            return;
        var picked = await storage.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Extrase bancare",
            AllowMultiple = true,
            FileTypeFilter =
            [
                new FilePickerFileType("Extrase") { Patterns = ["*.pdf", "*.csv", "*.txt", "*.sta", "*.940", "*.mt940"] }
            ]
        });
        foreach (var file in picked)
        {
            await using var stream = await file.OpenReadAsync();
            using var memory = new MemoryStream();
            await stream.CopyToAsync(memory);
            _files.Add((file.Name, memory.ToArray()));
        }
        _filesText.Text = _files.Count == 0 ? "Niciun extras încărcat." : string.Join("\n", _files.Select(file => file.Name));
        _status.Text = _files.Count + " fișier(e) încărcate.";
    }

    private async void Generate()
    {
        if (_files.Count == 0)
        {
            _status.Text = "Încărcați cel puțin un extras bancar.";
            return;
        }
        try
        {
            var company = _session.CurrentCompany?.Denumire ?? "";
            var daily = Mt940Engine.Build(_files, company);
            var storage = StorageProvider;
            if (storage == null)
                return;
            var folders = await storage.OpenFolderPickerAsync(new FolderPickerOpenOptions { Title = "Folder pentru fișierele MT940", AllowMultiple = false });
            var folder = folders.FirstOrDefault()?.TryGetLocalPath();
            if (string.IsNullOrEmpty(folder))
                return;
            var holder = company.Length == 0 ? "Firma" : company;
            Mt940Engine.Write(folder, Mt940Engine.ArchiveName(holder, daily), daily);
            _status.Foreground = Brushes.DarkGreen;
            _status.Text = "Salvate " + daily.Count + " fișiere MT940 zilnice și arhiva ZIP în " + folder + ".";
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private static Button Action(string text, Action action)
    {
        var button = new Button
        {
            Content = text,
            Padding = new Avalonia.Thickness(12, 8),
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        button.Click += (_, _) => action();
        return button;
    }
}

public sealed class PayrollWindow : Window
{
    private readonly AppSession _session;
    private byte[]? _pdf;
    private readonly TextBlock _fileText;
    private readonly TextBlock _status;
    private readonly ComboBox _style;
    private readonly TextBox _firstNumber;

    public PayrollWindow(AppSession session)
    {
        _session = session;
        Title = "Import stat NextUp din notă PDF";
        Width = 640;
        Height = 520;
        Icon = Brand.WindowIcon();
        Background = Brand.Brush(Brand.Page);
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        _fileText = new TextBlock { Text = "Niciun PDF încărcat.", TextWrapping = TextWrapping.Wrap };
        _status = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) };
        _style = new ComboBox
        {
            ItemsSource = new[] { "Simplă", "Sume strânse (4311)" },
            SelectedIndex = 0,
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        _firstNumber = new TextBox { Text = "1", Watermark = "ex. 1543" };
        var root = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12 };
        root.Children.Add(new TextBlock
        {
            Text = "Acceptă nota contabilă PDF din Saga. La % (un debit, mai multe credite) NextUp primește perechi 1:1.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        root.Children.Add(Action("Încarcă nota PDF", Pick));
        root.Children.Add(_fileText);
        root.Children.Add(new TextBlock { Text = "Tip notă contabilă", Foreground = Brand.Brush(Brand.Muted), FontSize = 12 });
        root.Children.Add(_style);
        root.Children.Add(new TextBlock { Text = "Nr. înregistrare începe de la", Foreground = Brand.Brush(Brand.Muted), FontSize = 12 });
        root.Children.Add(_firstNumber);
        root.Children.Add(Action("Citește și salvează Excel-ul", Generate));
        root.Children.Add(_status);
        Content = root;
    }

    private async void Pick()
    {
        var storage = StorageProvider;
        if (storage == null)
            return;
        var picked = await storage.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Notă contabilă PDF",
            AllowMultiple = false,
            FileTypeFilter = [new FilePickerFileType("PDF") { Patterns = ["*.pdf"] }]
        });
        var file = picked.FirstOrDefault();
        if (file == null)
            return;
        await using var stream = await file.OpenReadAsync();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory);
        _pdf = memory.ToArray();
        _fileText.Text = file.Name;
        _status.Text = "PDF încărcat.";
    }

    private async void Generate()
    {
        if (_pdf == null)
        {
            _status.Text = "Încărcați mai întâi PDF-ul notei contabile.";
            return;
        }
        if (!int.TryParse(_firstNumber.Text?.Trim(), out var first) || first < 1)
            first = 1;
        try
        {
            var style = _style.SelectedIndex == 1 ? PayrollNoteStyle.Collected : PayrollNoteStyle.Simple;
            var (lines, company) = PayrollNcEngine.Read(_pdf, first, style);
            var storage = StorageProvider;
            if (storage == null)
                return;
            var firm = company.Length > 0 ? company : _session.CurrentCompany?.Denumire ?? "Firma";
            var safe = string.Concat(firm.Select(ch => "/\\?%*|\"<>:".Contains(ch) ? '_' : ch)).Trim();
            if (safe.Length == 0)
                safe = "Firma";
            var suggested = "Salarii_" + safe.Replace(' ', '_') + ".xlsx";
            var saved = await storage.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Salvează Excel-ul de import",
                SuggestedFileName = suggested,
                DefaultExtension = "xlsx",
                FileTypeChoices = [new FilePickerFileType("Excel") { Patterns = ["*.xlsx"] }]
            });
            var path = saved?.TryGetLocalPath();
            if (string.IsNullOrEmpty(path))
                return;
            PayrollNcEngine.WriteXlsx(path, lines);
            _status.Foreground = Brushes.DarkGreen;
            _status.Text = "Citite " + lines.Count + " linii. Excel salvat: " + path;
        }
        catch (Exception ex)
        {
            _status.Foreground = Brushes.IndianRed;
            _status.Text = ex.Message;
        }
    }

    private static Button Action(string text, Action action)
    {
        var button = new Button
        {
            Content = text,
            Padding = new Avalonia.Thickness(12, 8),
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White
        };
        button.Click += (_, _) => action();
        return button;
    }
}
