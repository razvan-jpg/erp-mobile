using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Layout;
using Avalonia.Media;

namespace ERPMobile.Ui;

/// <summary>Imprimantă pe listare și dischetă pe salvarea PDF.</summary>
internal static class PdfGlyphs
{
    private const string PrinterData = "M7,2 H17 V6 H21 V15 H17 V22 H7 V15 H3 V6 H7 Z";
    private const string FloppyData = "M4,6 H14 L20,12 V22 H4 Z M8,2 H16 V8 H8 Z";

    public static void Set(Button button, string title, bool print, bool save)
    {
        var brush = button.Foreground ?? Brand.Brush(Brand.Navy);
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            VerticalAlignment = VerticalAlignment.Center
        };
        if (print)
            row.Children.Add(Glyph(PrinterData, brush));
        if (save)
            row.Children.Add(Glyph(FloppyData, brush));
        row.Children.Add(new TextBlock
        {
            Text = title,
            VerticalAlignment = VerticalAlignment.Center,
            Foreground = brush
        });
        button.Content = row;
    }

    private static Avalonia.Controls.Shapes.Path Glyph(string data, IBrush brush)
    {
        return new Avalonia.Controls.Shapes.Path
        {
            Data = StreamGeometry.Parse(data),
            Fill = brush,
            Width = 16,
            Height = 16,
            Stretch = Stretch.Uniform,
            VerticalAlignment = VerticalAlignment.Center
        };
    }
}
