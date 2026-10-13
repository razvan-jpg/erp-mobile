using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class SettingsHome : UserControl
{
    private readonly AppSession _session;
    private readonly Border _host = new();

    public SettingsHome(AppSession session)
    {
        _session = session;
        Content = _host;
        ShowMenu();
    }

    public void ShowMenu()
    {
        var profile = _session.Profile;
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 10, MaxWidth = 560 };
        page.Children.Add(new TextBlock { Text = "Contul meu", Foreground = Brand.Brush(Brand.Muted), FontSize = 12 });
        page.Children.Add(new TextBlock { Text = profile?.FullName ?? "", FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        page.Children.Add(new TextBlock { Text = profile?.Email ?? "", Foreground = Brand.Brush(Brand.Muted) });
        page.Children.Add(new TextBlock { Text = profile?.RoleLabel ?? "", Foreground = Brand.Brush(Brand.Muted), FontSize = 12, Margin = new Avalonia.Thickness(0, 0, 0, 8) });

        page.Children.Add(Row("Limba aplicației", LanguageName(profile?.PreferredLanguage), () => Show(new LanguageSettings(_session, this))));
        if (profile?.IsAdmin == true)
            page.Children.Add(Row("Utilizatori", "Conturi, permisiuni și blocare (doar administratori).", () => Show(new UsersSettings(_session, this))));
        if (_session.CurrentCompany != null)
        {
            page.Children.Add(Row("Sync offline", "Documente salvate fără internet și stare sync.", () => Show(new SyncSettings(_session, this))));
            page.Children.Add(Row("Setări Zetta", "Case de marcat, conturi casă și cote TVA pentru raportul Z.", () => Show(new ZettaSettingsScreen(_session, this))));
            page.Children.Add(Row("e-Factura (SPV)", "Invitație pe email către contabil. Data de valabilitate se citește din SPV.", () => Show(new EFacturaSettingsScreen(_session))));
        }
        page.Children.Add(Row("Adaugă scurtătură pe Desktop", "Creează scurtătura ERP Mobile pe Desktop.", CreateShortcut));
        if (profile?.IsSuperAdmin == true)
            page.Children.Add(Row("Administrare societăți", "Creați societăți și alocați drepturi (doar Superadmin).", () => Show(new CompaniesSettings(_session, this))));
        page.Children.Add(Row("Schimbă parola", "Parolă nouă pentru contul curent.", () => Show(new PasswordSettings(_session, this))));
        page.Children.Add(Row("Deconectare", "Închide sesiunea pe acest calculator.", async () => await _session.Logout(), destructive: true));
        if (_shortcutMessage.Length > 0)
        {
            page.Children.Add(new TextBlock
            {
                Text = _shortcutMessage,
                TextWrapping = TextWrapping.Wrap,
                Foreground = _shortcutOk ? Brushes.DarkGreen : Brushes.IndianRed,
                Margin = new Avalonia.Thickness(4, 4, 0, 0)
            });
        }
        _host.Child = new ScrollViewer { Content = page };
    }

    public void Show(Control page)
    {
        var root = new DockPanel();
        var back = new Button
        {
            Content = "← Setări",
            Margin = new Avalonia.Thickness(24, 16, 24, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brushes.White
        };
        ToolTip.SetTip(back, "Înapoi la Setări");
        back.Click += (_, _) => Dispatcher.UIThread.Post(ShowMenu);
        DockPanel.SetDock(back, Dock.Top);
        root.Children.Add(back);
        root.Children.Add(page);
        _host.Child = root;
    }

    private string _shortcutMessage = "";
    private bool _shortcutOk;

    private void CreateShortcut()
    {
        try
        {
            _shortcutOk = true;
            _shortcutMessage = DesktopShortcut.Create();
        }
        catch (Exception ex)
        {
            _shortcutOk = false;
            _shortcutMessage = ex.Message;
        }
        ShowMenu();
    }

    private static Control Row(string title, string subtitle, Action open, bool destructive = false)
    {
        var text = new StackPanel { Spacing = 2 };
        text.Children.Add(new TextBlock { Text = title, FontWeight = FontWeight.SemiBold, Foreground = destructive ? Brushes.IndianRed : Brand.Brush(Brand.Navy) });
        if (subtitle.Length > 0)
            text.Children.Add(new TextBlock { Text = subtitle, FontSize = 12, Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap });
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        grid.Children.Add(text);
        var chevron = new TextBlock { Text = ">", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Muted), Margin = new Avalonia.Thickness(12, 0, 0, 0) };
        Grid.SetColumn(chevron, 1);
        grid.Children.Add(chevron);
        var button = new Button
        {
            Content = grid,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Stretch,
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            CornerRadius = new Avalonia.CornerRadius(12),
            Padding = new Avalonia.Thickness(14, 12)
        };
        button.Click += (_, _) => Dispatcher.UIThread.Post(open);
        ToolTip.SetTip(button, string.IsNullOrWhiteSpace(subtitle) ? title : title + " — " + subtitle);
        return button;
    }

    public static string LanguageName(string? code) => code switch
    {
        "en" => "English",
        "fr" => "Français",
        "it" => "Italiano",
        "es" => "Español",
        "de" => "Deutsch",
        "pl" => "Polski",
        "cs" => "Čeština",
        "sr" => "Srpski",
        "hu" => "Magyar",
        "ru" => "Русский",
        "bg" => "Български",
        "tr" => "Türkçe",
        "ne" => "नेपाली",
        "ko" => "한국어",
        "zh-Hans" => "中文",
        "ja" => "日本語",
        "ar" => "العربية",
        "th" => "ไทย",
        "nl" => "Nederlands",
        _ => "Română"
    };
}
