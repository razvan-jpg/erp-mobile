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
        _host.Child = new ScrollViewer { Content = page };
        try
        {
            var company = Company();
            var rows = await _session.SelectRows("products", $"company_id=eq.{company}&has_recipe=eq.true&is_active=eq.true&select=id,cod,denumire&order=denumire.asc");
            if (rows.ValueKind != JsonValueKind.Array || rows.GetArrayLength() == 0)
            {
                page.Children.Add(Muted("Nu există articole cu rețetă de producție."));
                return;
            }
            foreach (var row in rows.EnumerateArray())
            {
                var name = TextOf(row, "denumire");
                var code = TextOf(row, "cod");
                page.Children.Add(new TextBlock
                {
                    Text = string.IsNullOrWhiteSpace(code) ? name : name + "  ·  " + code,
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

