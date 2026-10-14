using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public static class Brand
{
    public const string Version = "1.0.316";
    public const string Build = "188";
    public static readonly Color Navy = Color.Parse("#0B1F3A");
    public static readonly Color Gold = Color.Parse("#C6A15A");
    public static readonly Color Page = Color.Parse("#F4F6F8");
    public static readonly Color Muted = Color.Parse("#5C6B7A");
    public static readonly Color Line = Color.Parse("#E2E8F0");

    private static Bitmap? _icon;
    private static Bitmap? _nectarieLogo;

    public static Bitmap Icon
    {
        get
        {
            _icon ??= new Bitmap(AssetLoader.Open(new Uri("avares://ERPMobile/Assets/AppIcon.png")));
            return _icon;
        }
    }

    public static Bitmap NectarieLogo
    {
        get
        {
            _nectarieLogo ??= new Bitmap(AssetLoader.Open(new Uri("avares://ERPMobile/Assets/NectariePosLogo.jpg")));
            return _nectarieLogo;
        }
    }

    public static WindowIcon WindowIcon() => new(AssetLoader.Open(new Uri("avares://ERPMobile/Assets/AppIcon.ico")));

    private static readonly Dictionary<string, IImage> SidebarLogos = new(StringComparer.Ordinal);

    public static IImage SidebarLogo(CompanyRow? company)
    {
        if (company == null)
            return Icon;
        if (company.IsNectarie)
            return NectarieLogo;
        var key = company.Id + "|" + (company.LogoUrl ?? "");
        if (SidebarLogos.TryGetValue(key, out var cached))
            return cached;
        var image = DecodeLogo(company.LogoUrl) ?? InitialsLogo(company.Denumire);
        SidebarLogos[key] = image;
        return image;
    }

    private static Bitmap? DecodeLogo(string? stored)
    {
        if (string.IsNullOrWhiteSpace(stored) || !stored.StartsWith("data:", StringComparison.OrdinalIgnoreCase))
            return null;
        var comma = stored.IndexOf(',');
        if (comma < 0 || comma >= stored.Length - 1)
            return null;
        try
        {
            var bytes = Convert.FromBase64String(stored[(comma + 1)..]);
            return new Bitmap(new MemoryStream(bytes));
        }
        catch (FormatException)
        {
            return null;
        }
    }

    private static IImage InitialsLogo(string name)
    {
        var initials = Initials(name);
        var bitmap = new RenderTargetBitmap(new PixelSize(512, 512));
        using (var context = bitmap.CreateDrawingContext())
        {
            context.FillRectangle(new SolidColorBrush(InitialsColor(name)), new Rect(0, 0, 512, 512));
            var formatted = new FormattedText(
                initials,
                CultureInfo.GetCultureInfo("ro-RO"),
                FlowDirection.LeftToRight,
                new Typeface(FontFamily.Default, FontStyle.Normal, FontWeight.SemiBold),
                initials.Length > 1 ? 170 : 210,
                Brushes.White);
            context.DrawText(formatted, new Point((512 - formatted.Width) / 2, (512 - formatted.Height) / 2));
        }
        return bitmap;
    }

    private static string Initials(string name)
    {
        var words = name.Split(new[] { ' ', '-', '&', '/' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(word => word.Trim().Trim('.', ','))
            .Where(word => word.Length > 0 && word.ToUpperInvariant() is not ("SRL" or "SA" or "PFA" or "SRL-D"))
            .ToList();
        if (words.Count == 0)
            return name.Length == 0 ? "ER" : name[..Math.Min(2, name.Length)].ToUpperInvariant();
        if (words.Count == 1)
            return words[0][..Math.Min(2, words[0].Length)].ToUpperInvariant();
        return string.Concat(words[0][0], words[1][0]).ToUpperInvariant();
    }

    private static Color InitialsColor(string seed)
    {
        ulong hash = 5381;
        foreach (var ch in seed)
            hash = ((hash << 5) + hash) + ch;
        var hue = (hash % 360) / 360.0;
        return Hsv(hue, 0.58, 0.72);
    }

    private static Color Hsv(double hue, double saturation, double value)
    {
        var sector = hue * 6;
        var index = (int)Math.Floor(sector) % 6;
        var fraction = sector - Math.Floor(sector);
        var p = value * (1 - saturation);
        var q = value * (1 - fraction * saturation);
        var t = value * (1 - (1 - fraction) * saturation);
        double red;
        double green;
        double blue;
        switch (index)
        {
            case 0: red = value; green = t; blue = p; break;
            case 1: red = q; green = value; blue = p; break;
            case 2: red = p; green = value; blue = t; break;
            case 3: red = p; green = q; blue = value; break;
            case 4: red = t; green = p; blue = value; break;
            default: red = value; green = p; blue = q; break;
        }
        return Color.FromRgb((byte)(red * 255), (byte)(green * 255), (byte)(blue * 255));
    }

    public static SolidColorBrush Brush(string hex) => new(Color.Parse(hex));
    public static SolidColorBrush Brush(Color color) => new(color);
}
