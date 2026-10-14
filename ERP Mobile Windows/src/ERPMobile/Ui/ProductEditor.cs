using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class ProductEditor : Window
{
    private static readonly HttpClient Http = new();
    private static readonly string[] StockUnits = ["Buc.", "Kg", "Litru"];
    private static readonly (string Code, string Label)[] Categories =
    [
        ("marfa", "Marfă"),
        ("materie_prima", "Materie primă"),
        ("produs_finit", "Produs finit"),
        ("ambalaj", "Ambalaj"),
        ("materiale_consumabile", "Materiale consumabile"),
        ("materiale_curatenie", "Materiale curățenie"),
        ("birotica", "Birotică"),
        ("servicii", "Servicii"),
        ("garantie", "Garanție")
    ];
    private static readonly (string Code, string Label)[] PurchaseUnits =
    [
        ("", "Aceeași ca la stoc (fără conversie)"),
        ("bax", "bax"),
        ("cutie", "cutie"),
        ("ladă", "ladă"),
        ("palet", "palet"),
        ("pachet", "pachet"),
        ("sac", "sac"),
        ("bidon", "bidon"),
        ("set", "set"),
        ("__other__", "Alta…")
    ];

    private readonly AppSession _session;
    private readonly string _productId;
    private readonly string _companyId;
    private readonly StackPanel _page = new() { Spacing = 8, Margin = new Avalonia.Thickness(20), MaxWidth = 640 };
    private readonly TextBlock _status = new() { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
    private readonly Image _photo = new() { Height = 220, Stretch = Stretch.Uniform };
    private readonly TextBlock _noPhoto = new()
    {
        Text = "Nu există poză pentru acest articol.",
        Foreground = Brand.Brush(Brand.Muted),
        HorizontalAlignment = HorizontalAlignment.Center,
        VerticalAlignment = VerticalAlignment.Center,
        TextWrapping = TextWrapping.Wrap,
        TextAlignment = TextAlignment.Center,
        Margin = new Avalonia.Thickness(16)
    };
    private readonly Button _removePhoto = new() { Content = "Elimină poza", HorizontalAlignment = HorizontalAlignment.Left, IsVisible = false };
    private readonly TextBox _name = new();
    private readonly TextBox _code = new();
    private readonly TextBox _barcode = new();
    private readonly ComboBox _category = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ComboBox _stockUnit = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ComboBox _purchaseUnit = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly TextBox _purchaseCustom = new() { Watermark = "UM de pe factură" };
    private readonly TextBlock _factorLabel = new() { Foreground = Brand.Brush(Brand.Muted), FontSize = 12 };
    private readonly TextBox _factor = new() { Text = "1" };
    private readonly StackPanel _factorRow = new() { Spacing = 4 };
    private readonly TextBox _minStock = new() { Text = "0", Watermark = "0 = fără prag" };
    private readonly TextBox _optimalStock = new() { Text = "0", Watermark = "0 = nesetat" };
    private readonly StackPanel _minStockRow = new() { Spacing = 4 };
    private readonly StackPanel _optimalStockRow = new() { Spacing = 4 };
    private readonly ComboBox _vat = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly TextBox _price = new();
    private readonly TextBox _onlinePrice = new();
    private readonly TextBox _purchasePrice = new() { Watermark = "fără TVA" };
    private readonly CheckBox _inCatalog = new() { Content = "Folosit în catalog" };
    private readonly CheckBox _inStockSheet = new() { Content = "Folosit în Foaie stoc" };
    private readonly CheckBox _hasRecipe = new() { Content = "Are rețetă" };
    private readonly StackPanel _groups = new() { Spacing = 4 };
    private readonly StackPanel _addons = new() { Spacing = 4 };
    private readonly StackPanel _recipe = new() { Spacing = 4 };
    private int _recipeGeneration;
    private readonly List<(string Id, CheckBox Box)> _groupBoxes = new();
    private HashSet<string> _initialGroups = new(StringComparer.OrdinalIgnoreCase);
    private string? _imagineUrl;
    private bool _saved;
    private bool _vatPayer = true;
    private bool _loading = true;

    private ProductEditor(AppSession session, string productId, string companyId)
    {
        _session = session;
        _productId = productId;
        _companyId = companyId;
        Title = "Fișa articolului";
        Width = 680;
        Height = 860;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Icon = Brand.WindowIcon();
        Background = Brand.Brush(Brand.Page);
        Build();
        Opened += async (_, _) => await Load();
    }

    public static async Task<bool> Edit(Control owner, AppSession session, string productId)
    {
        if (session.CurrentCompany == null)
            return false;
        var window = new ProductEditor(session, productId, session.CurrentCompany.Id.ToString());
        if (TopLevel.GetTopLevel(owner) is Window parent)
            await window.ShowDialog(parent);
        return window._saved;
    }

    private void Build()
    {
        AddHeading("Imagine articol");
        var frame = new Border
        {
            Height = 220,
            Background = Brushes.White,
            CornerRadius = new Avalonia.CornerRadius(12),
            ClipToBounds = true
        };
        var photoHost = new Grid();
        photoHost.Children.Add(_noPhoto);
        photoHost.Children.Add(_photo);
        frame.Child = photoHost;
        _page.Children.Add(frame);
        var pick = new Button { Content = "Alege din fișier", HorizontalAlignment = HorizontalAlignment.Left };
        pick.Click += async (_, _) => await PickImage();
        _removePhoto.Click += async (_, _) => await RemoveImage();
        var photoButtons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        photoButtons.Children.Add(pick);
        photoButtons.Children.Add(_removePhoto);
        _page.Children.Add(photoButtons);

        AddHeading("Categoria articolului");
        foreach (var (code, label) in Categories)
            _category.Items.Add(new FieldChoice(code, label));
        _category.SelectionChanged += (_, _) =>
        {
            if (_loading)
                return;
            if (SelectedCode(_category) == "produs_finit")
                _inCatalog.IsChecked = true;
        };
        _page.Children.Add(_category);

        AddHeading("Date articol");
        AddField("Denumire", _name);
        AddField("Cod", _code);
        AddField("Cod bare", _barcode);
        foreach (var unit in StockUnits)
            _stockUnit.Items.Add(new FieldChoice(unit, unit));
        _stockUnit.SelectionChanged += (_, _) => RefreshFactor();
        AddField("UM vânzare / consum", _stockUnit);
        _page.Children.Add(Hint("Vânzare doar la bucată. Consum (rețete, bucătărie) doar în Kg sau Litru."));
        foreach (var (code, label) in PurchaseUnits)
            _purchaseUnit.Items.Add(new FieldChoice(code, label));
        _purchaseUnit.SelectionChanged += (_, _) => RefreshFactor();
        AddField("UM achiziție (factură)", _purchaseUnit);
        _purchaseCustom.TextChanged += (_, _) => RefreshFactor();
        _page.Children.Add(_purchaseCustom);
        _factorRow.Children.Add(_factorLabel);
        _factorRow.Children.Add(_factor);
        _page.Children.Add(_factorRow);
        _page.Children.Add(Hint("Furnizorii facturează des pe bax, cutie sau ladă. Completați UM achiziție și factorul, de ex. 1 bax = 24 Buc. NIR-ul și stocul rămân în UM de vânzare/consum."));

        AddHeading("Stoc minim și optim");
        _minStockRow.Children.Add(new TextBlock { Text = "Stoc minim (UM articol)", FontSize = 12, Foreground = Brand.Brush(Brand.Muted) });
        _minStockRow.Children.Add(_minStock);
        _page.Children.Add(_minStockRow);
        _optimalStockRow.Children.Add(new TextBlock { Text = "Stoc optim (UM articol)", FontSize = 12, Foreground = Brand.Brush(Brand.Muted) });
        _optimalStockRow.Children.Add(_optimalStock);
        _page.Children.Add(_optimalStockRow);
        _page.Children.Add(Hint("Când stocul scade sub minim (inclusiv stoc negativ), articolul apare la Necesar comandă. Cantitatea de comandat este stocul optim minus stocul real. Birotica nu intră automat. 0 = fără prag. Nu se aplică la produs finit."));
        _category.SelectionChanged += (_, _) => RefreshMinStockVisibility();

        AddHeading("Prețuri");
        foreach (var rate in new[] { "0", "11", "21" })
            _vat.Items.Add(new FieldChoice(rate, rate + "%"));
        AddField("Cotă TVA", _vat);
        AddField("Preț vânzare In Store (inclusiv TVA)", _price);
        AddField("Preț vânzare On Line (inclusiv TVA)", _onlinePrice);
        AddField("Preț achiziție (fără TVA)", _purchasePrice);
        _page.Children.Add(Hint("Prețul afișat pe raft include TVA."));
        _page.Children.Add(Hint("Prețul de achiziție este fără TVA, pe unitatea articolului. Se actualizează la fiecare factură furnizor și la fiecare NIR. Îl poți modifica."));
        _page.Children.Add(Hint("Alegeți cota TVA: 0%, 11% (ex. produse alimentare) sau 21%."));

        AddHeading("Catalog, Foaie stoc și rețetă");
        _page.Children.Add(_inCatalog);
        _page.Children.Add(_inStockSheet);
        _page.Children.Add(_hasRecipe);

        AddHeading("Grupa CM");
        _page.Children.Add(_groups);
        _page.Children.Add(Hint("Alegeți 1 sau 2 grupe în care produsul apare la vânzarea pe casă marcat."));

        AddHeading("Produse adiționale (bon)");
        _page.Children.Add(_addons);
        _page.Children.Add(Hint("La vânzarea acestui produs pe casă, fiecare adițional apare ca linie separată pe bonul fiscal."));

        AddHeading("Rețetă (materii prime)");
        var copyRecipe = new Button
        {
            Content = "Copiază rețetă",
            HorizontalAlignment = HorizontalAlignment.Left,
            Padding = new Avalonia.Thickness(12, 6)
        };
        copyRecipe.Click += async (_, _) => await ShowCopyRecipe();
        _page.Children.Add(copyRecipe);
        _page.Children.Add(Hint("Alegi produsul finit de la care se copiază rețeta. Liniile ajung pe articolul curent și le poți modifica."));
        _page.Children.Add(_recipe);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8, Margin = new Avalonia.Thickness(0, 12, 0, 0) };
        var cancel = new Button { Content = "Renunță", Padding = new Avalonia.Thickness(12, 6) };
        var save = new Button { Content = "Salvează", Padding = new Avalonia.Thickness(12, 6), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White };
        cancel.Click += (_, _) => Close(false);
        save.Click += async (_, _) => await Save();
        buttons.Children.Add(cancel);
        buttons.Children.Add(save);
        _page.Children.Add(buttons);
        _page.Children.Add(_status);
        Content = new ScrollViewer { Content = _page };
    }

    private async Task Load()
    {
        _status.Text = "Se încarcă...";
        _status.Foreground = Brand.Brush(Brand.Muted);
        try
        {
            var rows = await _session.SelectRows("products", "id=eq." + _productId + "&select=*");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                _status.Text = "Articolul nu mai există.";
                _status.Foreground = Brushes.Firebrick;
                return;
            }
            var row = rows[0];
            _name.Text = Text(row, "denumire");
            _code.Text = Text(row, "cod");
            _barcode.Text = Text(row, "cod_bare");
            Select(_category, Text(row, "tip"), Categories[0].Code);
            SelectUnit(_stockUnit, Text(row, "unitate_masura"), "Buc.");
            SelectPurchase(Text(row, "unitate_achizitie"));
            _minStock.Text = StockAmount(row, "cantitate_minima", "0");
            _optimalStock.Text = StockAmount(row, "cantitate_optima", "0");
            RefreshMinStockVisibility();
            _factor.Text = Amount(row, "factor_conversie", "1");
            _price.Text = Amount(row, "pret_vanzare", "0");
            _onlinePrice.Text = Amount(row, "pret_vanzare_online", Amount(row, "pret_vanzare", "0"));
            _purchasePrice.Text = Amount(row, "pret_achizitie", "");
            _inCatalog.IsChecked = Bool(row, "in_catalog");
            _inStockSheet.IsChecked = Bool(row, "in_stock_sheet");
            _hasRecipe.IsChecked = Bool(row, "has_recipe");
            _imagineUrl = Text(row, "imagine_url");
            if (string.IsNullOrWhiteSpace(_imagineUrl))
                _imagineUrl = null;
            _vatPayer = await LoadVatPayer();
            var vat = Amount(row, "cota_tva", _vatPayer ? "21" : "0");
            if (!_vatPayer)
                vat = "0";
            Select(_vat, NormalizeVat(vat), "0");
            _vat.IsEnabled = _vatPayer;
            await LoadGroups();
            await LoadAddons();
            await LoadRecipe();
            RefreshFactor();
            _loading = false;
            _status.Text = "";
            await ShowPhoto(_imagineUrl);
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async Task<bool> LoadVatPayer()
    {
        var rows = await _session.SelectRows("companies", "id=eq." + _companyId + "&select=platitor_tva");
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            return true;
        return Bool(rows[0], "platitor_tva");
    }

    private async Task LoadGroups()
    {
        _groups.Children.Clear();
        _groupBoxes.Clear();
        var groups = await _session.SelectRows(
            "cm_product_groups",
            "company_id=eq." + _companyId + "&kind=eq.custom&select=id,name&order=name.asc");
        var members = await _session.SelectRows(
            "cm_product_group_members",
            "product_id=eq." + _productId + "&select=id,group_id");
        _initialGroups = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (members.ValueKind == JsonValueKind.Array)
        {
            foreach (var member in members.EnumerateArray())
            {
                var id = Text(member, "group_id");
                if (id.Length > 0)
                    _initialGroups.Add(id);
            }
        }
        if (groups.ValueKind != JsonValueKind.Array || groups.GetArrayLength() == 0)
        {
            _groups.Children.Add(Hint("Nu există grupe CM custom. Creați-le în Catalog → Grupe CM."));
            return;
        }
        var options = groups.EnumerateArray()
            .Select(row => (Id: Text(row, "id"), Name: Text(row, "name")))
            .Where(row => row.Id.Length > 0)
            .OrderBy(row => row.Name, StringComparer.Create(CultureInfo.GetCultureInfo("ro-RO"), true))
            .ToList();
        foreach (var option in options)
        {
            var box = new CheckBox { Content = option.Name, IsChecked = _initialGroups.Contains(option.Id) };
            box.IsCheckedChanged += (_, _) => LimitGroups(box);
            _groupBoxes.Add((option.Id, box));
            _groups.Children.Add(box);
        }
    }

    private void LimitGroups(CheckBox changed)
    {
        if (changed.IsChecked != true)
            return;
        if (_groupBoxes.Count(item => item.Box.IsChecked == true) <= 2)
            return;
        changed.IsChecked = false;
        _status.Text = "Un produs poate fi în maximum 2 grupe CM.";
        _status.Foreground = Brushes.Firebrick;
    }

    private async Task LoadAddons()
    {
        _addons.Children.Clear();
        var rows = await _session.SelectRows(
            "product_sale_addons",
            "product_id=eq." + _productId + "&select=cantitate,addon_product_id&order=sort_order.asc");
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
        {
            _addons.Children.Add(Hint("Niciun produs adițional."));
            return;
        }
        foreach (var row in rows.EnumerateArray())
        {
            var addonId = Text(row, "addon_product_id");
            var name = await ProductName(addonId);
            _addons.Children.Add(new TextBlock
            {
                Text = name + "  ·  " + Amount(row, "cantitate", "1"),
                Foreground = Brand.Brush(Brand.Navy)
            });
        }
    }

    private async Task LoadRecipe()
    {
        var generation = ++_recipeGeneration;
        _recipe.Children.Clear();
        var rows = await _session.SelectRows(
            "product_recipe_lines",
            "product_id=eq." + _productId + "&select=id,cantitate,unitate_masura,ingredient_product_id&order=numar_linie.asc",
            0,
            999);
        if (generation != _recipeGeneration)
            return;
        if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
        {
            _recipe.Children.Add(Hint("Rețeta este goală."));
            return;
        }
        foreach (var row in rows.EnumerateArray())
        {
            var lineId = Text(row, "id");
            var name = await ProductName(Text(row, "ingredient_product_id"));
            if (generation != _recipeGeneration)
                return;
            var line = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            line.Children.Add(new TextBlock
            {
                Text = name,
                Width = 320,
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = Brand.Brush(Brand.Navy),
                TextWrapping = TextWrapping.Wrap
            });
            var quantity = new TextBox { Text = RecipeQuantity(row), Width = 90 };
            var lastQuantity = quantity.Text ?? "";
            quantity.LostFocus += async (_, _) =>
            {
                if (generation != _recipeGeneration)
                    return;
                var text = quantity.Text ?? "";
                if (text == lastQuantity)
                    return;
                if (!TryAmount(text, out var number) || number <= 0)
                {
                    quantity.Text = lastQuantity;
                    _status.Text = "Cantitatea trebuie să fie mai mare decât zero.";
                    _status.Foreground = Brushes.Firebrick;
                    return;
                }
                var rounded = decimal.Round(number, StockFormat.Digits, MidpointRounding.AwayFromZero);
                var shown = StockFormat.Text(rounded);
                quantity.Text = shown;
                lastQuantity = shown;
                try
                {
                    await _session.UpdateRow("product_recipe_lines", lineId, new Dictionary<string, object?>
                    {
                        ["cantitate"] = rounded
                    });
                    _status.Text = "Cantitatea a fost salvată.";
                    _status.Foreground = Brand.Brush(Brand.Muted);
                }
                catch (Exception ex)
                {
                    _status.Text = ex.Message;
                    _status.Foreground = Brushes.Firebrick;
                }
            };
            line.Children.Add(quantity);
            line.Children.Add(new TextBlock
            {
                Text = Text(row, "unitate_masura"),
                VerticalAlignment = VerticalAlignment.Center
            });
            var remove = new Button { Content = "Șterge", Padding = new Avalonia.Thickness(8, 4) };
            remove.Click += async (_, _) =>
            {
                if (generation != _recipeGeneration)
                    return;
                try
                {
                    await _session.DeleteRow("product_recipe_lines", lineId);
                    var left = await _session.SelectRows(
                        "product_recipe_lines",
                        "product_id=eq." + _productId + "&select=id",
                        0,
                        0);
                    if (left.ValueKind != JsonValueKind.Array || left.GetArrayLength() == 0)
                    {
                        await _session.UpdateRow("products", _productId, new Dictionary<string, object?>
                        {
                            ["has_recipe"] = false
                        });
                        _hasRecipe.IsChecked = false;
                    }
                    await LoadRecipe();
                    _status.Text = "Linia a fost scoasă din rețetă.";
                    _status.Foreground = Brand.Brush(Brand.Muted);
                }
                catch (Exception ex)
                {
                    _status.Text = ex.Message;
                    _status.Foreground = Brushes.Firebrick;
                }
            };
            line.Children.Add(remove);
            _recipe.Children.Add(line);
        }
    }

    private async Task ShowCopyRecipe()
    {
        List<RecipeSource> sources;
        try
        {
            sources = await LoadRecipeSources();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
            return;
        }
        if (sources.Count == 0)
        {
            _status.Text = "Niciun produs finit cu rețetă.";
            _status.Foreground = Brushes.Firebrick;
            return;
        }

        var window = new Window
        {
            Title = "De la ce produs finit",
            Width = 560,
            Height = 520,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Icon = Brand.WindowIcon()
        };
        var search = new TextBox { Watermark = "Denumire sau cod", Margin = new Avalonia.Thickness(12) };
        var list = new ListBox { Margin = new Avalonia.Thickness(12, 0, 12, 12), ItemsSource = sources };
        var copy = new Button
        {
            Content = "Copiază rețetă",
            Margin = new Avalonia.Thickness(12),
            HorizontalAlignment = HorizontalAlignment.Left,
            IsEnabled = false
        };
        list.SelectionChanged += (_, _) => copy.IsEnabled = list.SelectedItem is RecipeSource;
        search.TextChanged += (_, _) =>
        {
            var term = (search.Text ?? "").Trim();
            list.ItemsSource = term.Length == 0
                ? sources
                : sources.Where(item =>
                    item.Name.Contains(term, StringComparison.CurrentCultureIgnoreCase)
                    || item.Code.Contains(term, StringComparison.CurrentCultureIgnoreCase)).ToList();
        };
        RecipeSource? chosen = null;
        copy.Click += (_, _) =>
        {
            if (list.SelectedItem is RecipeSource source)
            {
                chosen = source;
                window.Close();
            }
        };
        var root = new DockPanel();
        DockPanel.SetDock(search, Dock.Top);
        DockPanel.SetDock(copy, Dock.Bottom);
        root.Children.Add(search);
        root.Children.Add(copy);
        root.Children.Add(list);
        window.Content = root;
        await window.ShowDialog(this);
        if (chosen == null)
            return;
        await CopyRecipeFrom(chosen);
    }

    private async Task<List<RecipeSource>> LoadRecipeSources()
    {
        var sources = new List<RecipeSource>();
        for (var from = 0; ; from += 1000)
        {
            var rows = await _session.SelectRows(
                "products",
                "company_id=eq." + _companyId
                    + "&is_active=eq.true&has_recipe=eq.true&tip=eq.produs_finit&id=neq." + _productId
                    + "&select=id,denumire,cod&order=denumire.asc",
                from,
                from + 999);
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
                break;
            foreach (var row in rows.EnumerateArray())
            {
                var id = Text(row, "id");
                var name = Text(row, "denumire");
                if (id.Length == 0 || name.Length == 0)
                    continue;
                sources.Add(new RecipeSource(id, name, Text(row, "cod")));
            }
            if (rows.GetArrayLength() < 1000)
                break;
        }
        return sources;
    }

    private async Task CopyRecipeFrom(RecipeSource source)
    {
        try
        {
            var existing = await _session.SelectRows(
                "product_recipe_lines",
                "product_id=eq." + _productId + "&select=id",
                0,
                999);
            var hasLines = existing.ValueKind == JsonValueKind.Array && existing.GetArrayLength() > 0;
            if (hasLines)
            {
                var ok = await ConfirmDialog.Ask(
                    this,
                    "Rețeta actuală se înlocuiește cu cea de la " + source.Name + ". După copiere poți modifica liniile.");
                if (!ok)
                    return;
            }

            var sourceRows = await _session.SelectRows(
                "product_recipe_lines",
                "product_id=eq." + source.Id + "&select=ingredient_product_id,cantitate,unitate_masura,pret_achizitie,pret_achizitie_sursa,numar_linie&order=numar_linie.asc",
                0,
                999);
            var lines = new List<JsonElement>();
            if (sourceRows.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in sourceRows.EnumerateArray())
                {
                    if (!string.Equals(Text(row, "ingredient_product_id"), _productId, StringComparison.OrdinalIgnoreCase))
                        lines.Add(row);
                }
            }
            if (lines.Count == 0)
            {
                _status.Text = "Produsul ales nu are linii de rețetă de copiat.";
                _status.Foreground = Brushes.Firebrick;
                return;
            }

            if (existing.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in existing.EnumerateArray())
                    await _session.DeleteRow("product_recipe_lines", Text(row, "id"));
            }

            var number = 1;
            foreach (var row in lines)
            {
                if (!TryAmount(Text(row, "cantitate"), out var quantity) || quantity <= 0)
                    continue;
                var payload = new Dictionary<string, object?>
                {
                    ["company_id"] = _companyId,
                    ["product_id"] = _productId,
                    ["ingredient_product_id"] = Text(row, "ingredient_product_id"),
                    ["numar_linie"] = number++,
                    ["cantitate"] = decimal.Round(quantity, StockFormat.Digits, MidpointRounding.AwayFromZero),
                    ["unitate_masura"] = Text(row, "unitate_masura"),
                    ["pret_achizitie_sursa"] = Text(row, "pret_achizitie_sursa") is { Length: > 0 } priceSource ? priceSource : "local"
                };
                if (TryAmount(Text(row, "pret_achizitie"), out var price))
                    payload["pret_achizitie"] = price;
                await _session.InsertRow("product_recipe_lines", payload);
            }

            await _session.UpdateRow("products", _productId, new Dictionary<string, object?>
            {
                ["has_recipe"] = true
            });
            _hasRecipe.IsChecked = true;
            await LoadRecipe();
            _status.Text = "Rețeta a fost copiată. Poți modifica cantitățile.";
            _status.Foreground = Brand.Brush(Brand.Muted);
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
            await LoadRecipe();
        }
    }

    private sealed class RecipeSource
    {
        public RecipeSource(string id, string name, string code)
        {
            Id = id;
            Name = name;
            Code = code;
        }

        public string Id { get; }
        public string Name { get; }
        public string Code { get; }

        public override string ToString() => Code.Length == 0 ? Name : Name + "  ·  " + Code;
    }

    private async Task<string> ProductName(string id)
    {
        if (id.Length == 0)
            return "Produs";
        var rows = await _session.SelectRows("products", "id=eq." + id + "&select=denumire");
        if (rows.ValueKind == JsonValueKind.Array && rows.GetArrayLength() > 0)
        {
            var name = Text(rows[0], "denumire");
            if (name.Length > 0)
                return name;
        }
        return "Produs";
    }

    private async Task ShowPhoto(string? url)
    {
        _photo.IsVisible = false;
        _photo.Source = null;
        _noPhoto.IsVisible = true;
        _noPhoto.Text = "Nu există poză pentru acest articol.";
        _removePhoto.IsVisible = !string.IsNullOrWhiteSpace(url);
        if (string.IsNullOrWhiteSpace(url))
            return;
        try
        {
            var bytes = await Http.GetByteArrayAsync(url);
            var bitmap = new Bitmap(new MemoryStream(bytes));
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                _photo.Source = bitmap;
                _photo.IsVisible = true;
                _noPhoto.IsVisible = false;
            });
        }
        catch
        {
            _noPhoto.Text = "Poza nu a putut fi încărcată.";
        }
    }

    private async Task PickImage()
    {
        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Imagine articol",
            AllowMultiple = false,
            FileTypeFilter = [new FilePickerFileType("Imagini") { Patterns = ["*.png", "*.jpg", "*.jpeg", "*.webp"] }]
        });
        var file = files.FirstOrDefault();
        if (file == null)
            return;
        try
        {
            await using var stream = await file.OpenReadAsync();
            using var memory = new MemoryStream();
            await stream.CopyToAsync(memory);
            var ext = Path.GetExtension(file.Name).ToLowerInvariant();
            var type = ext == ".png" ? "image/png" : ext == ".webp" ? "image/webp" : "image/jpeg";
            var previous = _imagineUrl;
            var url = await _session.UploadProductImage(_companyId, _productId, memory.ToArray(), type);
            await _session.UpdateRow("products", _productId, new Dictionary<string, object?> { ["imagine_url"] = url });
            if (!string.Equals(previous, url, StringComparison.Ordinal))
                await _session.RemoveStoredProductImage(previous);
            _imagineUrl = url;
            await ShowPhoto(url);
            _status.Text = "";
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async Task RemoveImage()
    {
        try
        {
            await _session.RemoveStoredProductImage(_imagineUrl);
            await _session.UpdateRow("products", _productId, new Dictionary<string, object?> { ["imagine_url"] = null });
            _imagineUrl = null;
            await ShowPhoto(null);
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async Task Save()
    {
        var name = (_name.Text ?? "").Trim();
        if (name.Length == 0)
        {
            _status.Text = "Denumirea este obligatorie.";
            _status.Foreground = Brushes.Firebrick;
            return;
        }
        if (!TryAmount(_price.Text, out var price) || price < 0
            || !TryAmount(_onlinePrice.Text, out var onlinePrice) || onlinePrice < 0)
        {
            _status.Text = "Prețul de vânzare nu este valid.";
            _status.Foreground = Brushes.Firebrick;
            return;
        }
        decimal? purchasePrice = null;
        var purchaseRaw = (_purchasePrice.Text ?? "").Trim();
        if (purchaseRaw.Length > 0)
        {
            if (!TryAmount(purchaseRaw, out var parsedPurchase) || parsedPurchase < 0)
            {
                _status.Text = "Prețul de achiziție nu este valid.";
                _status.Foreground = Brushes.Firebrick;
                return;
            }
            purchasePrice = decimal.Round(parsedPurchase, 2, MidpointRounding.AwayFromZero);
        }
        var purchase = PurchaseValue();
        var stock = SelectedCode(_stockUnit);
        if (stock.Length == 0)
            stock = "Buc.";
        var factor = 1m;
        if (ShowsFactor(stock, purchase))
        {
            if (!TryAmount(_factor.Text, out factor) || factor <= 0)
            {
                _status.Text = "Factorul de conversie nu este valid.";
                _status.Foreground = Brushes.Firebrick;
                return;
            }
        }
        var tip = SelectedCode(_category);
        var inCatalog = _inCatalog.IsChecked == true || tip == "produs_finit";
        var vat = _vatPayer ? NormalizeVat(SelectedCode(_vat)) : "0";
        if (!decimal.TryParse(vat, NumberStyles.Number, CultureInfo.InvariantCulture, out var vatNumber))
            vatNumber = 0;
        var code = (_code.Text ?? "").Trim();
        if (code.Length == 0)
        {
            _status.Text = "Codul articolului este obligatoriu și trebuie să fie unic.";
            _status.Foreground = Brushes.Firebrick;
            return;
        }
        var minStock = 0m;
        var optimalStock = 0m;
        if (tip != "produs_finit")
        {
            if (!TryAmount(_minStock.Text, out minStock) || minStock < 0)
            {
                _status.Text = "Stocul minim nu este valid.";
                _status.Foreground = Brushes.Firebrick;
                return;
            }
            if (!TryAmount(_optimalStock.Text, out optimalStock) || optimalStock < 0)
            {
                _status.Text = "Stocul optim nu este valid.";
                _status.Foreground = Brushes.Firebrick;
                return;
            }
            minStock = decimal.Round(minStock, StockFormat.Digits, MidpointRounding.AwayFromZero);
            optimalStock = decimal.Round(optimalStock, StockFormat.Digits, MidpointRounding.AwayFromZero);
        }
        try
        {
            await _session.UpdateRow("products", _productId, new Dictionary<string, object?>
            {
                ["denumire"] = name,
                ["cod"] = code,
                ["cod_bare"] = EmptyToNull(_barcode.Text),
                ["unitate_masura"] = stock,
                ["unitate_achizitie"] = EmptyToNull(purchase),
                ["factor_conversie"] = factor,
                ["tip"] = tip,
                ["cantitate_minima"] = tip == "produs_finit" ? 0m : minStock,
                ["cantitate_optima"] = tip == "produs_finit" ? 0m : optimalStock,
                ["in_catalog"] = inCatalog,
                ["in_stock_sheet"] = _inStockSheet.IsChecked == true,
                ["has_recipe"] = _hasRecipe.IsChecked == true,
                ["cota_tva"] = vatNumber,
                ["pret_vanzare"] = price,
                ["pret_vanzare_online"] = onlinePrice,
                ["pret_achizitie"] = purchasePrice
            });
            await SaveGroups();
            _saved = true;
            Close(true);
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.Firebrick;
        }
    }

    private async Task SaveGroups()
    {
        var selected = _groupBoxes.Where(item => item.Box.IsChecked == true).Select(item => item.Id).ToList();
        if (selected.Count > 2)
            throw new InvalidOperationException("Un produs poate fi în maximum 2 grupe CM.");
        var members = await _session.SelectRows(
            "cm_product_group_members",
            "product_id=eq." + _productId + "&select=id,group_id");
        if (members.ValueKind == JsonValueKind.Array)
        {
            foreach (var member in members.EnumerateArray())
            {
                var groupId = Text(member, "group_id");
                if (!selected.Contains(groupId, StringComparer.OrdinalIgnoreCase))
                    await _session.DeleteRow("cm_product_group_members", Text(member, "id"));
            }
        }
        var order = 0;
        foreach (var groupId in selected)
        {
            if (_initialGroups.Contains(groupId))
            {
                order++;
                continue;
            }
            await _session.InsertRow("cm_product_group_members", new Dictionary<string, object?>
            {
                ["company_id"] = _companyId,
                ["group_id"] = groupId,
                ["product_id"] = _productId,
                ["sort_order"] = order
            });
            order++;
        }
    }

    private void RefreshFactor()
    {
        var stock = SelectedCode(_stockUnit);
        var purchase = PurchaseValue();
        var show = ShowsFactor(stock, purchase);
        _purchaseCustom.IsVisible = SelectedCode(_purchaseUnit) == "__other__";
        _factorRow.IsVisible = show;
        if (!show)
            return;
        var purchaseLabel = purchase.Length == 0 ? "UM achiziție" : purchase;
        var stockLabel = stock.Length == 0 ? "Buc." : stock;
        _factorLabel.Text = "Câte " + stockLabel + " în 1 " + purchaseLabel;
    }

    private void RefreshMinStockVisibility()
    {
        var showStockLevels = SelectedCode(_category) != "produs_finit";
        _minStockRow.IsVisible = showStockLevels;
        _optimalStockRow.IsVisible = showStockLevels;
    }

    private string PurchaseValue()
    {
        var code = SelectedCode(_purchaseUnit);
        if (code == "__other__")
            return (_purchaseCustom.Text ?? "").Trim();
        return code;
    }

    private void SelectPurchase(string current)
    {
        var match = PurchaseUnits.FirstOrDefault(unit => unit.Code.Length > 0 && unit.Code != "__other__" && string.Equals(unit.Code, current, StringComparison.OrdinalIgnoreCase));
        if (string.IsNullOrWhiteSpace(current))
            Select(_purchaseUnit, "", "");
        else if (!string.IsNullOrEmpty(match.Code))
            Select(_purchaseUnit, match.Code, "");
        else
        {
            Select(_purchaseUnit, "__other__", "");
            _purchaseCustom.Text = current;
        }
    }

    private static bool ShowsFactor(string stock, string purchase) =>
        purchase.Length > 0 && !string.Equals(purchase, stock, StringComparison.OrdinalIgnoreCase);

    private static void Select(ComboBox combo, string code, string fallback)
    {
        var match = combo.Items.OfType<FieldChoice>().FirstOrDefault(item => string.Equals(item.Code, code, StringComparison.OrdinalIgnoreCase))
            ?? combo.Items.OfType<FieldChoice>().FirstOrDefault(item => string.Equals(item.Code, fallback, StringComparison.OrdinalIgnoreCase))
            ?? combo.Items.OfType<FieldChoice>().FirstOrDefault();
        combo.SelectedItem = match;
    }

    private static void SelectUnit(ComboBox combo, string code, string fallback)
    {
        if (combo.Items.OfType<FieldChoice>().All(item => !string.Equals(item.Code, code, StringComparison.OrdinalIgnoreCase)) && code.Length > 0)
            combo.Items.Add(new FieldChoice(code, code));
        Select(combo, code, fallback);
    }

    private static string SelectedCode(ComboBox combo) =>
        combo.SelectedItem is FieldChoice choice ? choice.Code : "";

    private static string NormalizeVat(string raw)
    {
        if (!decimal.TryParse(raw.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out var number))
            return "0";
        if (number >= 19)
            return "21";
        if (number >= 9)
            return "11";
        return "0";
    }

    private static bool TryAmount(string? text, out decimal value)
    {
        var raw = (text ?? "").Trim().Replace(" ", "");
        return decimal.TryParse(raw, NumberStyles.Number, CultureInfo.GetCultureInfo("ro-RO"), out value)
            || decimal.TryParse(raw, NumberStyles.Number, CultureInfo.InvariantCulture, out value);
    }

    private static string? EmptyToNull(string? text)
    {
        var trimmed = (text ?? "").Trim();
        return trimmed.Length == 0 ? null : trimmed;
    }

    private void AddHeading(string text) =>
        _page.Children.Add(new TextBlock
        {
            Text = text,
            FontSize = 16,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            Margin = new Avalonia.Thickness(0, 12, 0, 0)
        });

    private void AddField(string label, Control input)
    {
        _page.Children.Add(new TextBlock { Text = label, Foreground = Brand.Brush(Brand.Muted), FontSize = 12 });
        _page.Children.Add(input);
    }

    private static TextBlock Hint(string text) => new()
    {
        Text = text,
        Foreground = Brand.Brush(Brand.Muted),
        FontSize = 12,
        TextWrapping = TextWrapping.Wrap
    };

    private static string Text(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value) || value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.GetRawText();
    }

    private static string RecipeQuantity(JsonElement row)
    {
        var text = Text(row, "cantitate");
        return TryAmount(text, out var number)
            ? StockFormat.Text(number)
            : (text.Length == 0 ? StockFormat.Text(0) : text);
    }

    private static string StockAmount(JsonElement row, string field, string fallback)
    {
        var text = Text(row, field);
        if (text.Length == 0)
            return fallback;
        return TryAmount(text, out var number) ? StockFormat.Text(number) : text;
    }

    private static string Amount(JsonElement row, string field, string fallback)
    {
        var text = Text(row, field);
        if (text.Length == 0)
            return fallback;
        return TryAmount(text, out var number)
            ? number.ToString("0.##", CultureInfo.GetCultureInfo("ro-RO"))
            : text;
    }

    private static bool Bool(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value))
            return false;
        return value.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.String => value.GetString() is "true" or "Da" or "1",
            _ => false
        };
    }
}
