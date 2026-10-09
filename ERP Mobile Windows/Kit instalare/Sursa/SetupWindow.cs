using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Threading;

namespace ERPMobile.Setup;

public sealed class SetupWindow : Window
{
    private readonly TextBlock _status;
    private readonly ProgressBar _progress;
    private readonly StackPanel _actions;

    public SetupWindow()
    {
        Title = App.Uninstall ? "ERP Mobile — Dezinstalare" : "ERP Mobile — Instalare";
        Width = 520;
        Height = 460;
        CanResize = false;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = Brushes.White;
        Icon = new WindowIcon(AssetLoader.Open(new Uri("avares://ERPMobile.Setup/Assets/AppIcon.ico")));

        var root = new StackPanel { Margin = new Avalonia.Thickness(28), Spacing = 14 };
        root.Children.Add(new Image
        {
            Source = new Bitmap(AssetLoader.Open(new Uri("avares://ERPMobile.Setup/Assets/AppIcon.png"))),
            Width = 84,
            Height = 84,
            HorizontalAlignment = HorizontalAlignment.Center
        });
        root.Children.Add(new TextBlock
        {
            Text = "ERP Mobile",
            FontSize = 26,
            FontWeight = FontWeight.Bold,
            HorizontalAlignment = HorizontalAlignment.Center,
            Foreground = new SolidColorBrush(Color.Parse("#0B1F3A"))
        });
        root.Children.Add(new TextBlock
        {
            Text = App.Uninstall
                ? "Se elimină ERP Mobile de pe acest calculator. Datele din baza de date rămân."
                : "Instalează ERP Mobile pentru Windows, cu aceeași iconiță și aceeași bază de date ca pe iPhone și Mac.",
            TextWrapping = TextWrapping.Wrap,
            TextAlignment = TextAlignment.Center,
            Foreground = new SolidColorBrush(Color.Parse("#5C6B7A"))
        });
        root.Children.Add(new TextBlock
        {
            Text = Installer.InstallDirectory,
            FontSize = 12,
            TextWrapping = TextWrapping.Wrap,
            TextAlignment = TextAlignment.Center,
            Foreground = new SolidColorBrush(Color.Parse("#5C6B7A"))
        });

        _progress = new ProgressBar { IsIndeterminate = false, Minimum = 0, Maximum = 100, Height = 8, IsVisible = false };
        root.Children.Add(_progress);
        _status = new TextBlock { TextWrapping = TextWrapping.Wrap, MinHeight = 40 };
        root.Children.Add(_status);

        _actions = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, Spacing = 8 };
        if (App.Uninstall)
        {
            _actions.Children.Add(Primary("Dezinstalează", RunUninstall));
        }
        else
        {
            _actions.Children.Add(Primary(Installer.IsInstalled ? "Reinstalează" : "Instalează", RunInstall));
            if (Installer.IsInstalled)
                _actions.Children.Add(Secondary("Dezinstalează", RunUninstall));
        }
        root.Children.Add(_actions);
        Content = root;
    }

    private async Task RunInstall()
    {
        await Run(report => Installer.Install(report), launchAfter: true);
    }

    private async Task RunUninstall()
    {
        await Run(report => Installer.Uninstall(report), launchAfter: false);
        _actions.Children.Clear();
        _actions.Children.Add(Primary("Închide", () => { Close(); return Task.CompletedTask; }));
    }

    private async Task Run(Action<Action<string>> work, bool launchAfter)
    {
        foreach (var child in _actions.Children)
        {
            if (child is Button button)
                button.IsEnabled = false;
        }
        _progress.IsVisible = true;
        _progress.IsIndeterminate = true;
        try
        {
            await Task.Run(() => work(message => Dispatcher.UIThread.Post(() => _status.Text = message)));
            _status.Text = launchAfter ? "ERP Mobile a fost instalat." : _status.Text;
            if (launchAfter)
                Installer.Launch();
            if (launchAfter)
                Close();
        }
        catch (Exception ex)
        {
            _status.Text = ex.Message;
            _status.Foreground = Brushes.IndianRed;
            foreach (var child in _actions.Children)
            {
                if (child is Button button)
                    button.IsEnabled = true;
            }
        }
        finally
        {
            _progress.IsIndeterminate = false;
        }
    }

    private static Button Primary(string text, Func<Task> action)
    {
        var button = new Button
        {
            Content = text,
            Padding = new Avalonia.Thickness(16, 8),
            Background = new SolidColorBrush(Color.Parse("#0B1F3A")),
            Foreground = Brushes.White,
            CornerRadius = new Avalonia.CornerRadius(8)
        };
        button.Click += async (_, _) => await action();
        return button;
    }

    private static Button Secondary(string text, Func<Task> action)
    {
        var button = new Button
        {
            Content = text,
            Padding = new Avalonia.Thickness(16, 8)
        };
        button.Click += async (_, _) => await action();
        return button;
    }
}
