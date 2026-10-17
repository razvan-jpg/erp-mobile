using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class HelpManualPage : UserControl
{
    static readonly Dictionary<string, Bitmap> Screenshots = new();
    readonly bool _station;
    readonly bool _english;
    readonly string _language;

    public HelpManualPage(AppSession session)
    {
        HorizontalAlignment = HorizontalAlignment.Stretch;
        VerticalAlignment = VerticalAlignment.Stretch;
        _language = session.Profile?.PreferredLanguage ?? "ro";
        _english = _language.StartsWith("en", StringComparison.OrdinalIgnoreCase);
        _station = session.IsStationCashier;
        ShowManual();
    }

    void ShowManual() => Content = _station ? StationManual() : Build(_english ? "en" : "ro");

    Control StationManual()
    {
        var page = new StackPanel { Margin = new Thickness(24), Spacing = 22, MaxWidth = 820 };
        page.Children.Add(new TextBlock
        {
            Text = "Apasati un buton. Textul se deschide aici.",
            FontSize = 20,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            TextWrapping = TextWrapping.Wrap
        });
        page.Children.Add(new TextBlock
        {
            Text = "Press a button. The text opens here.",
            FontSize = 20,
            Foreground = Brand.Brush(Brand.Muted),
            TextWrapping = TextWrapping.Wrap
        });
        page.Children.Add(LegalButtons(large: true));
        for (var i = 0; i < Lessons.Length; i++)
        {
            var lesson = Lessons[i];
            page.Children.Add(new TextBlock
            {
                Text = (i + 1) + ".",
                FontSize = 22,
                FontWeight = FontWeight.Bold,
                Foreground = Brand.Brush(Brand.Gold)
            });
            page.Children.Add(new TextBlock
            {
                Text = lesson.Ro,
                FontSize = 20,
                FontWeight = FontWeight.SemiBold,
                Foreground = Brand.Brush(Brand.Navy),
                TextWrapping = TextWrapping.Wrap
            });
            page.Children.Add(new TextBlock
            {
                Text = lesson.En,
                FontSize = 20,
                Foreground = Brand.Brush(Brand.Muted),
                TextWrapping = TextWrapping.Wrap
            });
            var shot = Screenshot(lesson.Image);
            if (shot != null)
                page.Children.Add(shot);
        }
        return new ScrollViewer { Content = page };
    }

    Control Build(string language)
    {
        var strings = LoadMap(language + ".json");
        if (strings.Count == 0)
        {
            return new TextBlock
            {
                Margin = new Thickness(24),
                Text = "Manualul de utilizare nu a putut fi încărcat.",
                TextWrapping = TextWrapping.Wrap
            };
        }

        string T(string key) => strings.TryGetValue(key, out var value) ? value : "";
        string F(string key, string arg)
        {
            var template = T(key);
            var at = template.IndexOf("%@", StringComparison.Ordinal);
            return at < 0 ? template : template.Remove(at, 2).Insert(at, arg);
        }

        var versionLabel = Brand.Version + " (Build: " + Brand.Build + ")";
        var sections = ErpSections(T);
        sections.AddRange(ZettaSections(F));

        var page = new StackPanel { Spacing = 16, MaxWidth = 760, Margin = new Thickness(24, 20, 24, 32) };
        var anchors = new Dictionary<string, Control>();

        page.Children.Add(LegalButtons(large: false));
        page.Children.Add(new TextBlock
        {
            Text = T("help.page_title"),
            FontSize = 28,
            FontWeight = FontWeight.Bold,
            Foreground = Brand.Brush(Brand.Navy),
            TextWrapping = TextWrapping.Wrap
        });
        page.Children.Add(new TextBlock
        {
            Text = T("help.subtitle"),
            FontSize = 14,
            Foreground = Brand.Brush(Brand.Muted),
            TextWrapping = TextWrapping.Wrap
        });
        page.Children.Add(new TextBlock
        {
            Text = F("help.installed_version", versionLabel),
            FontSize = 12,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brushes.Red
        });
        page.Children.Add(new TextBlock { Text = T("help.last_updated"), FontSize = 12, Foreground = Brand.Brush(Brand.Muted) });

        var tocCard = Card();
        var tocBody = new StackPanel { Spacing = 4 };
        tocBody.Children.Add(new TextBlock
        {
            Text = T("help.toc"),
            FontSize = 16,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            Margin = new Thickness(0, 0, 0, 6)
        });
        tocCard.Child = tocBody;
        anchors["toc"] = tocCard;
        page.Children.Add(tocCard);

        foreach (var section in sections)
        {
            var target = section;
            var link = TocButton(target.Title);
            link.Click += (_, _) =>
            {
                if (anchors.TryGetValue(target.Id, out var card))
                    card.BringIntoView();
            };
            tocBody.Children.Add(link);

            var card = Card();
            var body = new StackPanel { Spacing = 10 };
            body.Children.Add(new TextBlock
            {
                Text = target.Title,
                FontSize = 18,
                FontWeight = FontWeight.Bold,
                Foreground = Brand.Brush(Brand.Navy),
                TextWrapping = TextWrapping.Wrap
            });
            foreach (var paragraph in target.Paragraphs)
                body.Children.Add(Paragraph(paragraph));
            foreach (var shot in target.Screenshots)
            {
                var image = Screenshot(shot);
                if (image != null)
                {
                    body.Children.Add(image);
                    body.Children.Add(new TextBlock
                    {
                        Text = T("help.screenshot_caption"),
                        FontSize = 11,
                        Foreground = Brand.Brush(Brand.Muted)
                    });
                }
            }
            foreach (var bullet in target.Bullets)
                body.Children.Add(Bullet(bullet));
            if (!string.IsNullOrWhiteSpace(target.Tip))
                body.Children.Add(Tip(target.Tip));
            var back = TocButton(T("help.back_to_toc"));
            back.Click += (_, _) => tocCard.BringIntoView();
            back.Margin = new Thickness(0, 6, 0, 0);
            body.Children.Add(back);
            card.Child = body;
            anchors[target.Id] = card;
            page.Children.Add(card);
        }

        page.Children.Add(new TextBlock
        {
            Text = F("help.footer", versionLabel),
            FontSize = 12,
            Foreground = Brand.Brush(Brand.Muted),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 8, 0, 0)
        });

        return new ScrollViewer
        {
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Content = page
        };
    }

    static List<HelpSection> ErpSections(Func<string, string> t)
    {
        HelpSection S(string id, string title, string[] paragraphs, string[] bullets, string[] shots, string tip) =>
            new(id, t(title), Texts(t, paragraphs), Texts(t, bullets), shots, t(tip));

        return
        [
            S("intro", "help.section_intro_title", ["help.section_intro_p1", "help.section_intro_p2"],
                ["help.section_intro_b1", "help.section_intro_b2", "help.section_intro_b3", "help.section_intro_b4", "help.section_intro_b5", "help.section_intro_b6", "help.section_intro_b7"],
                ["HelpDashboard"], "help.section_intro_tip"),
            S("login", "help.section_login_title", ["help.section_login_p1", "help.section_login_p2"],
                ["help.section_login_b1", "help.section_login_b2", "help.section_login_b3", "help.section_login_b4"],
                ["HelpDashboard"], "help.section_login_tip"),
            S("dashboard", "help.section_dashboard_title", ["help.section_dashboard_p1", "help.section_dashboard_p2"],
                ["help.section_dashboard_b1", "help.section_dashboard_b2", "help.section_dashboard_b3", "help.section_dashboard_b4", "help.section_dashboard_b5", "help.section_dashboard_b6", "help.section_dashboard_b7", "help.section_dashboard_b8", "help.section_dashboard_b9", "help.section_dashboard_b10"],
                ["HelpDashboard", "HelpCompanyMenu"], "help.section_dashboard_tip"),
            S("pos", "help.section_pos_title", ["help.section_pos_p1", "help.section_pos_p2"],
                ["help.section_pos_b1", "help.section_pos_b2", "help.section_pos_b3", "help.section_pos_b4", "help.section_pos_b5", "help.section_pos_b6", "help.section_pos_b7", "help.section_pos_b8", "help.section_pos_b9", "help.section_pos_b10", "help.section_pos_b11", "help.section_pos_b12", "help.section_pos_b13", "help.section_pos_b14", "help.section_pos_b15", "help.section_pos_b16", "help.section_pos_b17", "help.section_pos_b18", "help.section_pos_b19", "help.section_pos_b20", "help.section_pos_b21", "help.section_pos_b22", "help.section_pos_b23", "help.section_pos_b24", "help.section_pos_b25"],
                [], "help.section_pos_tip"),
            S("company", "help.section_company_title", ["help.section_company_p1", "help.section_company_p2"],
                ["help.section_company_b1", "help.section_company_b2", "help.section_company_b3", "help.section_company_b4"],
                ["HelpCompanyMenu", "HelpStatusBar"], "help.section_company_tip"),
            S("settings", "help.section_settings_title", ["help.section_settings_p1", "help.section_settings_p2"],
                ["help.section_settings_b1", "help.section_settings_b2", "help.section_settings_b3", "help.section_settings_b4", "help.section_settings_b5", "help.section_settings_b6", "help.section_settings_b7", "help.section_settings_b8", "help.section_settings_b9"],
                ["HelpSettings"], "help.section_settings_tip"),
            S("users", "help.section_users_title", ["help.section_users_p1"],
                ["help.section_users_b1", "help.section_users_b2", "help.section_users_b3", "help.section_users_b4"],
                ["HelpUsers"], "help.section_users_tip"),
            S("bulk-delete", "help.section_bulk_delete_title", ["help.section_bulk_delete_p1", "help.section_bulk_delete_p2", "help.section_bulk_delete_p3"],
                ["help.section_bulk_delete_b1", "help.section_bulk_delete_b2", "help.section_bulk_delete_b3", "help.section_bulk_delete_b4", "help.section_bulk_delete_b5", "help.section_bulk_delete_b6", "help.section_bulk_delete_b7", "help.section_bulk_delete_b8", "help.section_bulk_delete_b9", "help.section_bulk_delete_b10"],
                ["HelpSuppliersModule", "HelpClientSituation"], "help.section_bulk_delete_tip"),
            S("nomenclatoare", "help.section_nomenclatoare_title", ["help.section_nomenclatoare_p1", "help.section_nomenclatoare_p2"],
                ["help.section_nomenclatoare_b1", "help.section_nomenclatoare_b2", "help.section_nomenclatoare_b3", "help.section_nomenclatoare_b4", "help.section_nomenclatoare_b5", "help.section_nomenclatoare_b6", "help.section_nomenclatoare_b7", "help.section_nomenclatoare_b8"],
                ["HelpNomenclatoare"], "help.section_nomenclatoare_tip"),
            S("suppliers", "help.section_suppliers_title", ["help.section_suppliers_p1", "help.section_suppliers_p2"],
                ["help.section_suppliers_b1", "help.section_suppliers_b2", "help.section_suppliers_b3", "help.section_suppliers_b4", "help.section_suppliers_b5", "help.section_suppliers_b7", "help.section_suppliers_b8"],
                ["HelpSuppliersModule", "HelpNIR"], "help.section_suppliers_tip"),
            S("clients", "help.section_clients_title", ["help.section_clients_p1", "help.section_clients_p2"],
                ["help.section_clients_b1", "help.section_clients_b2", "help.section_clients_b3", "help.section_clients_b4", "help.section_clients_b6", "help.section_clients_b7"],
                ["HelpClientsModule", "HelpClientSituation"], "help.section_clients_tip"),
            S("inventory", "help.section_inventory_title", ["help.section_inventory_p1", "help.section_inventory_p2"],
                ["help.section_inventory_b1", "help.section_inventory_b2", "help.section_inventory_b3", "help.section_inventory_b4"],
                ["HelpInventory"], "help.section_inventory_tip"),
            S("stock-sheet", "help.section_stock_sheet_title", ["help.section_stock_sheet_p1", "help.section_stock_sheet_p2"],
                ["help.section_stock_sheet_b1", "help.section_stock_sheet_b2", "help.section_stock_sheet_b3", "help.section_stock_sheet_b4"],
                ["HelpInventory"], "help.section_stock_sheet_tip"),
            S("hr", "help.section_hr_title", ["help.section_hr_p1", "help.section_hr_p2"],
                ["help.section_hr_b1", "help.section_hr_b2", "help.section_hr_b3", "help.section_hr_b4", "help.section_hr_b5"],
                ["HelpDashboard"], "help.section_hr_tip"),
            S("crm", "help.section_crm_title", ["help.section_crm_p1", "help.section_crm_p2"],
                ["help.section_crm_b1", "help.section_crm_b2", "help.section_crm_b3", "help.section_crm_b4", "help.section_crm_b5", "help.section_crm_b6", "help.section_crm_b7", "help.section_crm_b8"],
                ["HelpClientsModule", "HelpDashboard"], "help.section_crm_tip"),
            S("cash-register", "help.section_cash_register_title", ["help.section_cash_register_p1", "help.section_cash_register_p2"],
                ["help.section_cash_register_b1", "help.section_cash_register_b2", "help.section_cash_register_b3", "help.section_cash_register_b4", "help.section_cash_register_b5", "help.section_cash_register_b6", "help.section_cash_register_b7", "help.section_cash_register_b8", "help.section_cash_register_b9", "help.section_cash_register_b10"],
                ["HelpUtilitiesCashRegister", "HelpDashboard"], "help.section_cash_register_tip"),
            S("legal", "help.section_legal_title", ["help.section_legal_p1"],
                ["help.section_legal_b1", "help.section_legal_b2", "help.section_legal_b3", "help.section_legal_b4", "help.section_legal_b5"],
                ["HelpStatusBar"], "help.section_legal_tip"),
            S("utilities", "help.section_utilities_title", ["help.section_utilities_p1", "help.section_utilities_p2"],
                ["help.section_utilities_b1", "help.section_utilities_b2", "help.section_utilities_b3", "help.section_utilities_b4", "help.section_utilities_b5", "help.section_utilities_b6", "help.section_utilities_b7", "help.section_utilities_b8", "help.section_utilities_b9", "help.section_utilities_b10", "help.section_utilities_b11"],
                ["HelpUtilitiesMenu", "HelpUtilitiesZetta", "HelpUtilitiesMT940", "HelpUtilitiesCashRegister"], "help.section_utilities_tip"),
            S("zetta-category", "help.section_zetta_category_title", ["help.section_zetta_category_p1", "help.section_zetta_category_p2"],
                ["help.section_zetta_category_b1", "help.section_zetta_category_b2", "help.section_zetta_category_b3", "help.section_zetta_category_b4", "help.section_zetta_category_b5", "help.section_zetta_category_b6"],
                ["HelpClientsModule", "HelpMainScreen"], "help.section_zetta_category_tip"),
        ];
    }

    static List<HelpSection> ZettaSections(Func<string, string, string> format)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Help", "zetta-sections.json");
        if (!File.Exists(path))
            return [];
        var items = JsonSerializer.Deserialize<List<ZettaHelpSection>>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
        return items.Select(item => new HelpSection(
            "zetta-" + item.Id,
            format("help.zetta_section_prefix", item.Title),
            item.Paragraphs,
            item.Bullets,
            item.Screenshots,
            (item.Tip ?? "").Replace("{{version}}", Brand.Version, StringComparison.Ordinal)
        )).ToList();
    }

    static List<string> Texts(Func<string, string> t, IEnumerable<string> keys) =>
        keys.Select(t).Where(text => !string.IsNullOrWhiteSpace(text)).ToList();

    static Dictionary<string, string> LoadMap(string file)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Localization", file);
        if (!File.Exists(path))
            return new Dictionary<string, string>();
        return JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(path)) ?? new Dictionary<string, string>();
    }

    static Border Card() => new()
    {
        Background = Brushes.White,
        BorderBrush = Brand.Brush(Brand.Line),
        BorderThickness = new Thickness(1),
        CornerRadius = new CornerRadius(12),
        Padding = new Thickness(14)
    };

    static Button TocButton(string title) => new()
    {
        Content = new TextBlock { Text = title, TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Navy) },
        Background = Brushes.Transparent,
        BorderThickness = new Thickness(0),
        HorizontalAlignment = HorizontalAlignment.Stretch,
        HorizontalContentAlignment = HorizontalAlignment.Left,
        Padding = new Thickness(2, 4)
    };

    static TextBlock Paragraph(string text) => new()
    {
        Text = text,
        TextWrapping = TextWrapping.Wrap,
        Foreground = Brand.Brush("#243246"),
        FontSize = 14
    };

    static Control Bullet(string text)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("16,*") };
        grid.Children.Add(new TextBlock { Text = "•", FontWeight = FontWeight.Bold, Foreground = Brand.Brush(Brand.Gold) });
        var body = Paragraph(text);
        Grid.SetColumn(body, 1);
        grid.Children.Add(body);
        return grid;
    }

    static Border Tip(string text) => new()
    {
        Background = new SolidColorBrush(Color.FromArgb(26, Brand.Gold.R, Brand.Gold.G, Brand.Gold.B)),
        CornerRadius = new CornerRadius(10),
        Padding = new Thickness(10),
        Child = Paragraph(text)
    };

    Control LegalButtons(bool large)
    {
        var row = new WrapPanel { Orientation = Orientation.Horizontal };
        void Add(string title, string? stem)
        {
            var button = new Button
            {
                Content = title,
                Margin = new Thickness(0, 0, 10, 10),
                Padding = large ? new Thickness(18, 14) : new Thickness(12, 6),
                FontSize = large ? 18 : 14,
                Background = Brushes.White,
                Foreground = Brand.Brush(Brand.Navy),
                BorderBrush = Brand.Brush(Brand.Line),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(8)
            };
            button.Click += (_, _) => ShowDocument(title, stem);
            row.Children.Add(button);
        }
        Add("Privacy", "privacy-policy");
        Add("Termeni  /  Terms", "terms-of-service");
        Add("Politica GDPR", "gdpr-policy");
        Add("Despre  /  About", null);
        return row;
    }

    void ShowDocument(string title, string? stem)
    {
        var page = new StackPanel { Margin = new Thickness(24), Spacing = 16, MaxWidth = 820 };
        var back = new Button
        {
            Content = "Inapoi  /  Back",
            HorizontalAlignment = HorizontalAlignment.Left,
            Padding = new Thickness(18, 12),
            FontSize = 18,
            Background = Brushes.White,
            Foreground = Brand.Brush(Brand.Navy),
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8)
        };
        back.Click += (_, _) => ShowManual();
        page.Children.Add(back);
        page.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 24,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            TextWrapping = TextWrapping.Wrap
        });
        if (stem == null)
        {
            page.Children.Add(Paragraph(AboutText(false)));
            page.Children.Add(Paragraph(AboutText(true)));
        }
        else if (_station)
        {
            page.Children.Add(Paragraph(LegalText(stem, false)));
            page.Children.Add(Paragraph(LegalText(stem, true)));
        }
        else
            page.Children.Add(Paragraph(LegalText(stem, _english)));
        Content = new ScrollViewer { Content = page };
    }

    static string LegalText(string stem, bool english)
    {
        var code = english ? "en" : "ro";
        var path = Path.Combine(AppContext.BaseDirectory, "Legal", stem + "-" + code + ".txt");
        if (!File.Exists(path) && english)
            path = Path.Combine(AppContext.BaseDirectory, "Legal", stem + "-ro.txt");
        return File.Exists(path) ? File.ReadAllText(path) : titleMissing(stem);
    }

    static string titleMissing(string stem) => "Documentul nu a putut fi încărcat: " + stem;

    static string AboutText(bool english)
    {
        var version = Brand.Version + " (Build: " + Brand.Build + ")";
        if (english)
            return "ERP Mobile\n\nDeveloper - Razvan IVAN\n\nApp version: " + version + "\n\nDatabase engine: SUPABASE";
        return "ERP Mobile\n\nDezvoltator - Razvan IVAN\n\nVersiune aplicatie: " + version + "\n\nMotor baza de date: SUPABASE";
    }

    static Image? Screenshot(string name)
    {
        if (!Screenshots.TryGetValue(name, out var bitmap))
        {
            var path = Path.Combine(AppContext.BaseDirectory, "HelpScreenshots", name + ".png");
            if (!File.Exists(path))
                return null;
            using var full = new Bitmap(path);
            var width = Math.Min(full.PixelSize.Width, 900);
            var height = Math.Max(1, (int)Math.Round(full.PixelSize.Height * (width / (double)full.PixelSize.Width)));
            bitmap = full.CreateScaledBitmap(new PixelSize(width, height));
            Screenshots[name] = bitmap;
        }
        return new Image
        {
            Source = bitmap,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
    }

    static readonly (string Ro, string En, string Image)[] Lessons =
    [
        ("Pe ecranul casierului sunt trei patrate mari. Ca sa vindeti, apasati patratul rosu pe care scrie POS. Nu apasati altceva.", "On the cashier screen there are three big squares. To sell, press the red square that says POS. Do not press anything else.", "HelpCashier01"),
        ("Se deschid grupele de produse. Apasati o singura grupa, de exemplu Shaorma sau Bauturi. Produsele din grupa aceea apar pe ecran.", "The product groups open. Press one group only, for example Shaorma or Drinks. The products from that group appear on the screen.", "HelpCashier02"),
        ("Apasati o data pe produs. El intra pe bon cu cantitatea 1. Daca clientul vrea doua, apasati inca o data. Ca sa va intoarceti la grupe, apasati Inapoi la grupe.", "Press the product once. It goes on the receipt with quantity 1. If the customer wants two, press it once more. To go back to the groups, press Back to groups.", "HelpCashier03"),
        ("Daca ati pus un produs din greseala, uitati-va pe bon, la randul acela. Apasati × de pe rand. Butonul este mai mare, ca sa il apasati usor. Produsul iese de pe bon. Daca produsul avea garantie SGR, garantia iese odata cu el. Nu cautati SGR separat.", "If you put a product on the receipt by mistake, look at that line. Press the × on the line. The button is larger, so it is easy to press. The product leaves the receipt. If the product had an SGR deposit, the deposit leaves with it. Do not look for SGR on its own.", "HelpCashier04"),
        ("Daca firma cere CUI pe bon, apasati campul pe care scrie CUI client, optional. Scrieti numarul. Programul intreaba ANAF si scrie singur numele firmei. Daca numele nu este cel bun, apasati Fara CUI sau Corecteaza. Daca firma este inactiva sau radiata, bonul nu se emite. Fara CUI, bonul se emite normal.", "If the company wants a tax number on the receipt, press the field that says CUI client, optional. Type the number. The program asks ANAF and writes the company name by itself. If the name is wrong, press Without CUI or Correct. If the company is inactive or struck off, the receipt will not be issued. Without a CUI, the receipt is issued as usual.", "HelpCashier05"),
        ("Ca sa scoateti si factura odata cu bonul, bifati casuta Tipareste si factura fiscala. Butonul mare se schimba si scrie Emite bon si FF. Apasati-l. Intai iese bonul fiscal. Dupa el iese factura fiscala. Nu apasati de doua ori.", "To print the invoice together with the receipt, tick the box Print a fiscal invoice too. The big button changes and says Issue receipt and FF. Press it. The fiscal receipt comes out first. The fiscal invoice comes out after it. Do not press twice.", "HelpCashier06"),
        ("Daca nu vreti factura, lasati casuta nebifata. Butonul scrie Emite bon. Apasati-l. Iese numai bonul.", "If you do not want an invoice, leave the box unticked. The button says Issue receipt. Press it. Only the receipt comes out.", "HelpCashier07"),
        ("In magazin, apasati In Store. Pretul este pretul din magazin. Apoi alegeti cum plateste clientul. La Numerar scrieti cati bani v-a dat. Programul calculeaza restul si il arata la Rest. Daca banii sunt mai putini decat totalul, programul va spune si nu emite bonul.", "In the shop, press In Store. The price is the shop price. Then choose how the customer pays. For Cash, type how much money they gave you. The program works out the change and shows it at Change. If the money is less than the total, the program tells you and does not issue the receipt.", "HelpCashier08"),
        ("La Card nu scrieti nicio suma. Apasati Card. POS-ul de card incaseaza tot totalul. Apoi apasati Emite bon.", "For Card, do not type any amount. Press Card. The card machine takes the whole total. Then press Issue receipt.", "HelpCashier09"),
        ("La Numerar + Card scrieti o singura suma: ori numerarul, ori cardul. Programul pune restul pe cealalta metoda. Nu scrieti amandoua. Daca suma scrisa este mai mare decat totalul, programul va opreste.", "For Cash + Card, type one amount only: either the cash or the card. The program puts the rest on the other method. Do not type both. If the amount you typed is bigger than the total, the program stops you.", "HelpCashier10"),
        ("Pentru Glovo, Bolt sau Wolt apasati On line. Pretul este pretul de online, nu pretul din magazin. Plata este numai Moderna. Apasati Moderna, apoi apasati Glovo, Bolt sau Wolt. Trebuie sa alegeti una. Fara alegere, bonul nu se emite. In magazin nu folositi Moderna.", "For Glovo, Bolt or Wolt, press On line. The price is the online price, not the shop price. Payment is only Modern. Press Modern, then press Glovo, Bolt or Wolt. You must choose one. Without a choice, the receipt is not issued. In the shop, do not use Modern.", "HelpCashier11"),
        ("Puteti tine deschise pana la 4 bonuri. Sus sunt numerele 1, 2, 3 si 4. Apasati + ca sa deschideti inca un bon. Apasati numarul ca sa va intoarceti la bonul acela. × inchide numai un bon gol, pe care nu este niciun produs. Un bon care are produse nu se inchide cu ×. Intai emiteti-l sau stergeti produsele cu × de pe rand.", "You can keep up to 4 receipts open. At the top are the numbers 1, 2, 3 and 4. Press + to open another receipt. Press the number to go back to that receipt. × closes only an empty receipt, with no product on it. A receipt that has products does not close with ×. First issue it, or delete the products with the × on the line.", "HelpCashier12"),
        ("Ziua nu se inchide cat timp mai este un bon cu produse pe el. Apasati Raport Z numai dupa ce toate bonurile sunt emise sau golite. Daca mai este un bon cu articole, programul va opreste si scrie: Nu puteti inchide ziua. Mai sunt bonuri cu articole. Emiteti-le sau stergeti articolele, apoi apasati Raport Z. Dupa Raport Z tura se inchide si foaia de stoc se salveaza. Sus, inainte de Raport X, sunt + Numerar si - Numerar. + Numerar baga bani in casa. - Numerar scoate bani din casa. Scrieti suma pe tastatura numerica si apasati OK. Casa primeste banii. In fata lor este Raport Produse. Lista se deschide peste ecranul POS, in fereastra aplicatiei. Casierul o vede si fara drepturi de administrator. Alegeti Z-ul. Primul este Z-ul curent: In lucru - Neinchis. Vedeti produsele vandute, pe grupe, cu cantitatea, pretul de vanzare si totalul liniei. Garantia SGR este grupa ei. Fiecare grupa are subtotal, iar la final este totalul general. Butonul Print listeaza lista pe casa de marcat. Inapoi va intoarce la lista. Inchide inchide fereastra.", "The day does not close while a receipt still has products on it. Press Report Z only after every receipt is issued or emptied. If a receipt still has articles, the program stops you and writes: You cannot close the day. Receipts still have articles. Issue them or delete the articles, then press Report Z. After Report Z the shift closes and the stock sheet is saved. At the top, before Report X, there are + Cash and - Cash. + Cash puts money into the register. - Cash takes money out of the register. Type the amount on the numeric keypad and press OK. The register receives the money. In front of them is Product report. The list opens over the POS screen, inside the application window. The cashier sees it without administrator rights. Choose the Z. The first is the current Z: In progress - Not closed. You see the products sold, by group, with the quantity, the sale price and the line total. The SGR deposit is its own group. Each group has a subtotal, and the report ends with the grand total. The Print button lists it on the cash register. Back returns to the list. Close closes the window.", "HelpCashier13"),
        ("Ca sa faceti bonuri de productie, de transfer sau de consum, iesiti din POS si apasati patratul verde Productie. Acolo sunt trei butoane: Bon productie, Bon transfer si Bon consum. Apasati butonul de care aveti nevoie.", "To make production notes, transfer notes or consumption notes, leave POS and press the green square Production. There are three buttons: Production note, Transfer note and Consumption note. Press the button you need.", "HelpCashier14"),
        ("Exemplu: ati facut tepe de pui. Apasati Bon productie, apoi Bon productie nou. Alegeti DONER PUI. Reteta este inregistrata pentru 1 kg de DONER PUI. Nu scrieti 1. Scrieti toata cantitatea pe care ati facut-o. Daca ati facut 12 kg, scrieti 12. Pe Windows, la cantitate se deschide tastatura numerica. Programul scoate din stoc materiile pentru toti cei 12 kg.", "Example: you made chicken skewers. Press Production note, then New production note. Choose DONER PUI. The recipe is registered for 1 kg of DONER PUI. Do not type 1. Type the whole quantity you made. If you made 12 kg, type 12. On Windows, the quantity opens a numeric keypad. The program takes from stock the materials for all 12 kg.", "HelpCashier15"),
        ("Dupa bonul de productie faceti bonul de transfer pentru marfa care pleaca. Apasati Bon transfer, apoi Bon transfer nou. Daca alegeti Ploiești, destinatia se completeaza cu Agronomie, si invers. In lista intra si produsele finite, de exemplu DONER PUI. Cantitatea se scrie in campul galben de sub articol, sau apasati 123. Bonul se salveaza si daca stocul devine negativ. Pe bon treceti numai ce pleaca, nu tot ce ati produs daca o parte ramane la voi.", "After the production note, make the transfer note for the goods that leave. Press Transfer note, then New transfer note. If you pick Ploiești, the destination fills with Agronomie, and the other way around. Finished goods are in the list, for example DONER PUI. Type the quantity in the yellow field under the article, or press 123. The note is saved even if stock goes negative. On the note put only what leaves, not everything you produced if some of it stays with you.", "HelpCashier16"),
        ("La Raport Z programul face singur unele bonuri de productie, din vanzarile de pe bonurile fiscale. Cu acelea nu aveti treaba. Nu le cautati si nu le mai faceti o data. Voi faceti numai bonul de productie pentru ce ati preparat voi, cum este DONER PUI, si bonul de transfer pentru ce pleaca la Agronomie. Consumul urmeaza reteta si cand cantitatea este foarte mica. Stocul poate ajunge negativ, iar inchiderea nu se opreste din cauza asta. Daca dupa listarea Z-ului apare o eroare, apasati din nou Raport Z: casa nu mai listeaza, se salveaza foaia si se golesc incasarile.", "At Report Z the program makes some production notes by itself, from the sales on the fiscal receipts. Those are not your job. Do not look for them and do not make them again. You only make the production note for what you prepared yourselves, such as DONER PUI, and the transfer note for what leaves for Agronomie. Consumption follows the recipe even when the quantity is very small. Stock can go negative, and the close does not stop because of that. If an error appears after the Z is printed, press Report Z again: the register does not print again, the sheet is saved and the takings go back to 0.", "HelpCashier17"),
        ("Bonul de consum se face cand marfa iese si nu se vinde: protocol, rebut, marfa deteriorata si alte motive de acelasi fel. Apasati Bon consum, apoi Bon consum nou. Dupa data alegeti tura: 1 - ziua sau 2 - noapte. Dupa aprobare, consumul scade din foaia de stoc a acelei date si a acelei ture. Sus scrieti motivul. Pe un bon este un singur motiv. Nu puteti pune pe acelasi bon si protocol si rebut, pentru ca nu aveti decat un singur loc unde se scrie motivul. Faceti un bon pentru protocol si alt bon pentru rebut.", "A consumption note is made when goods leave and are not sold: protocol, scrap, damaged goods and other reasons of the same kind. Press Consumption note, then New consumption note. After the date, choose the shift: 1 - day or 2 - night. After approval, the consumption is taken from the stock sheet of that date and that shift. At the top, write the reason. One note has one reason only. You cannot put protocol and scrap on the same note, because there is only one place where the reason is written. Make one note for protocol and another note for scrap.", "HelpCashier18"),
        ("Apasati Adauga produs. Ca sa gasiti articolul, filtrati dupa categorie, denumire, cod sau cod de bare. Alegeti articolul. Sub el scrieti cantitatea. Pe Windows, la cantitate se deschide tastatura numerica. Daca ati gresit articolul, apasati Sterge pe randul lui. Motivul este obligatoriu. Trebuie cel putin un articol, iar la fiecare articol trebuie scrisa cantitatea. Fara motiv sau fara cantitate, bonul nu se salveaza.", "Press Add product. To find the article, filter by category, name, code or barcode. Choose the article. Under it, type the quantity. On Windows, the quantity opens a numeric keypad. If you chose the wrong article, press Delete on its line. The reason is required. There must be at least one article, and every article must have a quantity. Without a reason or without a quantity, the note is not saved.", "HelpCashier19"),
        ("Cand salvati bonul de consum, stocul nu scade. Salvarea nu este de ajuns. Un manager trebuie sa il aprobe. Managerul poate aproba tot bonul, cu Aproba bonul, sau numai liniile bifate, cu Salveaza aprobarea pe linii. Numai liniile aprobate ies din stoc. In lista vedeti Neaprobat, Aprobat partial sau Aprobat. Dupa aprobare nu mai puteti modifica sau sterge bonul. Managerul il poate redeschide.", "When you save the consumption note, stock does not go down. Saving is not enough. A manager must approve it. The manager can approve the whole note, with Approve the note, or only the ticked lines, with Save line approval. Only the approved lines leave the stock. In the list you see Not approved, Partially approved or Approved. After approval you can no longer change or delete the note. The manager can reopen it.", "HelpCashier20"),
        ("Daca foaia de stoc a fost deja emisa si apoi se aproba un bon de consum, programul reface foile de stoc de la data bonului pana la ultima foaie emisa. La fel se intampla daca managerul redeschide sau sterge un bon deja aprobat. Voi nu recalculati nimic. Programul o face cand managerul aproba.", "If the stock sheet was already issued and a consumption note is approved afterwards, the program redoes the stock sheets from the note date through the last issued sheet. The same happens if the manager reopens or deletes a note that was already approved. You do not recalculate anything. The program does it when the manager approves.", "HelpCashier21"),
        ("Foaia de stoc o vedeti pe patratul albastru Foaie stoc. Acolo sunt numai foile punctului vostru de lucru. Foaia se creeaza cand apasati Raport Z. Daca o cantitate de la inchidere nu se potriveste cu depozitul, randul este rosu. Voi nu scrieti foaia de mana.", "You see the stock sheet on the blue square Stock sheet. Only the sheets of your work location are there. The sheet is created when you press Report Z. If a closing quantity does not match the warehouse, the row is red. You do not write the sheet by hand.", "HelpCashier22"),
        ("Sus, in Ajutor, sunt patru butoane: Privacy, Termeni, Politica GDPR si Despre aplicatie. Apasati unul. Textul se deschide pe acelasi ecran. Ca sa va intoarceti la lectii, apasati Inapoi.", "At the top of Help there are four buttons: Privacy, Terms, GDPR policy and About the app. Press one. The text opens on the same screen. To come back to the lessons, press Back.", "HelpCashier23"),
    ];

    sealed record HelpSection(string Id, string Title, IReadOnlyList<string> Paragraphs, IReadOnlyList<string> Bullets, IReadOnlyList<string> Screenshots, string Tip);

    sealed class ZettaHelpSection
    {
        public string Id { get; set; } = "";
        public string Title { get; set; } = "";
        public List<string> Paragraphs { get; set; } = [];
        public List<string> Bullets { get; set; } = [];
        public List<string> Screenshots { get; set; } = [];
        public string? Tip { get; set; }
    }
}
