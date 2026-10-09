using System.Globalization;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class DocumentSeriesView : UserControl
{
    private readonly AppSession _session;
    private readonly StackPanel _list = new() { Spacing = 8 };
    private readonly TextBlock _status = new() { Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap };
    private readonly List<LocationOption> _locations = new();

    public DocumentSeriesView(AppSession session)
    {
        _session = session;
        var root = new DockPanel { Margin = new Avalonia.Thickness(24) };
        var bar = new DockPanel { Margin = new Avalonia.Thickness(0, 0, 0, 12) };
        var add = new Button
        {
            Content = "Serie nouă",
            Background = Brand.Brush(Brand.Navy),
            Foreground = Brushes.White,
            Padding = new Avalonia.Thickness(14, 8),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        add.Click += (_, _) => _ = Edit(null);
        DockPanel.SetDock(add, Dock.Right);
        bar.Children.Add(add);
        bar.Children.Add(new TextBlock
        {
            Text = "Serii documente",
            FontSize = 22,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy),
            VerticalAlignment = VerticalAlignment.Center
        });
        DockPanel.SetDock(bar, Dock.Top);
        DockPanel.SetDock(_status, Dock.Bottom);
        _status.Margin = new Avalonia.Thickness(0, 12, 0, 0);
        root.Children.Add(bar);
        root.Children.Add(_status);
        root.Children.Add(new ScrollViewer { Content = _list });
        Content = root;
        _ = Reload();
    }

    private async Task Reload()
    {
        _list.Children.Clear();
        _locations.Clear();
        _status.Text = "";
        if (_session.CurrentCompany == null)
        {
            _status.Text = "Selectați o societate.";
            return;
        }
        try
        {
            var companyId = _session.CurrentCompany.Id;
            var locations = await _session.SelectRows(
                "company_work_locations",
                "company_id=eq." + companyId + "&select=id,denumire&order=denumire.asc");
            if (locations.ValueKind == JsonValueKind.Array)
            {
                foreach (var row in locations.EnumerateArray())
                {
                    var id = Text(row, "id");
                    if (Guid.TryParse(id, out var guid))
                        _locations.Add(new LocationOption(guid, Text(row, "denumire")));
                }
            }
            var rows = await _session.SelectRows(
                "document_series",
                "company_id=eq." + companyId + "&select=id,kind,serie,next_number,work_location_id,is_active&order=serie.asc");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                _list.Children.Add(new TextBlock
                {
                    Text = "Nicio serie. Adăugați o serie de factură fiscală pentru fiecare punct de lucru cu casă de marcat.",
                    TextWrapping = TextWrapping.Wrap,
                    Foreground = Brand.Brush(Brand.Muted)
                });
                return;
            }
            foreach (var row in rows.EnumerateArray())
                _list.Children.Add(Row(row));
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
        }
    }

    private Control Row(JsonElement row)
    {
        var id = Text(row, "id");
        var kind = Text(row, "kind");
        var serie = Text(row, "serie");
        var next = Text(row, "next_number");
        var active = row.TryGetProperty("is_active", out var flag) && flag.ValueKind == JsonValueKind.True;
        var locationId = Text(row, "work_location_id");
        var location = _locations.FirstOrDefault(item => item.Id.ToString() == locationId)?.Name ?? "";
        var card = new Border
        {
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            BorderThickness = new Avalonia.Thickness(1),
            CornerRadius = new Avalonia.CornerRadius(10),
            Padding = new Avalonia.Thickness(14, 10)
        };
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto") };
        var text = new StackPanel();
        text.Children.Add(new TextBlock { Text = serie, FontSize = 18, FontWeight = FontWeight.SemiBold, Foreground = Brand.Brush(Brand.Navy) });
        var detail = kind == "factura_fiscala_casa" ? "Factură fiscală casă" : "Factură";
        if (location.Length > 0)
            detail += " · " + location;
        if (!active)
            detail += " · inactivă";
        text.Children.Add(new TextBlock { Text = detail, Foreground = Brand.Brush(Brand.Muted) });
        grid.Children.Add(text);
        var number = new TextBlock
        {
            Text = "Următorul " + next,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Avalonia.Thickness(12, 0, 12, 0),
            Foreground = Brand.Brush(Brand.Navy)
        };
        Grid.SetColumn(number, 1);
        grid.Children.Add(number);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        var edit = new Button { Content = "Modifică", Background = Brushes.White };
        edit.Click += (_, _) => _ = Edit(row);
        var remove = new Button { Content = "Șterge", Background = Brushes.White, Foreground = Brushes.Firebrick };
        remove.Click += async (_, _) =>
        {
            if (!await ConfirmDialog.Ask(this, "Ștergeți seria " + serie + "?"))
                return;
            try
            {
                await _session.DeleteRow("document_series", id, queueOnFailure: false);
                await Reload();
            }
            catch (Exception ex)
            {
                _status.Text = ex.Message;
            }
        };
        buttons.Children.Add(edit);
        buttons.Children.Add(remove);
        Grid.SetColumn(buttons, 2);
        grid.Children.Add(buttons);
        card.Child = grid;
        return card;
    }

    private async Task Edit(JsonElement? existing)
    {
        var window = new Window
        {
            Title = existing == null ? "Serie nouă" : "Modificare serie",
            Width = 460,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            CanResize = false,
            Icon = Brand.WindowIcon(),
            Background = Brushes.White
        };
        var kind = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch };
        kind.Items.Add(new KindOption("factura_fiscala_casa", "Factură fiscală casă"));
        kind.Items.Add(new KindOption("factura", "Factură"));
        var serie = new TextBox { Watermark = "Serie" };
        var next = new TextBox { Watermark = "Număr următor" };
        var location = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch };
        foreach (var item in _locations)
            location.Items.Add(item);
        var active = new CheckBox { Content = "Activă", IsChecked = true };
        var hint = new TextBlock
        {
            Text = "Fiecare punct de lucru cu casă de marcat are o singură serie de factură fiscală.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted),
            FontSize = 12
        };
        var error = new TextBlock { Foreground = Brushes.Firebrick, TextWrapping = TextWrapping.Wrap };
        if (existing is JsonElement row)
        {
            var currentKind = Text(row, "kind");
            kind.SelectedItem = kind.Items.OfType<KindOption>().FirstOrDefault(item => item.Code == currentKind);
            serie.Text = Text(row, "serie");
            next.Text = Text(row, "next_number");
            var locationId = Text(row, "work_location_id");
            location.SelectedItem = _locations.FirstOrDefault(item => item.Id.ToString() == locationId);
            active.IsChecked = row.TryGetProperty("is_active", out var flag) && flag.ValueKind == JsonValueKind.True;
        }
        else
        {
            kind.SelectedIndex = 0;
            next.Text = "1";
            if (_locations.Count > 0)
                location.SelectedIndex = 0;
        }
        void RefreshKind()
        {
            var fiscal = (kind.SelectedItem as KindOption)?.Code == "factura_fiscala_casa";
            location.IsVisible = fiscal;
            hint.IsVisible = fiscal;
        }
        kind.SelectionChanged += (_, _) => RefreshKind();
        RefreshKind();
        var panel = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 10 };
        panel.Children.Add(Label("Tip"));
        panel.Children.Add(kind);
        panel.Children.Add(Label("Serie"));
        panel.Children.Add(serie);
        panel.Children.Add(Label("Număr următor"));
        panel.Children.Add(next);
        panel.Children.Add(Label("Punct de lucru"));
        panel.Children.Add(location);
        panel.Children.Add(hint);
        panel.Children.Add(active);
        panel.Children.Add(error);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8 };
        var cancel = new Button { Content = "Renunță", Padding = new Avalonia.Thickness(12, 6) };
        var save = new Button { Content = "Salvează", Padding = new Avalonia.Thickness(12, 6), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White };
        cancel.Click += (_, _) => window.Close();
        save.Click += async (_, _) =>
        {
            error.Text = "";
            var code = (serie.Text ?? "").Trim().ToUpperInvariant();
            if (code.Length == 0)
            {
                error.Text = "Completați seria.";
                return;
            }
            if (!int.TryParse(next.Text, NumberStyles.Integer, CultureInfo.InvariantCulture, out var number) || number < 1)
            {
                error.Text = "Numărul următor trebuie să fie cel puțin 1.";
                return;
            }
            var selectedKind = (kind.SelectedItem as KindOption)?.Code ?? "factura";
            var selectedLocation = location.SelectedItem as LocationOption;
            if (selectedKind == "factura_fiscala_casa" && selectedLocation == null)
            {
                error.Text = "Alegeți punctul de lucru al casei de marcat.";
                return;
            }
            if (_session.CurrentCompany == null)
                return;
            try
            {
                var payload = new Dictionary<string, object?>
                {
                    ["company_id"] = _session.CurrentCompany.Id.ToString(),
                    ["kind"] = selectedKind,
                    ["serie"] = code,
                    ["next_number"] = number,
                    ["is_active"] = active.IsChecked == true,
                    ["work_location_id"] = selectedKind == "factura_fiscala_casa" ? selectedLocation!.Id.ToString() : null
                };
                if (existing is JsonElement current)
                    await _session.UpdateRow("document_series", Text(current, "id"), payload, queueOnFailure: false);
                else
                    await _session.InsertRow("document_series", payload, queueOnFailure: false);
                window.Close();
                await Reload();
            }
            catch (Exception ex)
            {
                error.Text = ex.Message.Contains("document_series_one_fiscal", StringComparison.Ordinal)
                    ? "Acest punct de lucru are deja o serie de factură fiscală."
                    : ex.Message;
            }
        };
        buttons.Children.Add(cancel);
        buttons.Children.Add(save);
        panel.Children.Add(buttons);
        window.Content = panel;
        if (TopLevel.GetTopLevel(this) is Window owner)
            await window.ShowDialog(owner);
        else
            window.Show();
    }

    private static TextBlock Label(string text) => new()
    {
        Text = text,
        FontSize = 12,
        Foreground = Brand.Brush(Brand.Muted)
    };

    private static string Text(JsonElement row, string name)
    {
        if (!row.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            return "";
        return value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : value.ToString();
    }

    private sealed class KindOption
    {
        public KindOption(string code, string label)
        {
            Code = code;
            Label = label;
        }

        public string Code { get; }
        public string Label { get; }
        public override string ToString() => Label;
    }

    private sealed class LocationOption
    {
        public LocationOption(Guid id, string name)
        {
            Id = id;
            Name = name;
        }

        public Guid Id { get; }
        public string Name { get; }
        public override string ToString() => Name;
    }
}
