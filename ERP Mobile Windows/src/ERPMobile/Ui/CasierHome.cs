using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class CasierHome : UserControl
{
    private readonly AppSession _session;
    private readonly Action<Guid, string> _enterPos;
    private readonly Border _host = new();

    public CasierHome(AppSession session, Action<Guid, string> enterPos)
    {
        _session = session;
        _enterPos = enterPos;
        Content = _host;
        ShowHub();
    }

    private void ShowHub()
    {
        var wrap = new WrapPanel();
        wrap.Children.Add(SectionHome.Tile("Producție", "Bon producție și bon transfer.", () => Dispatcher.UIThread.Post(ShowProduction)));
        wrap.Children.Add(SectionHome.Tile("POS", "Vânzare pe casa de marcat, pe punctul de lucru ales.", () => Dispatcher.UIThread.Post(() => _ = ShowLocations())));
        var page = new StackPanel { Margin = new Avalonia.Thickness(20) };
        page.Children.Add(wrap);
        _host.Child = new ScrollViewer { Content = page };
    }

    private void ShowProduction()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12, MaxWidth = 520 };
        page.Children.Add(Back("← Casier", ShowHub));
        page.Children.Add(ActionButton("Bon transfer", () => Dispatcher.UIThread.Post(() => _ = ShowTransfers())));
        page.Children.Add(ActionButton("Bon producție", () => Dispatcher.UIThread.Post(() => _ = ShowProductionNotes())));
        _host.Child = new ScrollViewer { Content = page };
    }

    private async Task ShowTransfers()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 640 };
        page.Children.Add(Back("← Producție", ShowProduction));
        page.Children.Add(Title("Bon transfer"));
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var company = Company();
            var rows = await _session.SelectRows("stock_transfers", $"company_id=eq.{company}&select=id,numar,data_bon&order=data_bon.desc");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Nu există bonuri de transfer."));
                return;
            }
            foreach (var row in rows.EnumerateArray())
            {
                var number = TextOf(row, "numar");
                var date = TextOf(row, "data_bon");
                page.Children.Add(new TextBlock
                {
                    Text = string.IsNullOrWhiteSpace(number) ? date : "Nr. " + number + "  ·  " + date,
                    Foreground = Brand.Brush(Brand.Navy),
                    FontSize = 15
                });
            }
        }
        catch (Exception ex)
        {
            page.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private async Task ShowProductionNotes()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 640 };
        page.Children.Add(Back("← Producție", ShowProduction));
        page.Children.Add(Title("Bon producție"));
        page.Children.Add(ActionButton("Bon producție nou", () => Dispatcher.UIThread.Post(() => _ = ShowCreateProductionNote())));
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var company = Company();
            var rows = await _session.SelectRows(
                "production_vouchers",
                $"company_id=eq.{company}&select=id,numar,data_bon,cantitate,unitate_masura,product:products(denumire),warehouse:company_warehouses(denumire)&order=data_bon.desc");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Nu există bonuri de producție. Creați unul: gestiune, produs finit și cantitate."));
                return;
            }
            foreach (var row in rows.EnumerateArray())
            {
                var number = TextOf(row, "numar");
                var date = TextOf(row, "data_bon");
                var qty = TextOf(row, "cantitate");
                var unit = TextOf(row, "unitate_masura");
                var product = NestedText(row, "product", "denumire");
                var warehouse = NestedText(row, "warehouse", "denumire");
                page.Children.Add(new TextBlock
                {
                    Text = "BP " + number + "  ·  " + date + "  ·  " + product + "  ·  " + qty + " " + unit
                        + (string.IsNullOrWhiteSpace(warehouse) ? "" : "  ·  " + warehouse),
                    Foreground = Brand.Brush(Brand.Navy),
                    FontSize = 15,
                    TextWrapping = TextWrapping.Wrap
                });
            }
        }
        catch (Exception ex)
        {
            page.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private async Task ShowCreateProductionNote()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 520 };
        page.Children.Add(Back("← Bonuri producție", () => Dispatcher.UIThread.Post(() => _ = ShowProductionNotes())));
        page.Children.Add(Title("Bon producție nou"));
        _host.Child = new ScrollViewer { Content = page };

        var warehouseCombo = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch, MinHeight = 32 };
        var productCombo = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch, MinHeight = 32 };
        var qtyBox = new TextBox { Watermark = "Cantitate" };
        var status = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = Brushes.Firebrick };

        page.Children.Add(Muted("Gestiune"));
        page.Children.Add(warehouseCombo);
        page.Children.Add(Muted("Produs finit (cu rețetă)"));
        page.Children.Add(productCombo);
        page.Children.Add(Muted("Cantitate"));
        page.Children.Add(qtyBox);
        page.Children.Add(Muted("La salvare: +stoc produs finit, −consum rețetă (inclusiv PF imbricate) pe gestiunea aleasă."));
        page.Children.Add(status);

        try
        {
            var company = Company();
            var warehouses = await _session.SelectRows(
                "company_warehouses",
                $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
            var products = await _session.SelectRows(
                "products",
                $"company_id=eq.{company}&has_recipe=eq.true&tip=eq.produs_finit&is_active=eq.true&select=id,denumire,cod,unitate_masura&order=denumire.asc");

            var warehouseItems = new List<NamedPick>();
            if (warehouses.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in warehouses.EnumerateArray())
                    warehouseItems.Add(new NamedPick(row.GetProperty("id").GetGuid(), TextOf(row, "denumire")));
            }
            warehouseCombo.ItemsSource = warehouseItems;
            if (warehouseItems.Count > 0)
                warehouseCombo.SelectedIndex = 0;

            var productItems = new List<NamedPick>();
            if (products.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in products.EnumerateArray())
                {
                    var name = TextOf(row, "denumire");
                    var code = TextOf(row, "cod");
                    var unit = TextOf(row, "unitate_masura");
                    var label = string.IsNullOrWhiteSpace(code) ? name : name + "  ·  " + code;
                    if (!string.IsNullOrWhiteSpace(unit))
                        label += " (" + unit + ")";
                    productItems.Add(new NamedPick(row.GetProperty("id").GetGuid(), label));
                }
            }
            productCombo.ItemsSource = productItems;
            if (productItems.Count == 0)
                status.Text = "Nu există produse finite cu rețetă.";
            else
                productCombo.SelectedIndex = 0;
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
        }

        var save = new Button
        {
            Content = "Salvează",
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brand.Brush(Brand.Gold),
            Foreground = Brushes.White,
            Padding = new Avalonia.Thickness(16, 10),
            CornerRadius = new Avalonia.CornerRadius(8)
        };
        save.Click += (_, _) => Dispatcher.UIThread.Post(() => _ = SaveProductionNote(warehouseCombo, productCombo, qtyBox, status));
        page.Children.Add(save);
    }

    private async Task SaveProductionNote(ComboBox warehouseCombo, ComboBox productCombo, TextBox qtyBox, TextBlock status)
    {
        status.Text = "";
        status.Foreground = Brushes.Firebrick;
        try
        {
            if (warehouseCombo.SelectedItem is not NamedPick warehouse)
            {
                status.Text = "Alegeți gestiunea.";
                return;
            }
            if (productCombo.SelectedItem is not NamedPick product)
            {
                status.Text = "Alegeți produsul finit.";
                return;
            }
            var qtyText = (qtyBox.Text ?? "").Trim().Replace(',', '.');
            if (!decimal.TryParse(qtyText, NumberStyles.Number, CultureInfo.InvariantCulture, out var qty) || qty <= 0)
            {
                status.Text = "Introduceți o cantitate mai mare decât zero.";
                return;
            }

            var company = Company();
            await _session.Rpc("post_production_voucher", new
            {
                p_company_id = company.ToString(),
                p_data_bon = DateTime.Today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                p_warehouse_id = warehouse.Id.ToString(),
                p_product_id = product.Id.ToString(),
                p_cantitate = qty,
                p_observatii = (string?)null
            });
            await ShowProductionNotes();
        }
        catch (Exception ex)
        {
            var message = ex.Message;
            if (message.Contains("PRODUCTION_INSUFFICIENT_STOCK", StringComparison.OrdinalIgnoreCase))
                message = "Stoc insuficient în gestiune pentru materiile din rețetă.";
            else if (message.Contains("PRODUCTION_RECIPE_EMPTY", StringComparison.OrdinalIgnoreCase))
                message = "Produsul nu are rețetă de producție.";
            else if (message.Contains("PRODUCTION_PRODUCT_NOT_ALLOWED", StringComparison.OrdinalIgnoreCase))
                message = "Alegeți un produs finit cu rețetă.";
            status.Text = message;
        }
    }

    private static string NestedText(JsonElement row, string objectName, string field)
    {
        if (!row.TryGetProperty(objectName, out var nested) || nested.ValueKind != JsonValueKind.Object)
            return "";
        return TextOf(nested, field);
    }

    private sealed record NamedPick(Guid Id, string Label)
    {
        public override string ToString() => Label;
    }

    private async Task ShowLocations()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12 };
        page.Children.Add(Back("← Casier", ShowHub));
        page.Children.Add(Title("POS"));
        var tiles = new WrapPanel();
        page.Children.Add(tiles);
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var company = Company();
            var rows = await _session.SelectRows("company_work_locations", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Nu există puncte de lucru active. Le adăugați în Nomenclatoare → Societăți."));
                return;
            }
            foreach (var row in rows.EnumerateArray())
            {
                var id = row.GetProperty("id").GetGuid();
                var name = TextOf(row, "denumire");
                tiles.Children.Add(LocationTile(name, () => Dispatcher.UIThread.Post(() => _enterPos(id, name))));
            }
        }
        catch (Exception ex)
        {
            page.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private Guid Company()
    {
        if (_session.CurrentCompany == null)
            throw new InvalidOperationException("Selectați o societate.");
        return _session.CurrentCompany.Id;
    }

    private static string TextOf(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.ToString();
    }

    private static TextBlock Title(string text) => new()
    {
        Text = text,
        FontSize = 22,
        FontWeight = FontWeight.SemiBold,
        Foreground = Brand.Brush(Brand.Navy)
    };

    private static TextBlock Muted(string text) => new()
    {
        Text = text,
        TextWrapping = TextWrapping.Wrap,
        Foreground = Brand.Brush(Brand.Muted)
    };

    private static Button Back(string title, Action action)
    {
        var button = new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brushes.White,
            Foreground = Brand.Brush(Brand.Navy)
        };
        button.Click += (_, _) => Dispatcher.UIThread.Post(action);
        return button;
    }

    private static Button LocationTile(string title, Action action)
    {
        var button = new Button
        {
            Width = 220,
            Height = 140,
            Margin = new Avalonia.Thickness(0, 0, 12, 12),
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(1),
            CornerRadius = new Avalonia.CornerRadius(14),
            HorizontalContentAlignment = HorizontalAlignment.Center,
            VerticalContentAlignment = VerticalAlignment.Center,
            Content = new TextBlock
            {
                Text = title,
                FontSize = 18,
                FontWeight = FontWeight.SemiBold,
                Foreground = Brand.Brush(Brand.Navy),
                TextWrapping = TextWrapping.Wrap,
                TextAlignment = TextAlignment.Center,
                Margin = new Avalonia.Thickness(12)
            }
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static Button ActionButton(string title, Action action)
    {
        var button = new Button
        {
            Content = title,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Background = Brushes.White,
            Foreground = Brand.Brush(Brand.Navy),
            FontSize = 16,
            Padding = new Avalonia.Thickness(16, 16),
            CornerRadius = new Avalonia.CornerRadius(12)
        };
        button.Click += (_, _) => action();
        return button;
    }
}

