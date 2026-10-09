using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;

namespace ERPMobile.Setup;

public class App : Application
{
    public static bool Uninstall { get; private set; }

    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            Uninstall = Environment.GetCommandLineArgs().Any(arg =>
                arg.Equals("/uninstall", StringComparison.OrdinalIgnoreCase)
                || arg.Equals("-uninstall", StringComparison.OrdinalIgnoreCase));
            desktop.MainWindow = new SetupWindow();
        }
        base.OnFrameworkInitializationCompleted();
    }
}
