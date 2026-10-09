using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Data;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class ShellWindow : Window
{
    private readonly AppSession _session = new();
    private readonly LaunchSplash _splash = new();
    private bool _showingSplash = true;
    private string _section = "home";
    private AppModule? _module;
    private CasierHome? _cashier;
    private Control? _pos;
    private string _email = "";
    private bool _rendering;

    public ShellWindow()
    {
        Title = "ERP Mobile";
        Width = 1280;
        Height = 820;
        MinWidth = 980;
        MinHeight = 640;
        Icon = Brand.WindowIcon();
        Background = Brand.Brush(Brand.Page);
        SystemDecorations = SystemDecorations.None;
        CanResize = false;
        ShowInTaskbar = false;
        Topmost = true;
        WindowStartupLocation = WindowStartupLocation.Manual;
        _session.Changed += () => Dispatcher.UIThread.Post(Render);
        Opened += async (_, _) =>
        {
            CoverScreen();
            if (OperatingSystem.IsWindows())
                WindowsKiosk.Install();
            var boot = _session.Bootstrap();
            _splash.Start();
            await _splash.Finished;
            try
            {
                await boot;
            }
            catch (Exception)
            {
            }
            OfflineSync.Start(_session);
            _showingSplash = false;
            Render();
        };
        Closed += (_, _) =>
        {
            if (OperatingSystem.IsWindows())
                WindowsKiosk.Remove();
        };
        Content = _splash;
    }

    private void CoverScreen()
    {
        var screen = Screens?.Primary;
        if (screen == null)
            return;
        WindowState = WindowState.Normal;
        Position = screen.Bounds.Position;
        Width = screen.Bounds.Width / screen.Scaling;
        Height = screen.Bounds.Height / screen.Scaling;
    }

    private void Render()
    {
        if (_showingSplash || _rendering)
            return;
        _rendering = true;
        try
        {
            Content = _session.State switch
            {
                SessionState.Loading => Center("Se încarcă..."),
                SessionState.ConfigError => Center(_session.Error ?? "Configurați credențialele Supabase înainte de utilizare."),
                SessionState.Blocked => Center(_session.Error ?? "Contul dvs. este blocat. Contactați administratorul."),
                SessionState.Login => LoginView(),
                _ => Shell()
            };
        }
        finally
        {
            _rendering = false;
        }
    }

    private Control Center(string message)
    {
        var panel = new StackPanel { Spacing = 16, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, MaxWidth = 460 };
        panel.Children.Add(new Image { Source = Brand.Icon, Width = 88, Height = 88, HorizontalAlignment = HorizontalAlignment.Center });
        panel.Children.Add(new TextBlock { Text = "ERP Mobile", FontSize = 28, FontWeight = FontWeight.Bold, Foreground = Brand.Brush(Brand.Navy), HorizontalAlignment = HorizontalAlignment.Center });
        panel.Children.Add(new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, TextAlignment = TextAlignment.Center, Foreground = Brand.Brush(Brand.Muted) });
        return panel;
    }

    private Control LoginView()
    {
        var card = new Border
        {
            Background = Brushes.White,
            CornerRadius = new Avalonia.CornerRadius(16),
            Padding = new Avalonia.Thickness(32),
            Width = 420,
            BoxShadow = BoxShadows.Parse("0 8 24 0 #14000000")
        };
        var stack = new StackPanel { Spacing = 14 };
        stack.Children.Add(new Image { Source = Brand.Icon, Width = 72, Height = 72, HorizontalAlignment = HorizontalAlignment.Center });
        stack.Children.Add(new TextBlock { Text = "ERP Mobile", FontSize = 26, FontWeight = FontWeight.Bold, HorizontalAlignment = HorizontalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        stack.Children.Add(new TextBlock { Text = "Dateconta", HorizontalAlignment = HorizontalAlignment.Center, Foreground = Brand.Brush(Brand.Muted) });
        if (string.IsNullOrWhiteSpace(_email))
            _email = _session.RememberedEmail;
        var email = new TextBox { Watermark = "Email", Text = _email };
        var password = new TextBox { Watermark = "Parolă", PasswordChar = '•' };
        email.TextChanged += (_, _) => _email = email.Text ?? "";
        stack.Children.Add(email);
        stack.Children.Add(password);
        if (!string.IsNullOrWhiteSpace(_session.Error))
            stack.Children.Add(new TextBlock { Text = _session.Error, Foreground = Brushes.IndianRed, TextWrapping = TextWrapping.Wrap });
        var button = new Button
        {
            Content = _session.IsBusy ? "Se autentifică..." : "Autentificare",
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            Padding = new Avalonia.Thickness(12, 10),
            Background = Brand.Brush(Brand.Gold),
            Foreground = Brushes.White,
            CornerRadius = new Avalonia.CornerRadius(8),
            IsEnabled = !_session.IsBusy
        };
        button.Click += async (_, _) => await _session.Login(email.Text ?? "", password.Text ?? "");
        stack.Children.Add(button);
        card.Child = stack;
        return new Border { Child = card, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
    }

    private Control Shell()
    {
        if (_pos != null)
        {
            Detach(_pos);
            return _pos;
        }

        var root = new DockPanel();
        root.Children.Add(Sidebar());
        var main = new DockPanel();
        main.Children.Add(TopBar());
        var body = new Grid();
        if (_session.NeedsCompanyChoice)
            body.Children.Add(CompanyChoice());
        else if (_module != null)
            body.Children.Add(ModuleBody());
        else
            body.Children.Add(SectionBody());
        main.Children.Add(body);
        root.Children.Add(main);
        return root;
    }

    private Control Sidebar()
    {
        var side = new Border { Background = Brand.Brush(Brand.Navy), Width = 248, Padding = new Avalonia.Thickness(16, 20) };
        var stack = new DockPanel();
        var brand = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, Margin = new Avalonia.Thickness(0, 0, 0, 24) };
        brand.Children.Add(new Image { Source = Brand.Icon, Width = 36, Height = 36 });
        var titles = new StackPanel();
        titles.Children.Add(new TextBlock { Text = "ERP Mobile", Foreground = Brushes.White, FontWeight = FontWeight.SemiBold, FontSize = 16 });
        titles.Children.Add(new TextBlock { Text = "v " + Brand.Version, Foreground = Brand.Brush("#D6DEE8"), FontSize = 12 });
        brand.Children.Add(titles);
        DockPanel.SetDock(brand, Dock.Top);
        stack.Children.Add(brand);

        var footer = new StackPanel { Spacing = 8, Margin = new Avalonia.Thickness(0, 8, 0, 36) };
        var close = SidebarAction("Închidere");
        close.Click += (_, _) => Close();
        footer.Children.Add(close);
        DockPanel.SetDock(footer, Dock.Bottom);
        stack.Children.Add(footer);

        var nav = new StackPanel { Spacing = 4 };
        nav.Children.Add(Nav("home", "Acasă"));
        nav.Children.Add(Nav("crm", "CRM"));
        nav.Children.Add(Nav("utilities", "Utilitare"));
        nav.Children.Add(Nav("help", "Ajutor"));
        nav.Children.Add(Nav("whatsnew", "Ce este nou..."));
        nav.Children.Add(Nav("settings", "Setări"));
        stack.Children.Add(nav);
        side.Child = stack;
        DockPanel.SetDock(side, Dock.Left);
        return side;
    }

    private static Button SidebarAction(string title)
    {
        return new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            Background = Brushes.Transparent,
            Foreground = Brushes.White,
            BorderBrush = Brand.Brush("#355172"),
            Padding = new Avalonia.Thickness(12, 8)
        };
    }

    private Button Nav(string id, string title)
    {
        var selected = _module == null && _section == id;
        var button = new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Background = selected ? Brand.Brush("#16345C") : Brushes.Transparent,
            Foreground = Brushes.White,
            Padding = new Avalonia.Thickness(12, 8),
            CornerRadius = new Avalonia.CornerRadius(8)
        };
        button.Click += (_, _) => Dispatcher.UIThread.Post(() =>
        {
            _section = id;
            _module = null;
            Render();
        });
        return button;
    }

    private Control TopBar()
    {
        var bar = new Border { Background = Brushes.White, Padding = new Avalonia.Thickness(20, 12), BorderBrush = Brand.Brush(Brand.Line), BorderThickness = new Avalonia.Thickness(0, 0, 0, 1) };
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var left = new StackPanel { Spacing = 2 };
        left.Children.Add(new TextBlock
        {
            Text = _module?.Name ?? SectionTitle(),
            FontSize = 18,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy)
        });
        if (!string.IsNullOrWhiteSpace(_session.PasswordWarning))
            left.Children.Add(new TextBlock { Text = _session.PasswordWarning, Foreground = Brushes.DarkGoldenrod });
        if (!string.IsNullOrWhiteSpace(_session.Error) && _session.State == SessionState.Ready)
            left.Children.Add(new TextBlock { Text = _session.Error, Foreground = Brushes.IndianRed });
        grid.Children.Add(left);

        var right = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12, VerticalAlignment = VerticalAlignment.Center };
        if (_session.SwitchableCompanies.Count > 0)
        {
            var combo = new ComboBox { MinWidth = 220, ItemsSource = _session.SwitchableCompanies, SelectedItem = _session.CurrentCompany };
            combo.SelectionChanged += async (_, _) =>
            {
                if (combo.SelectedItem is CompanyRow company && company.Id != _session.CurrentCompany?.Id)
                {
                    _module = null;
                    await _session.SelectCompany(company);
                }
            };
            right.Children.Add(combo);
        }
        right.Children.Add(new TextBlock
        {
            Text = _session.Profile?.FullName ?? "",
            VerticalAlignment = VerticalAlignment.Center,
            Foreground = Brand.Brush(Brand.Muted)
        });
        Grid.SetColumn(right, 1);
        grid.Children.Add(right);
        bar.Child = grid;
        DockPanel.SetDock(bar, Dock.Top);
        return bar;
    }

    private string SectionTitle() => _section switch
    {
        "crm" => "CRM",
        "utilities" => "Utilitare",
        "help" => "Ajutor",
        "whatsnew" => "Ce este nou...",
        "settings" => "Setări",
        _ => "Acasă"
    };

    private Control CompanyChoice()
    {
        var stack = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 12, MaxWidth = 520 };
        stack.Children.Add(new TextBlock { Text = "Alegeți societatea cu care lucrați.", FontSize = 16, Foreground = Brand.Brush(Brand.Navy) });
        foreach (var company in _session.SwitchableCompanies)
        {
            var button = new Button
            {
                Content = company.Denumire,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Left,
                Padding = new Avalonia.Thickness(12, 10),
                Background = Brushes.White
            };
            var chosen = company;
            button.Click += async (_, _) => await _session.SelectCompany(chosen);
            stack.Children.Add(button);
        }
        return stack;
    }

    private Control SectionBody() => _section switch
    {
        "crm" => CrmPage(),
        "utilities" => UtilitiesPage(),
        "help" => new HelpManualPage(_session),
        "whatsnew" => WhatsNewPage(),
        "settings" => SettingsPage(),
        _ => HomePage()
    };

    private Control HomePage()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 16 };
        if (_session.Profile?.IsSuperAdmin == true && _session.Companies.Count == 0)
        {
            page.Children.Add(new TextBlock { Text = "Nu există nicio societate. Adăugați prima societate ca să puteți lucra.", TextWrapping = TextWrapping.Wrap });
            var add = new Button { Content = "Adaugă societate", Padding = new Avalonia.Thickness(14, 8), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
            add.Click += async (_, _) => await CompanyDialog.Create(this, _session);
            page.Children.Add(add);
            return page;
        }
        if (_session.CurrentCompany == null)
        {
            page.Children.Add(new TextBlock { Text = "Selectați o societate ca să vedeți modulele.", Foreground = Brand.Brush(Brand.Muted) });
            return page;
        }

        var wrap = new WrapPanel { Orientation = Avalonia.Layout.Orientation.Horizontal };
        foreach (var module in _session.Modules)
        {
            var card = new Button
            {
                Width = 240,
                Height = 120,
                Margin = new Avalonia.Thickness(0, 0, 12, 12),
                Background = Brushes.White,
                CornerRadius = new Avalonia.CornerRadius(12),
                HorizontalContentAlignment = HorizontalAlignment.Left,
                VerticalContentAlignment = VerticalAlignment.Center,
                Padding = new Avalonia.Thickness(16)
            };
            var text = new StackPanel { Spacing = 6 };
            text.Children.Add(new TextBlock { Text = module.Name, FontWeight = FontWeight.SemiBold, FontSize = 16, Foreground = Brand.Brush(Brand.Navy), TextWrapping = TextWrapping.Wrap });
            if (!string.IsNullOrWhiteSpace(module.Description))
                text.Children.Add(new TextBlock { Text = module.Description, Foreground = Brand.Brush(Brand.Muted), FontSize = 12, TextWrapping = TextWrapping.Wrap, MaxHeight = 36 });
            card.Content = text;
            var chosen = module;
            card.Click += (_, _) => Dispatcher.UIThread.Post(() =>
            {
                _module = chosen;
                Render();
            });
            wrap.Children.Add(card);
        }
        page.Children.Add(wrap);
        return new ScrollViewer { Content = page };
    }

    private Control ModuleScreen(AppSession session, AppModule module)
    {
        var lists = ModuleCatalog.ForModule(module.Code);
        return module.Code switch
        {
            "nomenclatoare" => new NomenclatoareHome(session, module),
            "cashier" => CashierScreen(),
            "client_invoices_payments" => new SectionHome(session, module,
            [
                new ModuleSection("Situație clienți", "Clienți, facturi emise, scadențe și încasări.", lists.Where(list => list.Title != "Bonuri Z").ToList()),
                new ModuleSection("Zetta", "Rapoartele Z salvate pentru societate. Importul din poză sau PDF este în Utilitare.", lists.Where(list => list.Title == "Bonuri Z").ToList())
            ]),
            "hr" => new SectionHome(session, module,
            [
                new ModuleSection("Angajați", "Nomenclator personal: marcă, nume, CNP, telefon, punct de lucru.", lists.Where(list => list.Title == "Angajați").ToList()),
                new ModuleSection("Contracte", "CIM, durată, funcție și salariu brut.", lists.Where(list => list.Title == "Contracte").ToList()),
                new ModuleSection("Stat de plată", "Statele lunii și liniile de stat.", lists.Where(list => list.Title is "State de plată" or "Linii stat").ToList()),
                new ModuleSection("Pontaj", "Zilele de pontaj ale angajaților.", lists.Where(list => list.Title == "Pontaj").ToList()),
                new ModuleSection("Listări", "PDF-urile de stat, fluturași și notă contabilă se generează din aceste linii.", lists.Where(list => list.Title == "Linii stat").ToList()),
                new ModuleSection("Setări HR", "Orar, conturi și primul număr de notă.", [], Custom: new HrSettingsForm(session))
            ]),
            "stock_sheet" => new SectionHome(session, module,
            [
                new ModuleSection("Actualizare stocuri inițiale", "Cantitatea curentă pe articol.", lists.Where(list => list.Title == "Stoc curent").ToList()),
                new ModuleSection("Generare fișă stoc", "Intrări și ieșiri din care se calculează fișa.", lists.Where(list => list.Title == "Mișcări").ToList())
            ]),
            _ when lists.Count == 0 => TextPage(module.Name, "Modul în dezvoltare."),
            _ => new ModuleHost(session, module, lists)
        };
    }

    private Control ModuleBody()
    {
        var module = _module!;
        var host = new DockPanel();
        var back = new Button { Content = "← Acasă", Margin = new Avalonia.Thickness(20, 12, 20, 0), HorizontalAlignment = HorizontalAlignment.Left, Background = Brushes.White };
        back.Click += (_, _) => Dispatcher.UIThread.Post(() => { _module = null; _cashier = null; Render(); });
        DockPanel.SetDock(back, Dock.Top);
        host.Children.Add(back);
        host.Children.Add(ModuleScreen(_session, module));
        return host;
    }

    private Control CrmPage()
    {
        if (_session.CurrentCompany == null)
            return TextPage("CRM", "Selectați o societate.");
        return new RegisterView(_session, ModuleCatalog.Crm, ModuleAccess.Full, "Aceleași lead-uri, contacte, oferte și tichete ca în aplicația mobilă.");
    }

    private Control CashierScreen()
    {
        _cashier ??= new CasierHome(_session, (id, name) =>
        {
            _pos = new CasierPosView(_session, id, name, () =>
            {
                _pos = null;
                Render();
            });
            Render();
        });
        Detach(_cashier);
        return _cashier;
    }

    private static void Detach(Control control)
    {
        switch (control.Parent)
        {
            case Panel panel:
                panel.Children.Remove(control);
                break;
            case ContentControl content:
                content.Content = null;
                break;
            case Decorator decorator:
                decorator.Child = null;
                break;
        }
    }

    private Control UtilitiesPage() => new UtilitiesHome(_session);

    private Control SettingsPage() => new SettingsHome(_session);

    private static Control WhatsNewPage()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 14, MaxWidth = 720 };
        page.Children.Add(new TextBlock { Text = "Ce este nou...", FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        page.Children.Add(new TextBlock { Text = "What's New", FontSize = 16, Foreground = Brand.Brush("#003399") });
        page.Children.Add(Release("1.0.150", "09.10.2026",
            "Dacă la emitere nu este internet, bonul și factura se salvează fără codul QR și fără mesaj de eroare."));
        page.Children.Add(Release("1.0.149", "09.10.2026",
            "Pe tile, meniul arată denumirea dată la creare, nu numele produsului principal."));
        page.Children.Add(Release("1.0.148", "09.10.2026",
            "Codul QR mare de pe bon și de pe factură deschide PDF-ul documentului.",
            "Discountul procentual se aplică la restul bonului. SGR rămâne la prețul întreg."));
        page.Children.Add(Release("1.0.147", "09.10.2026",
            "Codul QR cu datele bonului și ale facturii este un pătrat cât lățimea hârtiei. Sub el, pe același rând, sunt două coduri mai mici: factura.dateconta.ro și beautymanager.net."));
        page.Children.Add(Release("1.0.146", "09.10.2026",
            "Jos, pe bonul fiscal și pe factură, apare un cod QR cu toate datele documentului. Același cod se tipărește și la casa de marcat, când imprimanta este legată."));
        page.Children.Add(Release("1.0.145", "09.10.2026",
            "Pe factură, fiecare linie arată și procentul de TVA. Jos scrie Baza, TVA și Total, fără semnul egal."));
        page.Children.Add(Release("1.0.144", "09.10.2026",
            "La emiterea bonului, stocul produselor se scade fără eroarea de dată lipsă."));
        page.Children.Add(Release("1.0.143", "09.10.2026",
            "Pe Windows, la pornire apare aceeași animație ca pe Mac, timp de 10 secunde: 5 secunde „Se inițializează...” cu versiunea, apoi 5 secunde „Se încarcă societățile”."));
        page.Children.Add(Release("1.0.142", "09.10.2026",
            "CUI-ul clientului de pe bon și de pe factură se scrie ca la ANAF: cu RO dacă firma este plătitoare de TVA, fără RO dacă nu este."));
        page.Children.Add(Release("1.0.141", "09.10.2026",
            "Pe bon, înainte de metoda de plată, puteți aplica un discount procentual. Totalul de încasat și cotele de TVA scad cu acel procent."));
        page.Children.Add(Release("1.0.140", "09.10.2026",
            "La crearea meniului, o bifă stabilește dacă la vânzare se pot alege mai multe produse secundare. Fără bifă se alege un singur secundar. Fiecare meniu primește un cod de produs unic."));
        page.Children.Add(Release("1.0.139", "09.10.2026",
            "Manualul povestește unde se creează meniurile, cum se trece CUI-ul pe bon și unde se listează facturile clienților."));
        page.Children.Add(Release("1.0.138", "09.10.2026",
            "Dacă ANAF arată că firma de pe CUI este radiată sau inactivă, nu se poate emite bonul sau factura. Mesajul roșu arată denumirea, CUI-ul și starea, cu variantele Fără CUI sau Corectează."));
        page.Children.Add(Release("1.0.137", "09.10.2026",
            "La casă, alegeți secundarele meniului, inclusiv pe cel obligatoriu, și trebuie ales cel puțin unul. Pe bon, secundarul are prețul întreg, iar sub el apare discount 100%."));
        page.Children.Add(Release("1.0.136", "09.10.2026",
            "În grupa Meniuri, coșul de gunoi este în dreapta fiecărui meniu. Pe Windows, Meniu nou, Modifică și Șterge deschid meniul ca să adăugați, schimbați sau ștergeți produsele din el."));
        page.Children.Add(Release("1.0.135", "09.10.2026",
            "Meniul arată poza produsului principal, la casă și în listă."));
        page.Children.Add(Release("1.0.134", "09.10.2026",
            "Pe factură, fiecare linie de pe bon arată cantitatea, prețul fără TVA, valoarea și TVA-ul."));
        page.Children.Add(Release("1.0.133", "09.10.2026",
            "Pe bon, fiecare produs din meniu își păstrează cota de TVA și este marcat cu ea, de exemplu A 21% sau B 11%."));
        page.Children.Add(Release("1.0.132", "09.10.2026",
            "Un meniu are un produs principal și produse secundare: unul obligatoriu și până la 10 opționale. La casă alegeți secundarele vândute. Pe bon, meniul nu are cotă și preț; principalul ia prețul meniului, secundarele au discount 100%, iar SGR-ul se scade din principal. Stocul produselor din meniu scade la emitere."));
        page.Children.Add(Release("1.0.131", "09.10.2026",
            "Bonul fiscal și factura fiscală sunt pe lățimea hârtiei de 80 mm, ca rola imprimantei."));
        page.Children.Add(Release("1.0.130", "09.10.2026",
            "La Articole, criteriul de grupe include Meniuri. Alegerea lui arată meniurile, nu doar grupele de produse."));
        page.Children.Add(Release("1.0.129", "09.10.2026",
            "Pe bonul fiscal, sub total, apar brutul și TVA-ul pe fiecare cotă. Pe factură, înainte de total, scrie baza și TVA-ul."));
        page.Children.Add(Release("1.0.128", "09.10.2026",
            "Pe bon, cantitatea 1 nu se mai scrie lângă produs. Apare doar când este mai mare, iar la SGR-ul cumulat se scrie mereu."));
        page.Children.Add(Release("1.0.127", "09.10.2026",
            "Garanția SGR de pe mai multe produse se adună într-un singur rând, pe bonul de pe ecran și în PDF."));
        page.Children.Add(Release("1.0.126", "09.10.2026",
            "Pe bonul și factura fiscală salvate în PDF, lângă denumirea produsului nu mai apare litera de TVA."));
        page.Children.Add(Release("1.0.125", "09.10.2026",
            "Pe bonul și factura fiscală salvate în PDF, ultimul rând este „Document generat cu ERP Mobile by DateConta”, centrat."));
        page.Children.Add(Release("1.0.124", "09.10.2026",
            "Pe bonul și factura fiscală salvate în PDF, denumirea lungă trece pe rândul următor și nu mai acoperă prețul."));
        page.Children.Add(Release("1.0.123", "09.10.2026",
            "În POS, punctele de lucru se aleg din tile-uri așezate unul lângă altul."));
        page.Children.Add(Release("1.0.122", "09.10.2026",
            "Pe bon, fiecare produs se poate șterge cu × înainte să închideți bonul."));
        page.Children.Add(Release("1.0.121", "09.10.2026",
            "În POS, încasările de pe bara de jos sunt centrate, iar produsele încap câte patru pe rând."));
        page.Children.Add(Release("1.0.120", "09.10.2026",
            "În Ajutor, capitolul Casier — vânzare POS explică pas cu pas catalogul, bonul, CUI-ul, factura fiscală și încasările de la ultimul Z."));
        page.Children.Add(Release("1.0.119", "09.10.2026",
            "Dacă pe bon este trecut CUI, butonul Modernă devine inactiv."));
        page.Children.Add(Release("1.0.118", "09.10.2026",
            "La plata modernă alegeți Glovo, Bolt sau Wolt. Pe bara de jos a POS-ului se văd încasările de la ultimul Z: numerar, card, Glovo, Bolt și Wolt."));
        page.Children.Add(Release("1.0.117", "09.10.2026",
            "Cu bifa Tipărește și factură fiscală, butonul devine Emite bon și FF. Dacă imprimanta nu este legată, se salvează două PDF-uri: bonul și factura."));
        page.Children.Add(Release("1.0.116", "09.10.2026",
            "După verificarea CUI-ului la ANAF, pe bon apare denumirea clientului, sub câmpul CUI."));
        page.Children.Add(Release("1.0.115", "09.10.2026",
            "Setări → e-Factura (SPV): trimiteți email contabilului pentru autorizare cu semnătura lui electronică. Acolo vedeți starea și până când este valabilă."));
        page.Children.Add(Release("1.0.114", "09.10.2026",
            "Dacă bonul are CUI, apare bifa Tipărește și factură fiscală. La emitere se tipărește întâi bonul fiscal, apoi factura fiscală pe 57 mm. Seria fiecărui punct de lucru se stabilește în Nomenclatoare → Societăți → Serii documente."));
        page.Children.Add(Release("1.0.113", "09.10.2026",
            "Pe Windows, Enter la CUI-ul de pe bon îl verifică la ANAF. Dacă este corect rămâne pe bon; dacă nu, îl puteți corecta sau reveni fără CUI."));
        page.Children.Add(Release("1.0.112", "09.10.2026",
            "Pe Windows, click pe CUI client din POS deschide aceeași tastatură numerică. Enter o închide."));
        page.Children.Add(Release("1.0.111", "09.10.2026",
            "Pe Windows, click pe suma primită din POS deschide o tastatură numerică. Enter o închide."));
        page.Children.Add(Release("1.0.110", "09.10.2026",
            "Pe bonul din POS: cotă A 21%, B 11% sau D 0%. Încasare numerar, card sau plată modernă (Glovo, Bolt, Wolt). La numerar introduceți suma primită și vedeți restul. Până la 4 bonuri deschise, fiecare cu CUI client."));
        page.Children.Add(Release("1.0.109", "09.10.2026",
            "După punctul de lucru, POS arată ecranul de vânzare: catalogul în stânga și bonul în dreapta. Produsul apăsat intră pe bon, cu SGR-ul din fișă."));
        page.Children.Add(Release("1.0.108", "08.10.2026",
            "Pe Windows, modificarea unui articol folosește aceeași fișă ca pe Mac, cu poza articolului."));
        page.Children.Add(Release("1.0.107", "08.10.2026",
            "În POS, denumirea produsului este centrată pe tile."));
        page.Children.Add(Release("1.0.106", "08.10.2026",
            "La Articole, căutarea găsește și codul. Lista se poate filtra opțional după grupa de catalog."));
        page.Children.Add(Release("1.0.105", "08.10.2026",
            "În POS, Înapoi la grupe este buton, în stânga jos, când sunteți într-o grupă."));
        page.Children.Add(Release("1.0.104", "08.10.2026",
            "Pe Windows, aplicația acoperă tot ecranul, inclusiv bara de start, până la Închidere."));
        page.Children.Add(Release("1.0.103", "08.10.2026",
            "Pe tile-ul din POS, codul produsului este în stânga, în fața denumirii."));
        page.Children.Add(Release("1.0.102", "08.10.2026",
            "În POS, grupele de catalog și produsele din grupă sunt afișate în ordine alfabetică."));
        page.Children.Add(Release("1.0.101", "08.10.2026",
            "În POS, Ieșire este în dreapta jos. Înapoi la grupe apare în stânga aceleiași bare, când sunteți într-o grupă."));
        page.Children.Add(Release("1.0.100", "08.10.2026",
            "Acasă → Casier: Producție (Bon producție, Bon transfer) și POS. POS umple ecranul, pe punctul de lucru ales, cu grupele de catalog și produsele ca tile-uri (poză, cod, denumire, preț în RON)."));
        page.Children.Add(Release("1.0.099", "08.10.2026",
            "Pe Windows, Ajutor conține același manual de utilizare ca pe Mac și iPhone: cuprins, capitole și capturi."));
        page.Children.Add(Release("1.0.098", "08.10.2026",
            "Când revine internetul, datele rămase nesincronizate se trimit singure, pe Mac și pe Windows."));
        page.Children.Add(Release("1.0.097", "08.10.2026",
            "Nomenclatoare pe Windows are aceleași intrări ca pe Mac: Societăți, Parteneri, Catalog, Articole, Persoane și Conturi.",
            "Clienți, HR și Fișa de stoc se deschid pe aceleași secțiuni ca pe Mac.",
            "Setări → Înapoi rămâne în aplicație. Sync offline arată conexiunea și operațiile salvate fără internet."));
        page.Children.Add(Release("1.0.096", "08.10.2026",
            "Utilitare Windows: Creare fișier import ZETTA citește PDF-urile și pozele de Raport Z, arată sumele ca să le corectați și salvează Excel-ul de notă contabilă.",
            "Z-uri scanate → import Zetta pe Windows: fiecare pagină este un Z, Nr. înreg. pornește de la numărul ales, iar Excel-ul se salvează pe firmă."));
        page.Children.Add(Release("1.0.095", "08.10.2026",
            "Pe Windows, Ieșire a fost scos din bara din stânga. Delogarea este în Setări → Deconectare. Închidere rămâne în bară și nu vă deloghează."));
        page.Children.Add(Release("1.0.094", "08.10.2026",
            "Aplicația Windows are aceeași versiune cu Mac și iPhone. Rămâneți autentificat până la Ieșire; Închidere închide fereastra fără delogare.",
            "Setări Windows: limbă, utilizatori, sync, setări Zetta, scurtătură pe Desktop, administrare societăți și deconectare — aceleași intrări ca pe Mac.",
            "La modificare, categoria articolului și celelalte câmpuri cu variante se aleg din listă.",
            "Utilitare Windows: arhivă MT940 din extrasul bancar și Excel NextUp din nota contabilă PDF."));
        page.Children.Add(new TextBlock { Text = "Urmează în 1.0.151", FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy), Margin = new Avalonia.Thickness(0, 8, 0, 0) });
        page.Children.Add(Bullet("BINA Smart Business: stabilizare listă Rapoarte Z în perioadă și descărcare batch PDF-uri în română."));
        page.Children.Add(Bullet("Extragere Rapoarte Z: conectori Memgest, BOCP și Generic HTTP (pe lângă BINA)."));
        page.Children.Add(Bullet("POS: tipărire bon fiscal, raport X și raport Z pe Datecs FP-700."));
        page.Children.Add(Bullet("e-Factura: încărcare directă ANAF SPV (OAuth) pe lângă canalul contabil."));
        page.Children.Add(new TextBlock
        {
            Text = "ERP Mobile · DATECONTA.RO · 9 octombrie 2026",
            Foreground = Brand.Brush(Brand.Muted),
            Margin = new Avalonia.Thickness(0, 12, 0, 0)
        });
        return new ScrollViewer { Content = page };
    }

    private static Control Release(string version, string date, params string[] items)
    {
        var stack = new StackPanel { Spacing = 6 };
        stack.Children.Add(new TextBlock { Text = "v " + version + "  ·  " + date, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        foreach (var item in items)
            stack.Children.Add(Bullet(item));
        return stack;
    }

    private static Control Bullet(string text)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("16,*") };
        grid.Children.Add(new TextBlock { Text = "•", Foreground = Brand.Brush(Brand.Navy) });
        var body = new TextBlock { Text = text, TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush("#243246") };
        Grid.SetColumn(body, 1);
        grid.Children.Add(body);
        return grid;
    }

    private static Control TextPage(string title, string body)
    {
        var stack = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 10, MaxWidth = 720 };
        stack.Children.Add(new TextBlock { Text = title, FontSize = 22, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        stack.Children.Add(new TextBlock { Text = body, TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush("#243246"), FontSize = 15, LineHeight = 22 });
        return new ScrollViewer { Content = stack };
    }
}

public sealed class ModuleHost : UserControl
{
    public ModuleHost(AppSession session, AppModule module, IReadOnlyList<ListSpec> lists, string? note = null)
    {
        Content = new TextBlock { Text = "Se încarcă drepturile...", Margin = new Avalonia.Thickness(24) };
        _ = Load(session, module, lists, note);
    }

    private async Task Load(AppSession session, AppModule module, IReadOnlyList<ListSpec> lists, string? note)
    {
        try
        {
            var access = await session.LoadAccess(module);
            if (!access.CanView)
            {
                Content = new TextBlock { Text = "Nu aveți drept de vizualizare pentru acest modul.", Margin = new Avalonia.Thickness(24) };
                return;
            }
            note ??= module.Code switch
            {
                "sales" => "Bonurile și rapoartele Z sunt aceleași înregistrări ca în aplicația mobilă.",
                "stock_sheet" => "Fișa de stoc se calculează din stocul și mișcările de mai jos.",
                _ => null
            };
            Content = new RegisterView(session, lists, access, note);
        }
        catch (Exception ex)
        {
            Content = new TextBlock { Text = ex.Message, Margin = new Avalonia.Thickness(24), Foreground = Brushes.IndianRed, TextWrapping = TextWrapping.Wrap };
        }
    }
}
