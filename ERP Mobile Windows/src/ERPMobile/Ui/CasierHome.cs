using System.Globalization;
using System.Linq;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Input;
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
    private Guid? _transferLocation;
    private DateTime _transferDate = DateTime.Today;
    private Guid? _productionLocation;
    private DateTime _productionDate = DateTime.Today;
    private Guid? _consumptionLocation;
    private DateTime _consumptionDate = DateTime.Today;
    private readonly List<NamedPick> _locations = new();
    private readonly Dictionary<Guid, Guid?> _warehouseLocation = new();

    public CasierHome(AppSession session, Action<Guid, string> enterPos)
    {
        _session = session;
        _enterPos = enterPos;
        Content = _host;
        ShowHub();
    }

    public void ShowStart() => ShowHub();

    private void ShowHub()
    {
        var wrap = new WrapPanel();
        wrap.Children.Add(SectionHome.Tile("Producție", "Bon producție, bon transfer și bon consum.", () => Dispatcher.UIThread.Post(ShowProduction), Color.FromRgb(46, 174, 78)));
        wrap.Children.Add(SectionHome.Tile("POS", "Vânzare pe casa de marcat, pe punctul de lucru ales.", () => Dispatcher.UIThread.Post(() => _ = ShowLocations()), Color.FromRgb(214, 48, 48)));
        wrap.Children.Add(SectionHome.Tile("Foaie stoc", "Foile generate după fiecare Raport Z, pe punct de lucru și pe tură.", () => Dispatcher.UIThread.Post(ShowStockSheets), Color.FromRgb(37, 99, 235)));
        var page = new StackPanel { Margin = new Avalonia.Thickness(20) };
        page.Children.Add(wrap);
        _host.Child = new ScrollViewer { Content = page };
    }

    private void ShowStockSheets()
    {
        var root = new DockPanel();
        var back = Back("← Casier", ShowHub);
        back.Margin = new Avalonia.Thickness(20, 12, 20, 0);
        DockPanel.SetDock(back, Dock.Top);
        root.Children.Add(back);
        root.Children.Add(new StockSheetListView(_session));
        _host.Child = root;
    }

    private void ShowProduction()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12, MaxWidth = 520 };
        page.Children.Add(Back("← Casier", ShowHub));
        page.Children.Add(ActionButton("Bon transfer", () => Dispatcher.UIThread.Post(() => _ = ShowTransfers())));
        page.Children.Add(ActionButton("Bon producție", () => Dispatcher.UIThread.Post(() => _ = ShowProductionNotes())));
        page.Children.Add(ActionButton("Bon consum", () => Dispatcher.UIThread.Post(() => _ = ShowConsumptions())));
        _host.Child = new ScrollViewer { Content = page };
    }

    private async Task ShowTransfers()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 720 };
        page.Children.Add(Back("← Producție", ShowProduction));
        page.Children.Add(Title("Bon transfer"));
        page.Children.Add(ActionButton("Bon transfer nou", () => Dispatcher.UIThread.Post(() => _ = ShowTransferEdit(null))));
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            await LoadPlaces();
            var location = new ComboBox { MinWidth = 220 };
            var date = new CalendarDatePicker { SelectedDate = _transferDate, Width = 160 };
            var armTransfer = AddFilters(page, location, date, () =>
            {
                var nextLocation = _locations.Count == 1 ? _locations[0].Id : PickedLocation(location);
                var nextDate = (date.SelectedDate ?? DateTime.Today).Date;
                if (nextLocation == _transferLocation && nextDate == _transferDate.Date)
                    return;
                _transferLocation = nextLocation;
                _transferDate = nextDate;
                Dispatcher.UIThread.Post(() => _ = ShowTransfers());
            });
            BindLocations(location, _locations.Count == 1 ? _locations[0].Id : _transferLocation);
            if (_locations.Count == 1)
                _transferLocation = _locations[0].Id;
            armTransfer();
            var company = Company();
            var rows = await _session.SelectRows(
                "stock_transfers",
                $"company_id=eq.{company}&select=id,numar,data_bon,source_warehouse_id,destination_warehouse_id&order=data_bon.desc");
            var day = _transferDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            var count = 0;
            if (rows.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in rows.EnumerateArray())
                {
                    if (TextOf(row, "data_bon") != day || !MatchesLocation(row, "source_warehouse_id", "destination_warehouse_id"))
                        continue;
                    count++;
                    var id = row.GetProperty("id").GetGuid();
                    var number = TextOf(row, "numar");
                    page.Children.Add(ActionButton(
                        "Nr. " + number + "  ·  " + day,
                        () => Dispatcher.UIThread.Post(() => _ = ShowTransferDetail(id))));
                }
            }
            if (count == 0)
                page.Children.Add(Muted("Nu există bonuri de transfer pentru filtrul ales."));
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
        page.Children.Add(ActionButton("Bon producție nou", () => Dispatcher.UIThread.Post(() => _ = ShowCreateProductionNote(null))));
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            await LoadPlaces();
        var location = new ComboBox { MinWidth = 220 };
        var date = new CalendarDatePicker { SelectedDate = _productionDate, Width = 160 };
        var armProduction = AddFilters(page, location, date, () =>
        {
            var nextLocation = _locations.Count == 1 ? _locations[0].Id : PickedLocation(location);
            var nextDate = (date.SelectedDate ?? DateTime.Today).Date;
            if (nextLocation == _productionLocation && nextDate == _productionDate.Date)
                return;
            _productionLocation = nextLocation;
            _productionDate = nextDate;
            Dispatcher.UIThread.Post(() => _ = ShowProductionNotes());
        });
            BindLocations(location, _locations.Count == 1 ? _locations[0].Id : _productionLocation);
            if (_locations.Count == 1)
                _productionLocation = _locations[0].Id;
            armProduction();
            var company = Company();
            var rows = await _session.SelectRows(
                "production_vouchers",
                $"company_id=eq.{company}&select=id,numar,data_bon,cantitate,unitate_masura,warehouse_id,product:products(denumire),warehouse:company_warehouses(denumire)&order=data_bon.desc");
            var day = _productionDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            var count = 0;
            if (rows.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in rows.EnumerateArray())
                {
                    if (TextOf(row, "data_bon") != day || !MatchesLocation(row, "warehouse_id"))
                        continue;
                    count++;
                    var id = row.GetProperty("id").GetGuid();
                    var number = TextOf(row, "numar");
                    var qty = TextOf(row, "cantitate");
                    var unit = TextOf(row, "unitate_masura");
                    var product = NestedText(row, "product", "denumire");
                    var warehouse = NestedText(row, "warehouse", "denumire");
                    page.Children.Add(ActionButton(
                        "BP " + number + "  ·  " + product + "  ·  " + qty + " " + unit
                            + (string.IsNullOrWhiteSpace(warehouse) ? "" : "  ·  " + warehouse),
                        () => Dispatcher.UIThread.Post(() => _ = ShowProductionDetail(id))));
                }
            }
            if (count == 0)
                page.Children.Add(Muted("Nu există bonuri de producție pentru filtrul ales."));
        }
        catch (Exception ex)
        {
            page.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private async Task ShowCreateProductionNote(Guid? existingId)
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 520 };
        page.Children.Add(Back("← Bonuri producție", () => Dispatcher.UIThread.Post(() => _ = ShowProductionNotes())));
        page.Children.Add(Title(existingId == null ? "Bon producție nou" : "Modifică bonul de producție"));
        _host.Child = new ScrollViewer { Content = page };

        var warehouseCombo = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch, MinHeight = 32 };
        var productCombo = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch, MinHeight = 32 };
        var qtyBox = QuantityBox();
        var date = new CalendarDatePicker { SelectedDate = DateTime.Today, Width = 160 };
        var status = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = Brushes.Firebrick };

        page.Children.Add(Muted("Data"));
        page.Children.Add(date);
        page.Children.Add(Muted("Gestiune"));
        page.Children.Add(warehouseCombo);
        page.Children.Add(Muted("Produs finit (cu rețetă)"));
        page.Children.Add(productCombo);
        page.Children.Add(Muted("Cantitate"));
        page.Children.Add(qtyBox);
        page.Children.Add(Muted("La salvare: +stoc produs finit, −consum rețetă pe gestiunea aleasă. Un produs finit din rețetă se scade din stocul lui."));
        page.Children.Add(status);

        try
        {
            var company = Company();
            var warehouses = await _session.SelectRows(
                "company_warehouses",
                $"company_id=eq.{company}&is_active=eq.true&select=id,denumire,work_location_id&order=denumire.asc");
            var products = await _session.SelectRows(
                "products",
                $"company_id=eq.{company}&has_recipe=eq.true&tip=eq.produs_finit&is_active=eq.true&select=id,denumire,cod,unitate_masura&order=denumire.asc");

            var warehouseItems = new List<NamedPick>();
            if (warehouses.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in warehouses.EnumerateArray())
                {
                    if (_session.IsStationCashier && !StationWarehouse(row))
                        continue;
                    warehouseItems.Add(new NamedPick(row.GetProperty("id").GetGuid(), TextOf(row, "denumire")));
                }
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

            if (existingId != null)
            {
                var current = await _session.SelectRows(
                    "production_vouchers",
                    $"id=eq.{existingId}&select=data_bon,cantitate,warehouse_id,product_id,observatii");
                if (current.ValueKind == JsonValueKind.Array && current.GetArrayLength() > 0)
                {
                    var row = current[0];
                    if (DateTime.TryParse(TextOf(row, "data_bon"), out var parsed))
                        date.SelectedDate = parsed;
                    qtyBox.SetQuantity(ShownQuantity(TextOf(row, "cantitate")));
                    SelectPick(warehouseCombo, warehouseItems, GuidOf(row, "warehouse_id"));
                    SelectPick(productCombo, productItems, GuidOf(row, "product_id"));
                }
            }
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
        save.Click += (_, _) => Dispatcher.UIThread.Post(() => _ = SaveProductionNote(existingId, date, warehouseCombo, productCombo, qtyBox, status));
        page.Children.Add(save);
    }

    private async Task SaveProductionNote(Guid? existingId, CalendarDatePicker date, ComboBox warehouseCombo, ComboBox productCombo, QuantityField qtyBox, TextBlock status)
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
            var qtyText = qtyBox.QuantityText.Trim().Replace(',', '.');
            if (!decimal.TryParse(qtyText, NumberStyles.Number, CultureInfo.InvariantCulture, out var qty) || qty <= 0)
            {
                status.Text = "Introduceți o cantitate mai mare decât zero.";
                return;
            }

            var company = Company();
            var day = (date.SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            if (existingId == null)
            {
                await _session.Rpc("post_production_voucher", new
                {
                    p_company_id = company.ToString(),
                    p_data_bon = day,
                    p_warehouse_id = warehouse.Id.ToString(),
                    p_product_id = product.Id.ToString(),
                    p_cantitate = qty,
                    p_observatii = (string?)null
                });
            }
            else
            {
                await _session.Rpc("update_production_voucher", new
                {
                    p_voucher_id = existingId.ToString(),
                    p_data_bon = day,
                    p_warehouse_id = warehouse.Id.ToString(),
                    p_product_id = product.Id.ToString(),
                    p_cantitate = qty,
                    p_observatii = (string?)null
                });
            }
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

    private async Task ShowProductionDetail(Guid id)
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 720 };
        page.Children.Add(Back("← Bonuri producție", () => Dispatcher.UIThread.Post(() => _ = ShowProductionNotes())));
        page.Children.Add(Title("Bon producție"));
        var edit = new Button
        {
            Content = "Modifică",
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brand.Brush(Brand.Gold),
            Foreground = Brushes.White,
            Padding = new Avalonia.Thickness(16, 10)
        };
        edit.Click += async (_, _) =>
        {
            if (await ConfirmSheetRecalc())
                await ShowCreateProductionNote(id);
        };
        page.Children.Add(edit);
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var rows = await _session.SelectRows(
                "production_vouchers",
                $"id=eq.{id}&select=numar,data_bon,cantitate,unitate_masura,observatii,product:products(denumire),warehouse:company_warehouses(denumire)");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Bonul nu mai există."));
                return;
            }
            var row = rows[0];
            page.Children.Add(Muted("Nr. " + TextOf(row, "numar") + "  ·  " + TextOf(row, "data_bon")));
            page.Children.Add(Muted(NestedText(row, "product", "denumire") + "  ·  " + TextOf(row, "cantitate") + " " + TextOf(row, "unitate_masura")));
            page.Children.Add(Muted("Gestiune: " + NestedText(row, "warehouse", "denumire")));
            if (!string.IsNullOrWhiteSpace(TextOf(row, "observatii")))
                page.Children.Add(Muted(TextOf(row, "observatii")));
            var lines = await _session.SelectRows(
                "production_voucher_lines",
                $"voucher_id=eq.{id}&select=cantitate,unitate_masura,product:products(denumire)&order=numar_linie.asc");
            page.Children.Add(Title("Consum"));
            if (lines.ValueKind == JsonValueKind.Array)
            {
                foreach (var line in lines.EnumerateArray())
                    page.Children.Add(Muted(NestedText(line, "product", "denumire") + "  ·  " + TextOf(line, "cantitate") + " " + TextOf(line, "unitate_masura")));
            }
        }
        catch (Exception ex)
        {
            page.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private async Task ShowTransferDetail(Guid id)
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 720 };
        page.Children.Add(Back("← Bonuri transfer", () => Dispatcher.UIThread.Post(() => _ = ShowTransfers())));
        page.Children.Add(Title("Bon transfer"));
        var edit = new Button
        {
            Content = "Modifică",
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brand.Brush(Brand.Gold),
            Foreground = Brushes.White,
            Padding = new Avalonia.Thickness(16, 10)
        };
        edit.Click += async (_, _) =>
        {
            if (await ConfirmSheetRecalc())
                await ShowTransferEdit(id);
        };
        page.Children.Add(edit);
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var rows = await _session.SelectRows(
                "stock_transfers",
                $"id=eq.{id}&select=numar,data_bon,observatii,source:company_warehouses!stock_transfers_source_warehouse_id_fkey(denumire),destination:company_warehouses!stock_transfers_destination_warehouse_id_fkey(denumire)");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Bonul nu mai există."));
                return;
            }
            var row = rows[0];
            page.Children.Add(Muted("Nr. " + TextOf(row, "numar") + "  ·  " + TextOf(row, "data_bon")));
            page.Children.Add(Muted(NestedText(row, "source", "denumire") + " → " + NestedText(row, "destination", "denumire")));
            if (!string.IsNullOrWhiteSpace(TextOf(row, "observatii")))
                page.Children.Add(Muted(TextOf(row, "observatii")));
            var lines = await _session.SelectRows(
                "stock_transfer_lines",
                $"transfer_id=eq.{id}&select=cantitate,unitate_masura,product:products(denumire)&order=numar_linie.asc");
            if (lines.ValueKind == JsonValueKind.Array)
            {
                foreach (var line in lines.EnumerateArray())
                    page.Children.Add(Muted(NestedText(line, "product", "denumire") + "  ·  " + TextOf(line, "cantitate") + " " + TextOf(line, "unitate_masura")));
            }
        }
        catch (Exception ex)
        {
            page.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private async Task ShowTransferEdit(Guid? id)
    {
        var creating = id == null;
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 640 };
        page.Children.Add(Back(creating ? "← Bonuri transfer" : "← Bon transfer", () =>
        {
            if (creating)
                Dispatcher.UIThread.Post(() => _ = ShowTransfers());
            else
                Dispatcher.UIThread.Post(() => _ = ShowTransferDetail(id!.Value));
        }));
        page.Children.Add(Title(creating ? "Bon transfer nou" : "Modifică bonul de transfer"));
        var date = new CalendarDatePicker { SelectedDate = DateTime.Today, Width = 160 };
        var source = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch };
        var destination = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch };
        var notes = new TextBox { Watermark = "Observații" };
        var linesPanel = new StackPanel { Spacing = 8 };
        var status = new TextBlock { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
        var drafts = new List<(ComboBox Product, QuantityField Qty)>();
        page.Children.Add(Muted("Data"));
        page.Children.Add(date);
        page.Children.Add(Muted("Din gestiunea"));
        page.Children.Add(source);
        page.Children.Add(Muted("În gestiunea"));
        page.Children.Add(destination);
        page.Children.Add(notes);
        page.Children.Add(linesPanel);
        page.Children.Add(status);
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var company = Company();
            var warehouses = await _session.SelectRows("company_warehouses", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire,work_location_id&order=denumire.asc");
            var products = await _session.SelectRows("products", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire,tip&order=denumire.asc");
            var sourceItems = new List<NamedPick>();
            var destinationItems = new List<NamedPick>();
            if (warehouses.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in warehouses.EnumerateArray())
                {
                    var pick = new NamedPick(row.GetProperty("id").GetGuid(), TextOf(row, "denumire"));
                    destinationItems.Add(pick);
                    if (!_session.IsStationCashier || StationWarehouse(row))
                        sourceItems.Add(pick);
                }
            }
            source.ItemsSource = sourceItems;
            destination.ItemsSource = destinationItems;
            var productItems = new List<NamedPick>();
            if (products.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in products.EnumerateArray())
                {
                    var tip = TextOf(row, "tip");
                    if (tip is "materie_prima" or "marfa" or "ambalaj" or "materiale_consumabile" or "materiale_curatenie" or "birotica" or "produs_finit")
                        productItems.Add(new NamedPick(row.GetProperty("id").GetGuid(), TextOf(row, "denumire")));
                }
            }
            if (!creating)
            {
                var header = await _session.SelectRows("stock_transfers", $"id=eq.{id}&select=data_bon,observatii,source_warehouse_id,destination_warehouse_id");
                if (header.ValueKind == JsonValueKind.Array && header.GetArrayLength() > 0)
                {
                    var row = header[0];
                    if (DateTime.TryParse(TextOf(row, "data_bon"), out var parsed))
                        date.SelectedDate = parsed;
                    notes.Text = TextOf(row, "observatii");
                    SelectPick(source, sourceItems, GuidOf(row, "source_warehouse_id"));
                    SelectPick(destination, destinationItems, GuidOf(row, "destination_warehouse_id"));
                }
            }
            else if (sourceItems.Count > 0)
            {
                source.SelectedIndex = 0;
                PairTransferWarehouse(source, destination, destinationItems);
            }
            var pairing = false;
            source.SelectionChanged += (_, _) =>
            {
                if (pairing)
                    return;
                pairing = true;
                PairTransferWarehouse(source, destination, destinationItems);
                pairing = false;
            };
            destination.SelectionChanged += (_, _) =>
            {
                if (pairing)
                    return;
                pairing = true;
                PairTransferWarehouse(destination, source, sourceItems);
                pairing = false;
            };
            var lines = creating
                ? default
                : await _session.SelectRows("stock_transfer_lines", $"transfer_id=eq.{id}&select=product_id,cantitate&order=numar_linie.asc");
            void AddLine(Guid? productId, string qty)
            {
                var product = new ComboBox { ItemsSource = productItems, HorizontalAlignment = HorizontalAlignment.Stretch };
                var qtyBox = QuantityBox(qty);
                qtyBox.HorizontalAlignment = HorizontalAlignment.Stretch;
                if (productId != null)
                    SelectPick(product, productItems, productId);
                drafts.Add((product, qtyBox));
                var card = new StackPanel { Spacing = 6 };
                card.Children.Add(product);
                card.Children.Add(Muted("Cantitate — scrieți aici"));
                card.Children.Add(qtyBox);
                linesPanel.Children.Add(new Border
                {
                    BorderBrush = Brand.Brush(Brand.Line),
                    BorderThickness = new Avalonia.Thickness(1),
                    CornerRadius = new Avalonia.CornerRadius(8),
                    Padding = new Avalonia.Thickness(10),
                    Child = card
                });
            }
            if (!creating && lines.ValueKind == JsonValueKind.Array)
                foreach (var line in lines.EnumerateArray())
                    AddLine(GuidOf(line, "product_id"), TextOf(line, "cantitate"));
            if (drafts.Count == 0)
                AddLine(null, "");
            var add = new Button { Content = "Adaugă linie", HorizontalAlignment = HorizontalAlignment.Left };
            add.Click += (_, _) => AddLine(null, "");
            page.Children.Add(add);
            var save = new Button
            {
                Content = "Salvează",
                HorizontalAlignment = HorizontalAlignment.Left,
                Background = Brand.Brush(Brand.Gold),
                Foreground = Brushes.White,
                Padding = new Avalonia.Thickness(16, 10)
            };
            save.Click += async (_, _) =>
            {
                try
                {
                    if (source.SelectedItem is not NamedPick from || destination.SelectedItem is not NamedPick to)
                    {
                        status.Text = "Alegeți gestiunile.";
                        return;
                    }
                    if (from.Id == to.Id)
                    {
                        status.Text = "Gestiunea de plecare și cea de sosire trebuie să fie diferite.";
                        return;
                    }
                    var payload = new List<object>();
                    foreach (var draft in drafts)
                    {
                        if (draft.Product.SelectedItem is not NamedPick product)
                            continue;
                        var text = draft.Qty.QuantityText.Trim().Replace(',', '.');
                        if (!decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var qty) || qty <= 0)
                            continue;
                        payload.Add(new { product_id = product.Id.ToString(), cantitate = qty });
                    }
                    if (payload.Count == 0)
                    {
                        status.Text = "Păstrați cel puțin o linie cu cantitate.";
                        return;
                    }
                    var day = (date.SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                    if (creating)
                    {
                        await _session.Rpc("post_stock_transfer", new
                        {
                            p_company_id = company.ToString(),
                            p_data_bon = day,
                            p_source_warehouse_id = from.Id.ToString(),
                            p_destination_warehouse_id = to.Id.ToString(),
                            p_observatii = notes.Text,
                            p_lines = payload
                        });
                    }
                    else
                    {
                        await _session.Rpc("update_stock_transfer", new
                        {
                            p_transfer_id = id!.Value.ToString(),
                            p_data_bon = day,
                            p_source_warehouse_id = from.Id.ToString(),
                            p_destination_warehouse_id = to.Id.ToString(),
                            p_observatii = notes.Text,
                            p_lines = payload
                        });
                    }
                    await ShowTransfers();
                }
                catch (Exception ex)
                {
                    status.Text = ex.Message;
                }
            };
            page.Children.Add(save);
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
        }
    }

    private async Task<bool> ConfirmSheetRecalc(string? message = null)
    {
        var done = new TaskCompletionSource<bool>();
        var window = new Window
        {
            Title = "Atenție",
            Width = 520,
            Height = 260,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            CanResize = false
        };
        var panel = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 16 };
        panel.Children.Add(new TextBlock
        {
            Text = message ?? "Modificarea acestui bon recalculează toate foile de stoc de la foaia afectată de bon până astăzi. Dacă stocurile nu se recalculează, ele se alterează și nu mai sunt afișate corect.",
            TextWrapping = TextWrapping.Wrap
        });
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, HorizontalAlignment = HorizontalAlignment.Right };
        var no = new Button { Content = "Renunță", Padding = new Avalonia.Thickness(12, 8) };
        var yes = new Button { Content = "Continuă", Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White, Padding = new Avalonia.Thickness(12, 8) };
        no.Click += (_, _) => { done.TrySetResult(false); window.Close(); };
        yes.Click += (_, _) => { done.TrySetResult(true); window.Close(); };
        window.Closed += (_, _) => done.TrySetResult(false);
        buttons.Children.Add(no);
        buttons.Children.Add(yes);
        panel.Children.Add(buttons);
        window.Content = panel;
        if (TopLevel.GetTopLevel(this) is Window parent)
            await window.ShowDialog(parent);
        else
            window.Show();
        return await done.Task;
    }

    private async Task LoadPlaces()
    {
        if (_locations.Count > 0)
            return;
        var company = Company();
        var locations = await _session.SelectRows("company_work_locations", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire&order=denumire.asc");
        var warehouses = await _session.SelectRows("company_warehouses", $"company_id=eq.{company}&select=id,work_location_id");
        var real = new List<NamedPick>();
        if (locations.ValueKind == JsonValueKind.Array)
            foreach (var row in locations.EnumerateArray())
                real.Add(new NamedPick(row.GetProperty("id").GetGuid(), TextOf(row, "denumire")));
        if (real.Count == 1)
            _locations.Add(real[0]);
        else
        {
            _locations.Add(new NamedPick(Guid.Empty, "Toate locațiile"));
            _locations.AddRange(real);
        }
        if (warehouses.ValueKind == JsonValueKind.Array)
        {
            foreach (var row in warehouses.EnumerateArray())
            {
                Guid? location = GuidOf(row, "work_location_id");
                _warehouseLocation[row.GetProperty("id").GetGuid()] = location;
            }
        }
    }

    private void BindLocations(ComboBox box, Guid? selected)
    {
        box.ItemsSource = _locations.ToList();
        box.SelectedIndex = 0;
        if (selected == null)
            return;
        for (var i = 0; i < _locations.Count; i++)
        {
            if (_locations[i].Id == selected)
            {
                box.SelectedIndex = i;
                return;
            }
        }
    }

    private Action AddFilters(StackPanel page, ComboBox location, CalendarDatePicker date, Action changed)
    {
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        if (_locations.Count != 1)
        {
            bar.Children.Add(new TextBlock { Text = "Locație", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
            bar.Children.Add(location);
        }
        bar.Children.Add(new TextBlock { Text = "Data", VerticalAlignment = VerticalAlignment.Center, Foreground = Brand.Brush(Brand.Navy) });
        bar.Children.Add(date);
        var armed = false;
        location.SelectionChanged += (_, _) => { if (armed) changed(); };
        date.SelectedDateChanged += (_, _) => { if (armed) changed(); };
        page.Children.Add(bar);
        return () => armed = true;
    }

    private bool StationWarehouse(JsonElement row)
    {
        if (!row.TryGetProperty("work_location_id", out var location) || !location.TryGetGuid(out var id))
            return false;
        return _session.StationLocationIds.Contains(id);
    }

    private static Guid? PickedLocation(ComboBox location)
    {
        if (location.SelectedItem is not NamedPick pick || pick.Id == Guid.Empty)
            return null;
        return pick.Id;
    }

    private bool MatchesLocation(JsonElement row, params string[] warehouseFields)
    {
        var selected = warehouseFields.Contains("source_warehouse_id") ? _transferLocation : _productionLocation;
        if (selected == null || selected == Guid.Empty)
            return true;
        foreach (var field in warehouseFields)
        {
            var id = GuidOf(row, field);
            if (id != null && _warehouseLocation.TryGetValue(id.Value, out var location) && location == selected)
                return true;
        }
        return false;
    }

    private static Guid? GuidOf(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            return null;
        return value.TryGetGuid(out var id) ? id : null;
    }

    private static string WarehousePairKey(string name)
    {
        var text = (name ?? "").Trim().ToLowerInvariant()
            .Replace('ă', 'a').Replace('â', 'a').Replace('î', 'i')
            .Replace('ș', 's').Replace('ş', 's').Replace('ț', 't').Replace('ţ', 't');
        if (text.Contains("ploiesti", StringComparison.Ordinal))
            return "ploiesti";
        if (text.Contains("agronomie", StringComparison.Ordinal) || text.Contains("agro", StringComparison.Ordinal))
            return "agronomie";
        return "";
    }

    private static void PairTransferWarehouse(ComboBox fromBox, ComboBox toBox, List<NamedPick> toItems)
    {
        if (fromBox.SelectedItem is not NamedPick from)
            return;
        var key = WarehousePairKey(from.Label);
        var want = key == "ploiesti" ? "agronomie" : key == "agronomie" ? "ploiesti" : "";
        if (want.Length == 0)
            return;
        for (var i = 0; i < toItems.Count; i++)
        {
            if (WarehousePairKey(toItems[i].Label) == want)
            {
                toBox.SelectedIndex = i;
                return;
            }
        }
    }

    private static void SelectPick(ComboBox box, List<NamedPick> items, Guid? id)
    {
        if (id == null)
            return;
        for (var i = 0; i < items.Count; i++)
        {
            if (items[i].Id == id)
            {
                box.SelectedIndex = i;
                return;
            }
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

    private static string ConsumptionMessage(Exception ex)
    {
        var text = ex.Message ?? "";
        if (text.Contains("CONSUMPTION_MOTIV_REQUIRED", StringComparison.Ordinal))
            return "Motivul consumului este obligatoriu.";
        if (text.Contains("CONSUMPTION_NO_LINES", StringComparison.Ordinal))
            return "Adăugați cel puțin un articol, cu cantitate.";
        if (text.Contains("CONSUMPTION_INVALID_QUANTITY", StringComparison.Ordinal))
            return "Scrieți cantitatea pentru fiecare articol.";
        if (text.Contains("CONSUMPTION_SHIFT_REQUIRED", StringComparison.Ordinal))
            return "Alegeți tura: 1 — ziua sau 2 — noapte.";
        return text;
    }

    private sealed record ShiftPick(int No, string Label)
    {
        public override string ToString() => Label;
    }

    private static int CurrentConsumptionShift()
    {
        TimeZoneInfo zone;
        try
        {
            zone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Bucharest");
        }
        catch (TimeZoneNotFoundException)
        {
            zone = TimeZoneInfo.Local;
        }
        catch (InvalidTimeZoneException)
        {
            zone = TimeZoneInfo.Local;
        }
        return TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, zone).Hour < 12 ? 2 : 1;
    }

    private static int? ShiftNo(JsonElement row)
    {
        if (!row.TryGetProperty("shift_no", out var value) || value.ValueKind != JsonValueKind.Number)
            return null;
        return value.GetInt32();
    }

    private static string ShiftSuffix(int? shift) => shift switch
    {
        1 => "  ·  1 — ziua",
        2 => "  ·  2 — noapte",
        _ => ""
    };

    private sealed class ConsumptionDraft
    {
        public ConsumptionDraft(QuantityField qty) => Qty = qty;
        public ConsumptionProduct? Product;
        public QuantityField Qty { get; }
    }

    private sealed record ConsumptionProduct(Guid Id, string Name, string Code, string Barcode, string Tip, string Unit)
    {
        public string Label
        {
            get
            {
                var code = string.IsNullOrWhiteSpace(Code) ? "" : Code + " · ";
                return code + Name;
            }
        }

        public override string ToString() => Label;
    }

    private async Task<ConsumptionProduct?> PickConsumptionProduct(List<ConsumptionProduct> catalog)
    {
        var window = new Window
        {
            Title = "Alege produs",
            Width = 640,
            Height = 560,
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var choices = FieldChoices.Options("products", "tip") ?? Array.Empty<FieldChoice>();
        var categoryLabels = new List<string> { "Toate categoriile" };
        var categoryCodes = new List<string?> { null };
        foreach (var choice in choices)
        {
            categoryLabels.Add(choice.Label);
            categoryCodes.Add(choice.Code);
        }
        var category = new ComboBox { ItemsSource = categoryLabels, SelectedIndex = 0, Margin = new Avalonia.Thickness(12, 12, 12, 0), HorizontalAlignment = HorizontalAlignment.Stretch };
        var search = new TextBox { Watermark = "Denumire, cod sau cod de bare", Margin = new Avalonia.Thickness(12) };
        var list = new ListBox { Margin = new Avalonia.Thickness(12, 0, 12, 12) };
        void Refresh()
        {
            var term = (search.Text ?? "").Trim();
            var index = category.SelectedIndex;
            var tip = index > 0 && index < categoryCodes.Count ? categoryCodes[index] : null;
            list.ItemsSource = catalog.Where(item =>
                (tip == null || item.Tip == tip)
                && (term.Length == 0
                    || item.Name.Contains(term, StringComparison.CurrentCultureIgnoreCase)
                    || item.Code.Contains(term, StringComparison.CurrentCultureIgnoreCase)
                    || item.Barcode.Contains(term, StringComparison.CurrentCultureIgnoreCase))).ToList();
        }
        category.SelectionChanged += (_, _) => Refresh();
        search.TextChanged += (_, _) => Refresh();
        Refresh();
        ConsumptionProduct? chosen = null;
        void Accept()
        {
            if (list.SelectedItem is ConsumptionProduct product)
            {
                chosen = product;
                window.Close();
            }
        }
        list.DoubleTapped += (_, _) => Accept();
        var ok = new Button { Content = "Alege", Margin = new Avalonia.Thickness(12), HorizontalAlignment = HorizontalAlignment.Left, IsEnabled = false };
        list.SelectionChanged += (_, _) => ok.IsEnabled = list.SelectedItem is ConsumptionProduct;
        ok.Click += (_, _) => Accept();
        var root = new DockPanel();
        DockPanel.SetDock(category, Dock.Top);
        DockPanel.SetDock(search, Dock.Top);
        DockPanel.SetDock(ok, Dock.Bottom);
        root.Children.Add(category);
        root.Children.Add(search);
        root.Children.Add(ok);
        root.Children.Add(list);
        window.Content = root;
        if (TopLevel.GetTopLevel(this) is Window parent)
            await window.ShowDialog(parent);
        else
            window.Show();
        return chosen;
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
            if (rows.GetArrayLength() == 1)
            {
                var only = rows[0];
                _enterPos(only.GetProperty("id").GetGuid(), TextOf(only, "denumire"));
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

    private async Task ShowConsumptions()
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 720 };
        page.Children.Add(Back("← Producție", ShowProduction));
        page.Children.Add(Title("Bon consum"));
        page.Children.Add(ActionButton("Bon consum nou", () => Dispatcher.UIThread.Post(() => _ = ShowConsumptionEdit(null))));
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            await LoadPlaces();
            var location = new ComboBox { MinWidth = 220 };
            var date = new CalendarDatePicker { SelectedDate = _consumptionDate, Width = 160 };
            var arm = AddFilters(page, location, date, () =>
            {
                var nextLocation = _locations.Count == 1 ? _locations[0].Id : PickedLocation(location);
                var nextDate = (date.SelectedDate ?? DateTime.Today).Date;
                if (nextLocation == _consumptionLocation && nextDate == _consumptionDate.Date)
                    return;
                _consumptionLocation = nextLocation;
                _consumptionDate = nextDate;
                Dispatcher.UIThread.Post(() => _ = ShowConsumptions());
            });
            BindLocations(location, _locations.Count == 1 ? _locations[0].Id : _consumptionLocation);
            if (_locations.Count == 1)
                _consumptionLocation = _locations[0].Id;
            arm();
            var rows = await _session.SelectRows(
                "consumption_vouchers",
                $"company_id=eq.{Company()}&select=id,numar,data_bon,shift_no,motiv,status,warehouse_id&order=data_bon.desc");
            var day = _consumptionDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            var count = 0;
            if (rows.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in rows.EnumerateArray())
                {
                    if (!TextOf(row, "data_bon").StartsWith(day, StringComparison.Ordinal) || !MatchesConsumption(row))
                        continue;
                    count++;
                    var id = row.GetProperty("id").GetGuid();
                    page.Children.Add(ActionButton(
                        "BC " + TextOf(row, "numar") + "  ·  " + ConsumptionStatus(TextOf(row, "status")) + ShiftSuffix(ShiftNo(row)) + "  ·  " + TextOf(row, "motiv"),
                        () => Dispatcher.UIThread.Post(() => _ = ShowConsumptionDetail(id))));
                }
            }
            if (count == 0)
                page.Children.Add(Muted("Nu există bonuri de consum pentru filtrul ales."));
        }
        catch (Exception ex)
        {
            page.Children.Add(new TextBlock { Text = ex.Message, Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap });
        }
    }

    private bool MatchesConsumption(JsonElement row)
    {
        if (_consumptionLocation == null || _consumptionLocation == Guid.Empty)
            return true;
        var id = GuidOf(row, "warehouse_id");
        return id != null && _warehouseLocation.TryGetValue(id.Value, out var location) && location == _consumptionLocation;
    }

    private static string ConsumptionStatus(string status) => status switch
    {
        "approved" => "Aprobat",
        "partial" => "Aprobat parțial",
        _ => "Neaprobat"
    };

    private async Task ShowConsumptionDetail(Guid id)
    {
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 720 };
        page.Children.Add(Back("← Bonuri consum", () => Dispatcher.UIThread.Post(() => _ = ShowConsumptions())));
        page.Children.Add(Title("Bon consum"));
        var status = new TextBlock { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var headerRows = await _session.SelectRows(
                "consumption_vouchers",
                $"id=eq.{id}&select=numar,data_bon,shift_no,motiv,status,created_by,warehouse:company_warehouses(denumire)");
            if (headerRows.ValueKind != JsonValueKind.Array || headerRows.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Bonul nu mai există."));
                return;
            }
            var header = headerRows[0];
            var voucherStatus = TextOf(header, "status");
            var createdBy = GuidOf(header, "created_by");
            var manager = !_session.IsStationCashier;
            var creator = _session.Profile != null && createdBy == _session.Profile.Id;
            page.Children.Add(Muted("BC " + TextOf(header, "numar") + "  ·  " + TextOf(header, "data_bon") + ShiftSuffix(ShiftNo(header)) + "  ·  " + NestedText(header, "warehouse", "denumire")));
            page.Children.Add(Muted("Motiv: " + TextOf(header, "motiv")));
            page.Children.Add(Muted(ConsumptionStatus(voucherStatus)));
            var lines = await _session.SelectRows(
                "consumption_voucher_lines",
                $"voucher_id=eq.{id}&select=id,cantitate,unitate_masura,aprobat,product:products(denumire)&order=numar_linie.asc");
            var checks = new List<(Guid Id, CheckBox Box)>();
            if (lines.ValueKind == JsonValueKind.Array)
            {
                foreach (var line in lines.EnumerateArray())
                {
                    var lineId = line.GetProperty("id").GetGuid();
                    var approved = line.TryGetProperty("aprobat", out var flag) && flag.ValueKind == JsonValueKind.True;
                    var box = new CheckBox
                    {
                        Content = NestedText(line, "product", "denumire") + "  ·  " + TextOf(line, "cantitate") + " " + TextOf(line, "unitate_masura"),
                        IsChecked = approved,
                        IsEnabled = manager
                    };
                    checks.Add((lineId, box));
                    page.Children.Add(box);
                }
            }
            page.Children.Add(status);
            if (voucherStatus == "draft" && (manager || creator))
            {
                page.Children.Add(ActionButton("Modifică", () => Dispatcher.UIThread.Post(() => _ = ShowConsumptionEdit(id))));
                page.Children.Add(ActionButton("Șterge", () => Dispatcher.UIThread.Post(() => _ = DeleteConsumption(id, status, false))));
            }
            else if (manager)
                page.Children.Add(ActionButton("Șterge", () => Dispatcher.UIThread.Post(() => _ = DeleteConsumption(id, status, true))));
            else if (voucherStatus != "draft")
                page.Children.Add(Muted("Bonul este blocat. Doar un manager îl poate redeschide, modifica sau șterge."));
            if (manager)
            {
                page.Children.Add(ActionButton("Aprobă bonul", () => Dispatcher.UIThread.Post(() => _ = ApproveConsumption(id, true, checks, status))));
                page.Children.Add(ActionButton("Salvează aprobarea pe linii", () => Dispatcher.UIThread.Post(() => _ = ApproveConsumption(id, false, checks, status))));
                if (voucherStatus != "draft")
                    page.Children.Add(ActionButton("Redeschide", () => Dispatcher.UIThread.Post(() => _ = ReopenConsumption(id, status))));
                page.Children.Add(Muted("Aprobarea, redeschiderea sau ștergerea unui bon aprobat recalculează foile de stoc de la data bonului până la ultima foaie emisă."));
            }
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
        }
    }

    private async Task ShowConsumptionEdit(Guid? id)
    {
        var creating = id == null;
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10, MaxWidth = 640 };
        page.Children.Add(Back(creating ? "← Bonuri consum" : "← Bon consum", () =>
        {
            if (creating)
                Dispatcher.UIThread.Post(() => _ = ShowConsumptions());
            else
                Dispatcher.UIThread.Post(() => _ = ShowConsumptionDetail(id!.Value));
        }));
        page.Children.Add(Title(creating ? "Bon consum nou" : "Modifică bonul de consum"));
        var date = new CalendarDatePicker { SelectedDate = DateTime.Today, Width = 160 };
        var shift = new ComboBox { Width = 220 };
        shift.Items.Add(new ShiftPick(1, "1 — ziua"));
        shift.Items.Add(new ShiftPick(2, "2 — noapte"));
        shift.SelectedIndex = CurrentConsumptionShift() == 2 ? 1 : 0;
        var warehouse = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch };
        var motiv = new TextBox { Watermark = "Motiv consum" };
        var linesPanel = new StackPanel { Spacing = 8 };
        var message = new TextBlock { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
        var drafts = new List<ConsumptionDraft>();
        page.Children.Add(Muted("Data"));
        page.Children.Add(date);
        page.Children.Add(Muted("Tură"));
        page.Children.Add(shift);
        page.Children.Add(Muted("După aprobare, consumul scade din foaia de stoc a datei și a turei alese. Ziua este tura 1. Noaptea este tura 2."));
        page.Children.Add(Muted("Gestiune"));
        page.Children.Add(warehouse);
        page.Children.Add(Muted("Motiv consum"));
        page.Children.Add(motiv);
        page.Children.Add(Muted("Motivul este obligatoriu. Bonul trebuie să aibă cel puțin un articol."));
        page.Children.Add(linesPanel);
        page.Children.Add(message);
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var company = Company();
            var warehouses = await _session.SelectRows("company_warehouses", $"company_id=eq.{company}&is_active=eq.true&select=id,denumire,work_location_id&order=denumire.asc");
            var warehouseItems = new List<NamedPick>();
            if (warehouses.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in warehouses.EnumerateArray())
                {
                    if (!_session.IsStationCashier || StationWarehouse(row))
                        warehouseItems.Add(new NamedPick(row.GetProperty("id").GetGuid(), TextOf(row, "denumire")));
                }
            }
            warehouse.ItemsSource = warehouseItems;
            var catalog = new List<ConsumptionProduct>();
            var pageRows = await _session.SelectAllPages(
                "products",
                $"company_id=eq.{company}&is_active=eq.true&select=id,denumire,cod,cod_bare,tip,unitate_masura&order=denumire.asc");
            foreach (var row in pageRows)
            {
                catalog.Add(new ConsumptionProduct(
                    row.GetProperty("id").GetGuid(),
                    TextOf(row, "denumire"),
                    TextOf(row, "cod"),
                    TextOf(row, "cod_bare"),
                    TextOf(row, "tip"),
                    TextOf(row, "unitate_masura")));
            }
            if (!creating)
            {
                var header = await _session.SelectRows("consumption_vouchers", $"id=eq.{id}&select=data_bon,shift_no,motiv,warehouse_id,status,created_by");
                if (header.ValueKind == JsonValueKind.Array && header.GetArrayLength() > 0)
                {
                    var row = header[0];
                    if (TextOf(row, "status") != "draft")
                    {
                        message.Text = "Bonul este blocat. Managerul îl redeschide înainte să îl modifice.";
                        return;
                    }
                    if (_session.IsStationCashier && GuidOf(row, "created_by") != _session.Profile?.Id)
                    {
                        message.Text = "Doar casierul care a creat bonul îl poate modifica.";
                        return;
                    }
                    if (DateTime.TryParse(TextOf(row, "data_bon"), out var parsed))
                        date.SelectedDate = parsed;
                    var savedShift = ShiftNo(row);
                    if (savedShift == 2)
                        shift.SelectedIndex = 1;
                    else if (savedShift == 1)
                        shift.SelectedIndex = 0;
                    motiv.Text = TextOf(row, "motiv");
                    SelectPick(warehouse, warehouseItems, GuidOf(row, "warehouse_id"));
                }
            }
            else if (warehouseItems.Count > 0)
                warehouse.SelectedIndex = 0;
            var existingLines = creating
                ? default
                : await _session.SelectRows("consumption_voucher_lines", $"voucher_id=eq.{id}&select=product_id,cantitate&order=numar_linie.asc");
            void AddLine(ConsumptionProduct? product, string qty, bool focusQuantity)
            {
                var qtyBox = QuantityBox(qty);
                qtyBox.HorizontalAlignment = HorizontalAlignment.Stretch;
                var draft = new ConsumptionDraft(qtyBox) { Product = product };
                var name = new TextBlock
                {
                    Text = product == null ? "Alegeți produsul" : product.Label,
                    TextWrapping = TextWrapping.Wrap,
                    FontWeight = FontWeight.SemiBold
                };
                var change = new Button { Content = product == null ? "Alege produs" : "Schimbă", HorizontalAlignment = HorizontalAlignment.Left };
                change.Click += async (_, _) =>
                {
                    var chosen = await PickConsumptionProduct(catalog);
                    if (chosen == null)
                        return;
                    draft.Product = chosen;
                    name.Text = chosen.Label;
                };
                var remove = new Button { Content = "Șterge", HorizontalAlignment = HorizontalAlignment.Left };
                var card = new StackPanel { Spacing = 6 };
                card.Children.Add(name);
                card.Children.Add(change);
                card.Children.Add(Muted("Cantitate" + (product == null || string.IsNullOrWhiteSpace(product.Unit) ? "" : " (" + product.Unit + ")")));
                card.Children.Add(draft.Qty);
                card.Children.Add(remove);
                var box = new Border
                {
                    BorderBrush = Brand.Brush(Brand.Line),
                    BorderThickness = new Avalonia.Thickness(1),
                    CornerRadius = new Avalonia.CornerRadius(8),
                    Padding = new Avalonia.Thickness(10),
                    Child = card
                };
                remove.Click += (_, _) =>
                {
                    drafts.Remove(draft);
                    linesPanel.Children.Remove(box);
                };
                drafts.Add(draft);
                linesPanel.Children.Add(box);
                if (focusQuantity)
                    Dispatcher.UIThread.Post(() => _ = EditQuantity(qtyBox));
            }
            if (!creating && existingLines.ValueKind == JsonValueKind.Array)
            {
                foreach (var line in existingLines.EnumerateArray())
                {
                    var productId = GuidOf(line, "product_id");
                    if (productId == null)
                        continue;
                    var product = catalog.FirstOrDefault(item => item.Id == productId)
                        ?? new ConsumptionProduct(productId.Value, "Produs", "", "", "", "");
                    AddLine(product, TextOf(line, "cantitate"), false);
                }
            }
            var add = new Button { Content = "Adaugă produs", HorizontalAlignment = HorizontalAlignment.Left };
            add.Click += async (_, _) =>
            {
                var chosen = await PickConsumptionProduct(catalog);
                if (chosen == null)
                    return;
                AddLine(chosen, "", true);
            };
            page.Children.Add(add);
            var save = new Button
            {
                Content = "Salvează",
                HorizontalAlignment = HorizontalAlignment.Left,
                Background = Brand.Brush(Brand.Gold),
                Foreground = Brushes.White,
                Padding = new Avalonia.Thickness(16, 10)
            };
            save.Click += async (_, _) =>
            {
                try
                {
                    if (warehouse.SelectedItem is not NamedPick place)
                    {
                        message.Text = "Alegeți gestiunea.";
                        return;
                    }
                    if (string.IsNullOrWhiteSpace(motiv.Text))
                    {
                        message.Text = "Motivul consumului este obligatoriu.";
                        return;
                    }
                    var payload = new List<object>();
                    var withProduct = 0;
                    foreach (var draft in drafts)
                    {
                        if (draft.Product == null)
                            continue;
                        withProduct++;
                        var text = draft.Qty.QuantityText.Trim().Replace(',', '.');
                        if (!decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var qty) || qty <= 0)
                        {
                            message.Text = "Scrieți cantitatea pentru fiecare articol.";
                            return;
                        }
                        payload.Add(new { product_id = draft.Product.Id.ToString(), cantitate = qty });
                    }
                    if (withProduct == 0)
                    {
                        message.Text = "Adăugați cel puțin un articol, cu cantitate.";
                        return;
                    }
                    var day = (date.SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                    var shiftNo = shift.SelectedItem is ShiftPick picked ? picked.No : CurrentConsumptionShift();
                    if (creating)
                    {
                        await _session.Rpc("post_consumption_voucher", new
                        {
                            p_company_id = company.ToString(),
                            p_data_bon = day,
                            p_shift_no = shiftNo,
                            p_warehouse_id = place.Id.ToString(),
                            p_motiv = motiv.Text,
                            p_lines = payload
                        });
                    }
                    else
                    {
                        await _session.Rpc("update_consumption_voucher", new
                        {
                            p_voucher_id = id!.Value.ToString(),
                            p_data_bon = day,
                            p_shift_no = shiftNo,
                            p_warehouse_id = place.Id.ToString(),
                            p_motiv = motiv.Text,
                            p_lines = payload
                        });
                    }
                    await ShowConsumptions();
                }
                catch (Exception ex)
                {
                    message.Text = ConsumptionMessage(ex);
                }
            };
            page.Children.Add(save);
        }
        catch (Exception ex)
        {
            message.Text = ex.Message;
        }
    }

    private async Task ApproveConsumption(Guid id, bool all, List<(Guid Id, CheckBox Box)> checks, TextBlock status)
    {
        try
        {
            var ids = checks.Where(item => item.Box.IsChecked == true).Select(item => item.Id.ToString()).ToArray();
            if (!all && ids.Length == 0)
            {
                status.Text = "Bifați cel puțin o linie.";
                return;
            }
            if (!await ConfirmSheetRecalc("Aprobarea acestui bon recalculează foile de stoc de la data bonului până la ultima foaie emisă. Dacă stocurile nu se recalculează, ele se alterează și nu mai sunt afișate corect."))
                return;
            await _session.Rpc("approve_consumption_voucher", new
            {
                p_voucher_id = id.ToString(),
                p_approve_all = all,
                p_line_ids = all ? Array.Empty<string>() : ids
            });
            await ShowConsumptions();
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
        }
    }

    private async Task ReopenConsumption(Guid id, TextBlock status)
    {
        try
        {
            if (!await ConfirmSheetRecalc("Redeschiderea acestui bon recalculează foile de stoc de la data bonului până la ultima foaie emisă. Dacă stocurile nu se recalculează, ele se alterează și nu mai sunt afișate corect."))
                return;
            await _session.Rpc("reopen_consumption_voucher", new { p_voucher_id = id.ToString() });
            await ShowConsumptionDetail(id);
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
        }
    }

    private async Task DeleteConsumption(Guid id, TextBlock status, bool recalc)
    {
        try
        {
            if (recalc && !await ConfirmSheetRecalc("Ștergerea acestui bon recalculează foile de stoc de la data bonului până la ultima foaie emisă. Dacă stocurile nu se recalculează, ele se alterează și nu mai sunt afișate corect."))
                return;
            await _session.Rpc("delete_consumption_voucher", new { p_voucher_id = id.ToString() });
            await ShowConsumptions();
        }
        catch (Exception ex)
        {
            status.Text = ex.Message;
        }
    }

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

    private bool _qtyPadOpen;

    private QuantityField QuantityBox(string text = "")
    {
        var field = new QuantityField(ShownQuantity(text));
        field.PadRequested += async (_, _) =>
        {
            var next = await QuantityPad(field.QuantityText);
            if (next != null)
                field.SetQuantity(next);
        };
        return field;
    }

    private async Task EditQuantity(QuantityField field)
    {
        var next = await QuantityPad(field.QuantityText);
        if (next != null)
            field.SetQuantity(next);
    }

    private sealed class QuantityField : Grid
    {
        private readonly TextBox _box;

        public event EventHandler? PadRequested;

        public QuantityField(string shown)
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto");
            MinHeight = 52;
            HorizontalAlignment = HorizontalAlignment.Stretch;
            _box = new TextBox
            {
                Watermark = "Scrieți cantitatea",
                MinHeight = 52,
                FontSize = 22,
                FontWeight = FontWeight.SemiBold,
                Padding = new Avalonia.Thickness(12, 10),
                HorizontalAlignment = HorizontalAlignment.Stretch,
                Background = new SolidColorBrush(Color.Parse("#FFF6E0")),
                BorderBrush = Brand.Brush(Brand.Gold),
                BorderThickness = new Avalonia.Thickness(2),
                CornerRadius = new Avalonia.CornerRadius(8)
            };
            ToolTip.SetTip(_box, "Se poate scrie în acest câmp");
            var pencil = new TextBlock
            {
                Text = "✎",
                FontSize = 22,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Avalonia.Thickness(8, 0, 0, 0),
                Foreground = Brand.Brush(Brand.Gold)
            };
            var pad = new Button
            {
                Content = "123",
                MinWidth = 64,
                MinHeight = 52,
                Margin = new Avalonia.Thickness(8, 0, 0, 0),
                Background = Brand.Brush(Brand.Navy),
                Foreground = Brushes.White
            };
            pad.Click += (_, _) => PadRequested?.Invoke(this, EventArgs.Empty);
            Grid.SetColumn(_box, 0);
            Grid.SetColumn(pencil, 1);
            Grid.SetColumn(pad, 2);
            Children.Add(_box);
            Children.Add(pencil);
            Children.Add(pad);
            SetQuantity(shown);
        }

        public string QuantityText => (_box.Text ?? "").Trim();

        public void SetQuantity(string shown)
        {
            _box.Text = shown.Trim();
        }
    }

    private static string ShownQuantity(string raw)
    {
        var text = raw.Trim().Replace(',', '.');
        if (!decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var qty))
            return "";
        return qty.ToString("0.####", CultureInfo.GetCultureInfo("ro-RO"));
    }

    private async Task<string?> QuantityPad(string initial)
    {
        if (_qtyPadOpen)
            return null;
        _qtyPadOpen = true;
        try
        {
            var value = NormalizeQty(initial);
            var committed = false;
            var done = new TaskCompletionSource<string?>();
            var window = new Window
            {
                Title = "Cantitate",
                Width = 360,
                SizeToContent = SizeToContent.Height,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                CanResize = false,
                Topmost = true,
                Icon = Brand.WindowIcon(),
                Background = Brushes.White
            };
            var display = new TextBlock
            {
                FontSize = 36,
                FontWeight = FontWeight.Bold,
                Foreground = Brand.Brush(Brand.Navy),
                HorizontalAlignment = HorizontalAlignment.Right,
                Margin = new Avalonia.Thickness(16, 12, 16, 8)
            };
            void Refresh()
            {
                display.Text = string.IsNullOrEmpty(value) ? "Cantitate" : value;
                display.Opacity = string.IsNullOrEmpty(value) ? 0.35 : 1;
            }
            void Push(string text)
            {
                value = NormalizeQty(value + text);
                Refresh();
            }
            void Backspace()
            {
                if (value.Length > 0)
                    value = value[..^1];
                Refresh();
            }
            void Commit()
            {
                committed = true;
                done.TrySetResult(value);
                window.Close();
            }
            var keys = new Grid
            {
                ColumnDefinitions = new ColumnDefinitions("*,*,*"),
                RowDefinitions = new RowDefinitions("Auto,Auto,Auto,Auto,Auto"),
                Margin = new Avalonia.Thickness(8, 0, 8, 12)
            };
            void Place(Control control, int column, int row, int columnSpan = 1)
            {
                Grid.SetColumn(control, column);
                Grid.SetRow(control, row);
                if (columnSpan > 1)
                    Grid.SetColumnSpan(control, columnSpan);
                keys.Children.Add(control);
            }
            string[,] digits =
            {
                { "7", "8", "9" },
                { "4", "5", "6" },
                { "1", "2", "3" }
            };
            for (var row = 0; row < 3; row++)
            {
                for (var column = 0; column < 3; column++)
                {
                    var digit = digits[row, column];
                    Place(PadKey(digit, () => Push(digit)), column, row);
                }
            }
            Place(PadKey(",", () => Push(",")), 0, 3);
            Place(PadKey("0", () => Push("0")), 1, 3);
            Place(PadKey("⌫", Backspace), 2, 3);
            Place(PadKey("Enter", Commit, accent: true), 0, 4, 3);
            var root = new StackPanel();
            root.Children.Add(display);
            root.Children.Add(keys);
            window.Content = root;
            window.Closed += (_, _) =>
            {
                if (!committed)
                    done.TrySetResult(null);
            };
            window.KeyDown += (_, e) =>
            {
                if (e.Key is >= Key.D0 and <= Key.D9)
                    Push(((int)e.Key - (int)Key.D0).ToString());
                else if (e.Key is >= Key.NumPad0 and <= Key.NumPad9)
                    Push(((int)e.Key - (int)Key.NumPad0).ToString());
                else if (e.Key is Key.OemComma or Key.OemPeriod or Key.Decimal)
                    Push(",");
                else if (e.Key == Key.Back)
                    Backspace();
                else if (e.Key is Key.Enter or Key.Return)
                    Commit();
                else
                    return;
                e.Handled = true;
            };
            Refresh();
            if (TopLevel.GetTopLevel(this) is Window parent)
                await window.ShowDialog(parent);
            else
                window.Show();
            return await done.Task;
        }
        finally
        {
            _qtyPadOpen = false;
        }
    }

    private static string NormalizeQty(string raw)
    {
        var result = "";
        var comma = false;
        var decimals = 0;
        foreach (var ch in raw.Replace('.', ','))
        {
            if (char.IsDigit(ch))
            {
                if (comma)
                {
                    if (decimals >= 8)
                        continue;
                    decimals++;
                }
                result += ch;
            }
            else if (ch == ',' && !comma)
            {
                comma = true;
                result = result.Length == 0 ? "0," : result + ",";
            }
        }
        return result;
    }

    private static Button PadKey(string label, Action action, bool accent = false)
    {
        var button = new Button
        {
            Content = label,
            FontSize = accent ? 18 : 26,
            FontWeight = FontWeight.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            MinHeight = accent ? 56 : 68,
            Margin = new Avalonia.Thickness(4),
            Background = accent ? Brand.Brush(Brand.Gold) : Brushes.White,
            Foreground = Brand.Brush(Brand.Navy),
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(1),
            CornerRadius = new Avalonia.CornerRadius(10)
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

