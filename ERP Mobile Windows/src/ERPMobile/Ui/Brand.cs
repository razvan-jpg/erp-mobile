using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

namespace ERPMobile.Ui;

public static class Brand
{
    public const string Version = "1.0.150";
    public const string Build = "150";
    public static readonly Color Navy = Color.Parse("#0B1F3A");
    public static readonly Color Gold = Color.Parse("#C6A15A");
    public static readonly Color Page = Color.Parse("#F4F6F8");
    public static readonly Color Muted = Color.Parse("#5C6B7A");
    public static readonly Color Line = Color.Parse("#E2E8F0");

    private static Bitmap? _icon;

    public static Bitmap Icon
    {
        get
        {
            _icon ??= new Bitmap(AssetLoader.Open(new Uri("avares://ERPMobile/Assets/AppIcon.png")));
            return _icon;
        }
    }

    public static WindowIcon WindowIcon() => new(AssetLoader.Open(new Uri("avares://ERPMobile/Assets/AppIcon.ico")));

    public static SolidColorBrush Brush(string hex) => new(Color.Parse(hex));
    public static SolidColorBrush Brush(Color color) => new(color);
}
