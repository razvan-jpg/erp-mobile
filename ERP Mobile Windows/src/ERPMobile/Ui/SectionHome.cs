using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ERPMobile.Data;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public sealed record ModuleSection(string Title, string Hint, IReadOnlyList<ListSpec> Lists, string? Note = null, Control? Custom = null);

public sealed class SectionHome : UserControl
{
    private readonly AppSession _session;
    private readonly AppModule _module;
    private readonly IReadOnlyList<ModuleSection> _sections;
    private readonly Border _host = new();

    public SectionHome(AppSession session, AppModule module, IReadOnlyList<ModuleSection> sections)
    {
        _session = session;
        _module = module;
        _sections = sections;
        Content = _host;
        ShowTiles();
    }

    private void ShowTiles()
    {
        var wrap = new WrapPanel();
        foreach (var section in _sections)
        {
            var chosen = section;
            wrap.Children.Add(Tile(section.Title, section.Hint, () => Dispatcher.UIThread.Post(() => Show(chosen))));
        }
        var page = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 12 };
        page.Children.Add(wrap);
        _host.Child = new ScrollViewer { Content = page };
    }

    private void Show(ModuleSection section)
    {
        var root = new DockPanel();
        var back = new Button
        {
            Content = "← " + _module.Name,
            Margin = new Avalonia.Thickness(20, 12, 20, 0),
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = Brushes.White
        };
        back.Click += (_, _) => Dispatcher.UIThread.Post(ShowTiles);
        DockPanel.SetDock(back, Dock.Top);
        root.Children.Add(back);
        if (section.Custom != null)
        {
            if (section.Custom.Parent is Panel panel)
                panel.Children.Remove(section.Custom);
            root.Children.Add(section.Custom);
        }
        else if (section.Lists.Count == 0)
            root.Children.Add(new TextBlock { Text = "Modul în dezvoltare.", Margin = new Avalonia.Thickness(24), TextWrapping = TextWrapping.Wrap });
        else
            root.Children.Add(new ModuleHost(_session, _module, section.Lists, section.Note));
        _host.Child = root;
    }

    internal static Button Tile(string title, string hint, Action open)
    {
        var text = new StackPanel { Spacing = 6 };
        text.Children.Add(new TextBlock { Text = title, FontWeight = FontWeight.SemiBold, FontSize = 16, Foreground = Brand.Brush(Brand.Navy), TextWrapping = TextWrapping.Wrap });
        text.Children.Add(new TextBlock { Text = hint, FontSize = 12, Foreground = Brand.Brush(Brand.Muted), TextWrapping = TextWrapping.Wrap, MaxHeight = 48 });
        var button = new Button
        {
            Width = 280,
            Height = 120,
            Margin = new Avalonia.Thickness(0, 0, 12, 12),
            Background = Brushes.White,
            BorderBrush = Brand.Brush(Brand.Line),
            CornerRadius = new Avalonia.CornerRadius(12),
            HorizontalContentAlignment = HorizontalAlignment.Left,
            VerticalContentAlignment = VerticalAlignment.Center,
            Padding = new Avalonia.Thickness(16),
            Content = text
        };
        button.Click += (_, _) => open();
        return button;
    }
}
