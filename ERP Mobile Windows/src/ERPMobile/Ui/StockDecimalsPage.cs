using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed class StockDecimalsPage : UserControl
{
    private readonly AppSession _session;
    private readonly ComboBox _digits = new() { Width = 160 };
    private readonly TextBlock _status = new() { TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Muted) };
    private bool _loading = true;

    public StockDecimalsPage(AppSession session)
    {
        _session = session;
        _digits.ItemsSource = new[] { "2", "3", "4" };
        _digits.SelectedIndex = Math.Clamp(StockFormat.Digits - 2, 0, 2);
        _digits.IsEnabled = session.IsAdmin;
        _digits.SelectionChanged += async (_, _) => await Save();

        var page = new StackPanel { Margin = new Avalonia.Thickness(24), Spacing = 12, MaxWidth = 560 };
        page.Children.Add(new TextBlock
        {
            Text = "Zecimale stoc",
            FontSize = 22,
            FontWeight = FontWeight.SemiBold,
            Foreground = Brand.Brush(Brand.Navy)
        });
        page.Children.Add(new TextBlock
        {
            Text = "Cantitățile de stoc și rețetele. Prețurile rămân cu 2 zecimale.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = Brand.Brush(Brand.Muted)
        });
        page.Children.Add(_digits);
        if (!session.IsAdmin)
        {
            page.Children.Add(new TextBlock
            {
                Text = "Doar un administrator poate modifica numărul de zecimale.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brand.Brush(Brand.Muted)
            });
        }
        page.Children.Add(_status);
        Content = page;
        _loading = false;
    }

    private async Task Save()
    {
        if (_loading || !_session.IsAdmin)
            return;
        var company = _session.CurrentCompany;
        if (company == null || _digits.SelectedItem is not string selected || !int.TryParse(selected, out var digits))
            return;
        digits = StockFormat.Normalize(digits);
        _status.Text = "Se salvează...";
        _status.Foreground = Brand.Brush(Brand.Muted);
        try
        {
            await _session.UpsertRow("company_stock_settings", new Dictionary<string, object?>
            {
                ["company_id"] = company.Id,
                ["fraction_digits"] = digits
            }, "company_id");
            StockFormat.Apply(digits);
            _status.Text = "Salvat. Stocurile și rețetele folosesc " + digits + " zecimale.";
            _status.Foreground = Brushes.DarkGreen;
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.IndianRed;
        }
    }
}
