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

    public HelpManualPage(AppSession session)
    {
        HorizontalAlignment = HorizontalAlignment.Stretch;
        VerticalAlignment = VerticalAlignment.Stretch;
        var language = session.Profile?.PreferredLanguage ?? "ro";
        Content = Build(language.StartsWith("en", StringComparison.OrdinalIgnoreCase) ? "en" : "ro");
    }

    static Control Build(string language)
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
                ["help.section_pos_b1", "help.section_pos_b2", "help.section_pos_b3", "help.section_pos_b4", "help.section_pos_b5", "help.section_pos_b6", "help.section_pos_b7", "help.section_pos_b8", "help.section_pos_b9", "help.section_pos_b10", "help.section_pos_b11", "help.section_pos_b12", "help.section_pos_b13", "help.section_pos_b14", "help.section_pos_b15", "help.section_pos_b16", "help.section_pos_b17", "help.section_pos_b18", "help.section_pos_b19", "help.section_pos_b20", "help.section_pos_b21"],
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
