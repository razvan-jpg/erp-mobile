using Avalonia;
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

        var nav = new StackPanel { Spacing = 4 };
        nav.Children.Add(Nav("home", "Acasă"));
        nav.Children.Add(Nav("crm", "CRM"));
        nav.Children.Add(Nav("utilities", "Utilitare"));
        nav.Children.Add(Nav("help", "Ajutor"));
        nav.Children.Add(Nav("whatsnew", "Ce este nou..."));
        nav.Children.Add(Nav("settings", "Setări"));
        DockPanel.SetDock(nav, Dock.Top);
        stack.Children.Add(nav);
        var logo = new Image
        {
            Source = Brand.SidebarLogo(_session.CurrentCompany),
            Width = 248,
            Height = 248,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Avalonia.Thickness(-16, 16, -16, 0)
        };
        DockPanel.SetDock(logo, Dock.Top);
        stack.Children.Add(logo);
        var close = SidebarAction("Închidere");
        close.Click += (_, _) => Close();
        var closeHost = new Grid();
        closeHost.Children.Add(new Border
        {
            Child = close,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Background = Brushes.Transparent,
            CornerRadius = new Avalonia.CornerRadius(10),
            BoxShadow = BoxShadows.Parse("0 4 0 0 #5C4318, 0 8 14 0 #55000000")
        });
        stack.Children.Add(closeHost);
        side.Child = stack;
        DockPanel.SetDock(side, Dock.Left);
        return side;
    }

    private static Button SidebarAction(string title)
    {
        var button = new Button
        {
            Content = new TextBlock
            {
                Text = title,
                Foreground = Brushes.White,
                FontWeight = FontWeight.SemiBold,
                TextAlignment = TextAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            },
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            VerticalContentAlignment = VerticalAlignment.Center,
            Background = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0.5, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0.5, 1, RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.Parse("#F3D7A2"), 0),
                    new GradientStop(Color.Parse("#C6A15A"), 0.48),
                    new GradientStop(Color.Parse("#8D682C"), 1)
                }
            },
            Foreground = Brushes.White,
            BorderBrush = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0.5, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0.5, 1, RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.Parse("#FFFFF6"), 0),
                    new GradientStop(Color.Parse("#E8C98A"), 0.35),
                    new GradientStop(Color.Parse("#6A4E1C"), 1)
                }
            },
            BorderThickness = new Avalonia.Thickness(1),
            Padding = new Avalonia.Thickness(18, 10),
            MinWidth = 180,
            MinHeight = 44,
            CornerRadius = new Avalonia.CornerRadius(10),
            FontWeight = FontWeight.SemiBold
        };
        ToolTip.SetTip(button, title);
        return button;
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
        ToolTip.SetTip(button, title);
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
            "inventory" => new SectionHome(session, module,
            [
                new ModuleSection("Necesar comandă", "Articole sub stocul minim, pe categorii. Cantitatea se poate modifica. Puteți adăuga sau scoate articole. Birotica se adaugă manual.", [], Custom: new ReorderNeedView(session)),
                new ModuleSection("Stocuri și mișcări", "Solduri și mișcări de stoc.", lists.Where(list => list.Title is "Stocuri" or "Mișcări").ToList()),
                new ModuleSection("Inventar fizic", "Inventarele salvate.", lists.Where(list => list.Title == "Inventar fizic").ToList())
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
        page.Children.Add(Release("1.0.284", "13.10.2026",
            "La Necesar comandă, cantitatea de comandat este un câmp cu chenar și creion, ca să se vadă că se poate modifica."));
        page.Children.Add(Release("1.0.283", "13.10.2026",
            "La Necesar comandă, lista e pe categorii. Cantitatea de comandat se poate modifica, iar articolele se pot adăuga sau scoate. Materialele consumabile au stoc optim 15, materialele de curățenie minim 1 și optim 3. Birotica nu intră automat."));
        page.Children.Add(Release("1.0.282", "13.10.2026",
            "La Necesar comandă, cantitatea de comandat este stocul optim minus stocul real. Se poate tipări și salva PDF direct în folder."));
        page.Children.Add(Release("1.0.281", "13.10.2026",
            "La Articole apare Stoc optim. La toate articolele, în afară de produsele finite, stocul minim este 10 și stocul optim este 25."));
        page.Children.Add(Release("1.0.280", "13.10.2026",
            "La casă, tile-urile sunt semitransparente, ca să se vadă logo-ul din fundal, și catalogul se deschide mai repede."));
        page.Children.Add(Release("1.0.279", "13.10.2026",
            "La casă, pe In Store plata este Numerar, Card sau Numerar + Card."));
        page.Children.Add(Release("1.0.278", "13.10.2026",
            "La casă, pe On line singura plată este Modernă: Glovo, Bolt sau Wolt."));
        page.Children.Add(Release("1.0.277", "13.10.2026",
            "La casă, un produs sau un meniu cu prețul de vânzare 0 nu se poate marca pe bon."));
        page.Children.Add(Release("1.0.276", "13.10.2026",
            "Meniurile au preț In Store și preț On Line. La casă, comutatorul alege prețul meniului."));
        page.Children.Add(Release("1.0.275", "13.10.2026",
            "La Articole, grupele și categoriile se pot bifa mai multe deodată: toate, sau doar cele alese."));
        page.Children.Add(Release("1.0.274", "13.10.2026",
            "La Articole, tile-urile și lista se pot sorta după nume sau după categoria articolului."));
        page.Children.Add(Release("1.0.273", "12.10.2026",
            "Pe bara din stânga, fiecare firmă are sigla ei. Dacă nu e încărcată, apare un pătrat cu inițialele firmei. Nectarie păstrează sigla ei."));
        page.Children.Add(Release("1.0.272", "12.10.2026",
            "Închidere aplicație este un buton 3D, centrat pe verticală în spațiul de sub siglă."));
        page.Children.Add(Release("1.0.271", "12.10.2026",
            "Butonul Închidere aplicație este centrat pe verticală și pe orizontală în meniul din stânga."));
        page.Children.Add(Release("1.0.270", "12.10.2026",
            "Închidere aplicație din meniul din stânga este buton și închide fereastra fără delogare."));
        page.Children.Add(Release("1.0.269", "12.10.2026",
            "La Articole, pe tile și în listă apare și stocul minim."));
        page.Children.Add(Release("1.0.268", "12.10.2026",
            "La Articole, pe tile și în listă apar ambele prețuri de vânzare: In Store și On Line."));
        page.Children.Add(Release("1.0.267", "12.10.2026",
            "La Nectarie, sigla apare și pe bara din stânga, sub meniu, într-un pătrat cât lățimea barei."));
        page.Children.Add(Release("1.0.266", "12.10.2026",
            "La Nectarie, ecranul de vânzare POS are sigla estompată 50% pe fundal, doar până la bon."));
        page.Children.Add(Release("1.0.265", "12.10.2026",
            "NECTARIE: pe shaorme / box / chifle etc. rețetele folosesc din nou produsul finit DONER PUI; pieptul de pui rămâne doar în rețeta DONER PUI."));
        page.Children.Add(Release("1.0.264", "12.10.2026",
            "Inventar: pe fiecare produs apare categoria articolului; puteți sorta tabelul după categorie, nume, cod, stoc scriptic, numărat sau diferență."));
        page.Children.Add(Release("1.0.263", "12.10.2026",
            "NECTARIE: retetele folosesc acum materiile prime din baza (CARTOFI ALBI, CURRY, PIEPT DE PUI, DONER VITA TOCAT) in locul codurilor BINA; ingredientele fara corespondent au fost eliminate."));
        page.Children.Add(Release("1.0.262", "12.10.2026",
            "NECTARIE: *1201*1245SGR (QAB AQUA CARPATICA PLATA 0.5L) unificat pe AQUA PLATA 0.5 L (cod 1469)."));
        page.Children.Add(Release("1.0.261", "12.10.2026",
            "NECTARIE: *340053107SGR (QAB AQUA CARPATICA CARBO 0.5L) unificat pe AQUA MINERALA 0.5 L (cod 1470)."));
        page.Children.Add(Release("1.0.260", "12.10.2026",
            "NECTARIE: sterse 14 articole tarife deseuri / TMB (coduri 6421735000120–0151 selectate)."));
        page.Children.Add(Release("1.0.259", "12.10.2026",
            "NECTARIE: 11 coduri Q (cutii, hartie, seturi etc.) mutate pe tip ambalaj: 00014099, 00014000, 00014053/1, 00014098, 00014022, 00012743, 00009595, 00005040, 00008904, 00014285, 00005053/2."));
        page.Children.Add(Release("1.0.258", "12.10.2026",
            "NECTARIE: codul 00012442/1 (saci LDPE) mutat pe tip materiale curatenie."));
        page.Children.Add(Release("1.0.257", "12.10.2026",
            "NECTARIE: codurile 00014865, 00004908 si 00004909 (manusi nitril Q) mutate pe tip materiale consumabile."));
        page.Children.Add(Release("1.0.256", "12.10.2026",
            "NECTARIE: sterse articolele cu codurile 6421735000124 si 6421735000117."));
        page.Children.Add(Release("1.0.255", "12.10.2026",
            "NECTARIE: master PEPSI ZERO VANILIE 0.33 L (cod 340063926); variantele CAN / DRS Vanilie se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.254", "12.10.2026",
            "NECTARIE: master PEPSI ZERO 0.5 L (cod 1471); QAB / PET Zero 0.5L se unifica pe aceasta fisa la NIR (Vanilie 330 ramane separata)."));
        page.Children.Add(Release("1.0.253", "12.10.2026",
            "NECTARIE: master PEPSI TWIST 0.5 L (cod 1466); QAB / PET Twist 0.5L se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.252", "12.10.2026",
            "NECTARIE: master PEPSI COLA DOZA 0.33 L (cod 1472); QAB / CAN 0.33L se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.251", "12.10.2026",
            "NECTARIE: master PEPSI COLA 0.5 L (cod 1465); QAB / PET 0.5L se unifica pe aceasta fisa la NIR (Twist / Zero / doza raman separate)."));
        page.Children.Add(Release("1.0.250", "12.10.2026",
            "NECTARIE: master MOUNTAIN DEW 0.5 L (cod 1475); variantele PET / SGR se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.249", "12.10.2026",
            "NECTARIE: master MIRINDA ORANGE DOZA 0.33 L (cod 1473); QAB / CAN 0.33L se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.248", "12.10.2026",
            "NECTARIE: master MIRINDA ORANGE 0.5 L (cod 1474); QAB / PET 0.5L se unifica pe aceasta fisa la NIR (doza 0.33 ramane separata)."));
        page.Children.Add(Release("1.0.247", "12.10.2026",
            "NECTARIE: master LIPTON PIERSICI 0.5 L (cod 1467); QAB / ICE TEA PEACH 0.5L se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.246", "12.10.2026",
            "NECTARIE: master LIPTON LAMAIE 0.5 L (cod 1468); QAB / ICE TEA LEMON 0.5L se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.245", "12.10.2026",
            "NECTARIE: INC 33,5 mutat pe tip materiale consumabile."));
        page.Children.Add(Release("1.0.244", "12.10.2026",
            "NECTARIE: master GRANINI 0.33 L (cod 1482); variantele SGR / arome de pe facturi se unifica pe aceasta fisa la NIR."));
        page.Children.Add(Release("1.0.243", "12.10.2026",
            "NECTARIE: sterse articolele cu codurile 305579, 6421735000136, 340063895, 340063894, 721806, 103483 si 100192."));
        page.Children.Add(Release("1.0.242", "12.10.2026",
            "NECTARIE: sters articolul cu codul 378748 (CCA. 2,38 KG ARO MOZZARELLA)."));
        page.Children.Add(Release("1.0.241", "12.10.2026",
            "NECTARIE: chirii, CEC deseuri si utilitati (coduri 6421735000152, 6421735000132, 6421735000153, 6421735000133, 6421735000143, 6421735000114, 6421735000142, 6421735000141) trec pe tip Servicii."));
        page.Children.Add(Release("1.0.240", "12.10.2026",
            "NIR / facturi: Tuborg sticla 0.33 L (inclusiv SGR) se leaga pe fisa „BERE TUBORG ST. 0.33 L” (cod 1479); doza 0.5 L ramane separata."));
        page.Children.Add(Release("1.0.239", "12.10.2026",
            "NIR / facturi: Tuborg doza 0.5 L (inclusiv SGR) se leaga pe fisa „BERE TUBORG DOZA 0.5 L” (cod 1481); sticla 0.33 L ramane separata."));
        page.Children.Add(Release("1.0.238", "12.10.2026",
            "NIR / facturi: Carlsberg doza 0.5 L (inclusiv SGR promo) se leaga pe fisa „BERE CARLSBERG DOZA 0.5 L” (cod 1480); sticla 0.33 L ramane separata."));
        page.Children.Add(Release("1.0.237", "12.10.2026",
            "NIR / facturi: Carlsberg 0.33 L (inclusiv SGR promo) se leaga pe fisa „BERE CARLSBERG 0.33 L” (cod 1478); doza 0.5 L ramane separata."));
        page.Children.Add(Release("1.0.236", "12.10.2026",
            "NIR / facturi: Bere Bucur blonda 0.35 L (inclusiv SGR promo) se leaga pe fisa „BERE BUCUR BLONDA 0.35 L” (cod 1484)."));
        page.Children.Add(Release("1.0.235", "12.10.2026",
            "NIR / facturi: ayranul se leaga pe fisa „AYRAN” (cod 1116); iaurtul ramane separat."));
        page.Children.Add(Release("1.0.234", "12.10.2026",
            "NIR / facturi: aqua plata 0.5 L (inclusiv SGR) se leaga pe fisa „AQUA PLATA 0.5 L” (cod 1469); aqua minerala si 1 L raman separate."));
        page.Children.Add(Release("1.0.233", "12.10.2026",
            "NIR / facturi: aqua minerala 0.5 L (inclusiv carbo/SGR) se leaga pe fisa „AQUA MINERALA 0.5 L” (cod 1470); aqua plata ramane separata."));
        page.Children.Add(Release("1.0.232", "12.10.2026",
            "NIR / facturi: 7UP Lemon Lime 0.5 L (inclusiv SGR) se leaga pe fisa „7UP LEMON LIME 0.5 L” (cod 1477); lamaile proaspete raman pe „LAMAI”."));
        page.Children.Add(Release("1.0.231", "12.10.2026",
            "NECTARIE: sterse articolele cu codurile 381968, 214307, 128583 si 369646."));
        page.Children.Add(Release("1.0.230", "12.10.2026",
            "NECTARIE: articolul cu codul 720653 (Abonament Lunar Comax Pro Plus) trece pe tip Servicii."));
        page.Children.Add(Release("1.0.229", "12.10.2026",
            "NIR / facturi: varza rosie se leaga pe fisa „VARZA ROSIE” (cod 103563); varza alba ramane separata."));
        page.Children.Add(Release("1.0.228", "12.10.2026",
            "NIR / facturi: varza alba (inclusiv varza noua) se leaga pe fisa „VARZA ALBA” (cod 389762); varza rosie ramane separata."));
        page.Children.Add(Release("1.0.227", "12.10.2026",
            "NIR / facturi: uleiul floarea-soarelui (ULEI FL / MC etc.) se leaga pe fisa „ULEI FLOAREA SOARELUI” (cod 104861), UM Litru; uleiul de palmier ramane separat."));
        page.Children.Add(Release("1.0.226", "12.10.2026",
            "NECTARIE: articolul cu codul 6421735000164 (TOTAL BAZA DE IMPOZITARE TVA 21%) trece pe tip Servicii."));
        page.Children.Add(Release("1.0.225", "12.10.2026",
            "NIR / facturi: tortilla 27cm curcuma se leaga pe fisa „TORTILLA 27CM CURCUMA” (cod 6421735000137)."));
        page.Children.Add(Release("1.0.224", "12.10.2026",
            "NECTARIE: tarifele TMB / depozitare (coduri 6421735000200, 6421735000178, 6421735000201, 6421735000179, 6421735000199, 6421735000177, 6421735000198, 6421735000176) trec pe tip Servicii."));
        page.Children.Add(Release("1.0.223", "12.10.2026",
            "NIR / facturi: zaharul (inclusiv 1KG ARO HT) se leaga pe fisa „ZAHAR” (cod 217912), materie prima activa, UM Kg."));
        page.Children.Add(Release("1.0.222", "12.10.2026",
            "NECTARIE: sterse articolele cu codurile 1008, 1070, 1013, 1010, 1133, 1034, 1028, 1442 si 1054."));
        page.Children.Add(Release("1.0.221", "12.10.2026",
            "NIR / facturi: sosul cedar (inclusiv galon 5 L) se leaga pe fisa „SOS CEDAR” (cod 6421735000154), UM Litru."));
        page.Children.Add(Release("1.0.220", "12.10.2026",
            "NIR / facturi: salata verde (inclusiv iceberg) se leaga pe fisa „SALATA VERDE” (cod 103717); salatele finite raman separate."));
        page.Children.Add(Release("1.0.219", "12.10.2026",
            "NIR / facturi: rosiile (RO, P, MC ciorchine etc.) se leaga pe fisa „ROSII” (cod 103616); sosurile de rosii raman separate."));
        page.Children.Add(Release("1.0.218", "12.10.2026",
            "NECTARIE: articolele cu codurile 6421735000196, 6421735000205, 6421735000204, 6421735000191, 6421735000190, 6421735000166, 6421735000165, 0000369 si 503308 trec pe tip Servicii."));
        page.Children.Add(Release("1.0.217", "12.10.2026",
            "NIR / facturi: pulpele de pui dezosate (cu piele) se leaga pe fisa „PULPE DE PUI DEZOSATE CU PIELE” (cod 6421735000135); pieptul ramane separat."));
        page.Children.Add(Release("1.0.216", "12.10.2026",
            "NIR / facturi: portocalele pentru suc se leaga pe fisa „PORTOCALE SUC” (cod 103572); PORTOCALE 3-5 P si bauturile orange raman separate."));
        page.Children.Add(Release("1.0.215", "12.10.2026",
            "NIR / facturi: portocalele (3-5 P) se leaga pe fisa „PORTOCALE 3-5 P” (cod 103921); PORTOCALE SUC si bauturile orange raman separate."));
        page.Children.Add(Release("1.0.214", "12.10.2026",
            "NIR / facturi: pita se leaga pe fisa „PITA” (cod 6421735000138); lipie tip C si PITA EXTRA raman separate."));
        page.Children.Add(Release("1.0.213", "12.10.2026",
            "NIR / facturi: pieptul de pui dezosat (cu piele) se leaga pe fisa „PIEPT DE PUI DEZ CU PIELE” (cod 6421735000113); pulpele raman separate."));
        page.Children.Add(Release("1.0.212", "12.10.2026",
            "NIR / facturi: patrunjelul se leaga pe fisa „PATRUNJEL” (cod 103712)."));
        page.Children.Add(Release("1.0.211", "12.10.2026",
            "NECTARIE: manusile nitrile (coduri 214469 si 211758) trec pe tip Materiale consumabile."));
        page.Children.Add(Release("1.0.210", "12.10.2026",
            "NIR / facturi: mini bagheta 120GR se leaga pe fisa „MINI BAGHETA 120GR” (cod 6421735000140)."));
        page.Children.Add(Release("1.0.209", "12.10.2026",
            "NECTARIE: sterse articolele cu codurile 1051, 1011, 1033 si 1243 (inclusiv mozzarella inactiva din retetele Cheese Kebab)."));
        page.Children.Add(Release("1.0.208", "12.10.2026",
            "NIR / facturi: lipie tip C 750G se leaga pe fisa „LIPIE TIP C 750G” (cod 6421735000112); tip 600G si pita raman separate."));
        page.Children.Add(Release("1.0.207", "12.10.2026",
            "NIR / facturi: Lay's sare (inclusiv 40G/BLT/BAX/DTS) se leaga pe fisa „LAY'S SARE” (cod 340059584); sarea de bucatarie ramane pe „SARE”."));
        page.Children.Add(Release("1.0.206", "12.10.2026",
            "NECTARIE: texte fara diacritice in baza de date (produse, categorii/grupe, module, facturi, stocuri, CRM, HR) si etichete tip produs (Materie prima, Marfa, Materiale curatenie, Birotica etc.)."));
        page.Children.Add(Release("1.0.205", "12.10.2026",
            "Casier → Productie → Bon productie: creati bonuri numerotate si datate automat (gestiune, produs finit, cantitate). La salvare creste stocul produsului finit si scade consumul din reteta (materii prime, marfa; produsele finite din reteta se expanda 1/1)."));
        page.Children.Add(Release("1.0.204", "12.10.2026",
            "Produse: „DONER PUI” (produs finit cu rețetă) — folosit în shaorme/chifle/extra carne pui; în rețetă puteți adăuga și produse finite (consum 1/1 din rețeta lor) pe lângă materii prime și marfă."));
        page.Children.Add(Release("1.0.203", "12.10.2026",
            "NIR / facturi: lămâile (inclusiv plasă 500G) se leagă pe fișa „LAMAI”; băuturile și detergentul cu aromă lămâie rămân separate."));
        page.Children.Add(Release("1.0.202", "12.10.2026",
            "NIR / facturi: Hot Marinade (inclusiv Seasoning 1/1 KG) se leagă pe fișa „HOT MARINADE”."));
        page.Children.Add(Release("1.0.201", "12.10.2026",
            "NIR / facturi: falafel 450G (Edenia etc.) se leagă pe fișa „FALAFEL 450G”; meniul finit din catalog rămâne separat."));
        page.Children.Add(Release("1.0.200", "12.10.2026",
            "NIR / facturi: crustă crispy (ACG 1/10 KG etc.) se leagă pe fișa „CRUSTA CRISPY”; meniurile crispy din catalog rămân separate."));
        page.Children.Add(Release("1.0.199", "12.10.2026",
            "NIR / facturi: Condimix (inclusiv Gustos 1/1 KG) se leagă pe fișa „CONDIMIX”."));
        page.Children.Add(Release("1.0.198", "12.10.2026",
            "NIR / facturi: bait / batter pentru șnițel (BATTER 300 FS etc.) se leagă pe fișa „BAIT SNITEL”."));
        page.Children.Add(Release("1.0.197", "12.10.2026",
            "NIR / facturi: Doner vită tocat (inclusiv linii cu LOT) se leagă pe fișa „DONER VITA TOCAT”; stocurile pe loturi au fost unificate."));
        page.Children.Add(Release("1.0.196", "12.10.2026",
            "NIR / facturi: chiflele mari se leagă pe fișa „CHIFLE MARI” (nu pe chiflele din catalog / produse finite)."));
        page.Children.Add(Release("1.0.195", "12.10.2026",
            "NIR / facturi: Ceko Pizza (inclusiv FIRST 2.3KG / bax) se leagă pe fișa „CEKO PIZZA”."));
        page.Children.Add(Release("1.0.194", "12.10.2026",
            "NIR / facturi: ceapa roșie se leagă pe fișa „CEAPA ROSIE” (separat de galbenă și prăjită)."));
        page.Children.Add(Release("1.0.193", "12.10.2026",
            "NIR / facturi: ceapa prăjită / fulgi se leagă pe fișa „CEAPA PRAJITA” (separat de galbenă și roșie)."));
        page.Children.Add(Release("1.0.192", "12.10.2026",
            "NIR / facturi: ceapa galbenă / albă (inclusiv 10KG) se leagă pe fișa „CEAPA GALBENA”; roșie și prăjită rămân separate."));
        page.Children.Add(Release("1.0.191", "12.10.2026",
            "NIR / facturi: castraveții murați se leagă pe fișa „CASTRAVETI MURATI” (separat de Fabio / proaspeți)."));
        page.Children.Add(Release("1.0.190", "12.10.2026",
            "NIR / facturi: castraveții proaspeți (inclusiv Fabio) se leagă pe fișa „CASTRAVETI FABIO”; murăturile rămân separate."));
        page.Children.Add(Release("1.0.189", "12.10.2026",
            "Articole: categorie nouă „Birotică” (stocabilă) — pe fișă, NIR, transferuri și inventar."));
        page.Children.Add(Release("1.0.188", "12.10.2026",
            "Articole: categorie nouă „Servicii” (nestocabilă) — pe fișă, NIR și filtre; exclusă din inventar (ex. asistență juridică)."));
        page.Children.Add(Release("1.0.187", "12.10.2026",
            "NIR / facturi: detergent vase, soluție aragaz și spray aragaz se leagă automat pe fișele existente și pe categoria Materiale curățenie."));
        page.Children.Add(Release("1.0.186", "12.10.2026",
            "Articole: categorie nouă „Materiale curățenie” (stocabilă), selectabilă pe fișă, NIR, control stoc și inventar — separată de Materiale consumabile."));
        page.Children.Add(Release("1.0.185", "12.10.2026",
            "Iconițe pe Mac: la hover apare imediat un tip cu ce face butonul (fix pentru Catalyst, unde tipul de sistem nu se vedea)."));
        page.Children.Add(Release("1.0.184", "12.10.2026",
            "Control / print stoc: filtrare pe una sau mai multe gestiuni (sau toate) și pe categorii; PDF cu număr de pagină. Articole (fără produs finit): Cantitate minimă pe fișă. Stocuri → Necesar comandă: doar articole cu minim completat, când stocul e sub minim (inclusiv negativ)."));
        page.Children.Add(Release("1.0.183", "12.10.2026",
            "Iconițe: dacă țineți cursorul pe o iconiță (toolbar, buton +, meniu …), apare o scurtă explicație a acțiunii."));
        page.Children.Add(Release("1.0.182", "12.10.2026",
            "Articole: fiecare articol are cod obligatoriu și unic pe societate. Articolele fără cod au primit automat un număr; la creare, dacă lăsați gol, se alocă următorul liber."));
        page.Children.Add(Release("1.0.181", "12.10.2026",
            "Control / print stoc și inventar: pe Mac, Export PDF deschide dialogul de salvare în folder (nu meniul de partajare)."));
        page.Children.Add(Release("1.0.180", "12.10.2026",
            "Articole: categorie nouă „Garanție” (ex. Garantie SGR) — nestocabilă; nu mai intră la inventar ca materie primă / consumabile."));
        page.Children.Add(Release("1.0.179", "12.10.2026",
            "Stocuri: Control / print stoc — alegeți gestiunea, vedeți stocul (opțional pe categorii), export PDF sau tipărire, fără inventar."));
        page.Children.Add(Release("1.0.178", "12.10.2026",
            "Inventar: listare, export PDF și print grupat pe categorii (marfă, materii prime, produse finite etc.)."));
        page.Children.Add(Release("1.0.177", "12.10.2026",
            "Inventar (doar superadmin): buton „Adu întregul stoc pe 0” — golește complet stocul gestiunii selectate, cu confirmare."));
        page.Children.Add(Release("1.0.176", "12.10.2026",
            "Articole: pe listă apare numărul total de articole din baza de date (și „X din Y” la filtrare / căutare)."));
        page.Children.Add(Release("1.0.175", "12.10.2026",
            "Inventar fizic: tabel editabil cu toate produsele (fără finite, inclusiv stoc 0); sortare, căutare, ștergere. Stoc + proces-verbal doar la finalizare. Celulă goală = stoc neschimbat; 0 = stoc zero. Redeschidere pentru corecturi."));
        page.Children.Add(Release("1.0.174", "12.10.2026",
            "Gestiune Nectarie: materiile prime cu CARTOFI se unifică automat pe CARTOFI ALBI la NIR / recepții viitoare (fără catalog)."));
        page.Children.Add(Release("1.0.173", "12.10.2026",
            "Gestiune Nectarie: produsele A.URSUS Cooler… se unifică automat pe URSUS Cooler 0.5 L la NIR / recepții viitoare."));
        page.Children.Add(Release("1.0.172", "12.10.2026",
            "Gestiune Nectarie: variantele ULEI FL / MC ulei floarea-soarelui se unifică automat pe materia primă ULEI FLOAREA SOARELUI la NIR / recepții viitoare (fără catalog)."));
        page.Children.Add(Release("1.0.171", "12.10.2026",
            "Articole / Catalog: comutator tile-uri / listă. Click pe articol deschide fișa de editare în ambele moduri."));
        page.Children.Add(Release("1.0.170", "12.10.2026",
            "Articole / Catalog: pe tile, stocul apare pe punctele de lucru (ex. Agronomie, Ploiești). In Store / On Line rămân etichete de preț, nu de stoc."));
        page.Children.Add(Release("1.0.169", "12.10.2026",
            "Gestiune Nectarie: promo Granini 0.33 (SGR / arome) se unifică automat pe GRANINI 0.33 L la NIR / recepții viitoare."));
        page.Children.Add(Release("1.0.168", "12.10.2026",
            "Gestiune Nectarie: promo Tuborg sticlă 0.33 (SGR) se unifică automat pe BERE TUBORG ST. 0.33 L la NIR / recepții viitoare."));
        page.Children.Add(Release("1.0.167", "12.10.2026",
            "Gestiune Nectarie: promo Tuborg doză 0.5 (SGR) se unifică automat pe BERE TUBORG DOZA 0.5 L la NIR / recepții viitoare."));
        page.Children.Add(Release("1.0.166", "12.10.2026",
            "Nomenclatoare → Articole (și Catalog): pe fiecare tile apare stocul pe punct de lucru (suma gestiunilor legate de locație)."));
        page.Children.Add(Release("1.0.165", "12.10.2026",
            "Gestiune Nectarie: promo Bere Bucur blondă 0.35 (SGR) se unifică automat pe BERE BUCUR BLONDA 0.35 L la NIR / recepții viitoare."));
        page.Children.Add(Release("1.0.164", "12.10.2026",
            "Gestiune Nectarie: promo Carlsberg doză 0.5 (SGR) se unifică automat pe BERE CARLSBERG DOZA 0.5 L la NIR / recepții viitoare."));
        page.Children.Add(Release("1.0.163", "12.10.2026",
            "Gestiune Nectarie: promo Carlsberg 0.33 (SGR) se unifică automat pe articolul din catalog BERE CARLSBERG 0.33 L la NIR / recepții viitoare."));
        page.Children.Add(Release("1.0.162", "12.10.2026",
            "În Setări → e-Factura (SPV), contabilul primește pe email un link valabil 7 zile. Data până la care este autorizat se citește din SPV. Butoane: Prelungește conectarea, Revocă conectarea, Reautorizează SPV."));
        page.Children.Add(Release("1.0.161", "11.10.2026",
            "Cererea de autorizare e-Factura pleacă pe emailul contabilului din aplicație. Nu mai depinde de programul de mail de pe calculator."));
        page.Children.Add(Release("1.0.160", "11.10.2026",
            "În Setări → e-Factura (SPV), emailul contabilului se salvează și cererea de autorizare pornește."));
        page.Children.Add(Release("1.0.159", "11.10.2026",
            "Pe bon se poate plăti și numerar și card: scrieți o sumă, restul se pune pe cealaltă metodă."));
        page.Children.Add(Release("1.0.158", "10.10.2026",
            "Pe bonul fiscal, comutatorul In Store / On line alege prețul din tile-uri. Același preț intră pe bon."));
        page.Children.Add(Release("1.0.157", "10.10.2026",
            "Fiecare articol are Preț vânzare In Store și Preț vânzare On Line. On Line pornește cu prețul de vânzare care exista. La casă se folosește prețul In Store."));
        page.Children.Add(Release("1.0.156", "10.10.2026",
            "Pe bara de jos, încasările Glovo, Bolt și Wolt apar ca G, B și W."));
        page.Children.Add(Release("1.0.155", "10.10.2026",
            "Pe ecranul de vânzare, bonul fiscal din dreapta ocupă toată înălțimea. Barele de sus și de jos se opresc la bon."));
        page.Children.Add(Release("1.0.154", "10.10.2026",
            "La vânzare, stocul nu se mai scade. Descărcarea de gestiune se va stabili separat."));
        page.Children.Add(Release("1.0.153", "09.10.2026",
            "Pe bonul fiscal, discountul de 100% stă imediat sub băutură. Totalul casei de marcat este totalul din aplicație."));
        page.Children.Add(Release("1.0.152", "09.10.2026",
            "Pe bonul fiscal, discountul de 100% al produsului din meniu se scade ca sumă. Totalul casei de marcat rămâne totalul din aplicație."));
        page.Children.Add(Release("1.0.151", "09.10.2026",
            "POS trimite bonul fiscal, factura, raportul X și raportul Z către Datecs FP-700 prin FiscalNet.",
            "La plata cu card, suma pleacă întâi la POS-ul bancar. Bonul se emite după ce banca acceptă, cu numărul întors de imprimantă."));
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
        page.Children.Add(new TextBlock { Text = "Urmează în 1.0.285", FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy), Margin = new Avalonia.Thickness(0, 8, 0, 0) });
        page.Children.Add(Bullet("BINA Smart Business: stabilizare listă Rapoarte Z în perioadă și descărcare batch PDF-uri în română (validare finală)."));
        page.Children.Add(Bullet("Extragere Rapoarte Z: conectori Memgest, BOCP și Generic HTTP (pe lângă BINA)."));
        page.Children.Add(Bullet("Preluare BF din BINA: import linii detaliate pe bon (dincolo de sloturile generate din Documente Z)."));
        page.Children.Add(Bullet("e-Factura: încărcare directă ANAF SPV (OAuth) pe lângă canalul contabil."));
        page.Children.Add(Bullet("Manual Ajutor: capturi de ecran reale din modul Registru de casă."));
        page.Children.Add(Bullet("MT940: șabloane suplimentare de parsare extras bancă (formate bănci românești)."));
        page.Children.Add(Bullet("Registru de casă: export direct în folder (ca la Rapoarte Z), fine-tuning pixel-perfect pe model PDF."));
        page.Children.Add(new TextBlock
        {
            Text = "ERP Mobile · DATECONTA.RO · 13 octombrie 2026",
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
