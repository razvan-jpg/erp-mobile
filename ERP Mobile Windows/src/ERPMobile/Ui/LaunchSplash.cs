using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Threading;

namespace ERPMobile.Ui;

public sealed class LaunchSplash : UserControl
{
    private const double InitializingSeconds = 5;
    private const double TotalSeconds = 10;
    private readonly SplashStage _stage = new();
    private readonly TextBlock _status;
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromMilliseconds(16) };
    private readonly TaskCompletionSource _finished = new();
    private DateTime _start;
    private bool _loadingCompanies;
    private bool _started;

    public LaunchSplash()
    {
        _status = new TextBlock
        {
            Text = "Se inițializează... v " + Brand.Version,
            FontSize = 20,
            FontWeight = FontWeight.Medium,
            Foreground = new SolidColorBrush(Color.FromArgb(235, 255, 255, 255)),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
            TextAlignment = TextAlignment.Center,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(32, 360, 32, 0)
        };
        Content = new Grid
        {
            Children = { _stage, _status }
        };
        _timer.Tick += (_, _) => Advance();
    }

    public Task Finished => _finished.Task;

    public void Start()
    {
        if (_started)
            return;
        _started = true;
        _start = DateTime.UtcNow;
        _stage.Elapsed = 0;
        _timer.Start();
    }

    private void Advance()
    {
        var elapsed = (DateTime.UtcNow - _start).TotalSeconds;
        _stage.Elapsed = elapsed;
        _stage.InvalidateVisual();
        if (!_loadingCompanies && elapsed >= InitializingSeconds)
        {
            _loadingCompanies = true;
            _status.Text = "Se încarcă societățile…";
        }
        var fade = 1.0;
        if (elapsed >= InitializingSeconds - 0.35 && elapsed < InitializingSeconds)
            fade = (InitializingSeconds - elapsed) / 0.35;
        else if (elapsed >= InitializingSeconds && elapsed < InitializingSeconds + 0.35)
            fade = (elapsed - InitializingSeconds) / 0.35;
        _status.Opacity = Math.Clamp(fade, 0, 1);
        if (elapsed < TotalSeconds)
            return;
        _timer.Stop();
        _finished.TrySetResult();
    }
}

sealed class SplashStage : Control
{
    private static readonly Color Gold = Color.FromRgb(219, 168, 61);
    private static readonly Color GoldLight = Color.FromRgb(245, 209, 115);
    private static readonly IBrush GoldBrush = new SolidColorBrush(Gold);
    private static readonly IBrush GoldLightBrush = new SolidColorBrush(GoldLight);

    public double Elapsed { get; set; }

    public override void Render(DrawingContext context)
    {
        var width = Bounds.Width;
        var height = Bounds.Height;
        if (width <= 1 || height <= 1)
            return;
        var bounds = new Rect(0, 0, width, height);
        context.FillRectangle(new LinearGradientBrush
        {
            StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
            EndPoint = new RelativePoint(1, 1, RelativeUnit.Relative),
            GradientStops =
            {
                new GradientStop(Color.FromRgb(10, 18, 41), 0),
                new GradientStop(Color.FromRgb(18, 28, 56), 0.55),
                new GradientStop(Color.FromRgb(13, 20, 46), 1)
            }
        }, bounds);
        context.FillRectangle(new RadialGradientBrush
        {
            Center = new RelativePoint(0.5, 0.46, RelativeUnit.Relative),
            GradientOrigin = new RelativePoint(0.5, 0.46, RelativeUnit.Relative),
            RadiusX = new RelativeScalar(0.42, RelativeUnit.Relative),
            RadiusY = new RelativeScalar(0.42, RelativeUnit.Relative),
            GradientStops =
            {
                new GradientStop(Color.FromArgb(46, 209, 158, 56), 0),
                new GradientStop(Colors.Transparent, 1)
            }
        }, bounds);

        var progress = Math.Clamp(Elapsed / 10.0, 0, 1);
        var center = new Point(width / 2, height / 2 - 36);
        using (context.PushTransform(Matrix.CreateTranslation(center.X, center.Y)))
        {
            DrawRings(context);
            DrawProgress(context, progress);
            DrawBars(context);
            DrawIcon(context);
            DrawSparkles(context);
        }
    }

    private void DrawRings(DrawingContext context)
    {
        for (var index = 0; index < 3; index++)
        {
            var phase = Elapsed * 0.9 + index * 2.1;
            var size = 170 + index * 34 + Math.Sin(phase) * 8;
            var scale = 0.92 + Math.Sin(phase * 0.7) * 0.06;
            var radius = size * scale / 2;
            var alpha = (byte)Math.Clamp((0.22 - index * 0.05) * 255, 0, 255);
            var pen = new Pen(new SolidColorBrush(Color.FromArgb(alpha, Gold.R, Gold.G, Gold.B)), 1.5);
            context.DrawEllipse(null, pen, new Point(0, 0), radius, radius);
        }
    }

    private static void DrawProgress(DrawingContext context, double progress)
    {
        const double radius = 98;
        context.DrawEllipse(null, new Pen(new SolidColorBrush(Color.FromArgb(20, 255, 255, 255)), 4), new Point(0, 0), radius, radius);
        if (progress <= 0.001)
            return;
        var pen = new Pen(new LinearGradientBrush
        {
            StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
            EndPoint = new RelativePoint(1, 1, RelativeUnit.Relative),
            GradientStops =
            {
                new GradientStop(Color.FromArgb(50, Gold.R, Gold.G, Gold.B), 0),
                new GradientStop(Gold, 0.45),
                new GradientStop(GoldLight, 0.75),
                new GradientStop(Gold, 1)
            }
        }, 4, lineCap: PenLineCap.Round);
        if (progress >= 0.999)
        {
            context.DrawEllipse(null, pen, new Point(0, 0), radius, radius);
            return;
        }
        var start = -Math.PI / 2;
        var sweep = progress * Math.PI * 2;
        var from = new Point(Math.Cos(start) * radius, Math.Sin(start) * radius);
        var to = new Point(Math.Cos(start + sweep) * radius, Math.Sin(start + sweep) * radius);
        var geometry = new StreamGeometry();
        using (var figure = geometry.Open())
        {
            figure.BeginFigure(from, false);
            figure.ArcTo(to, new Size(radius, radius), 0, sweep > Math.PI, SweepDirection.Clockwise);
            figure.EndFigure(false);
        }
        context.DrawGeometry(null, pen, geometry);
    }

    private void DrawBars(DrawingContext context)
    {
        double[] targets = [28, 42, 56, 72];
        var x = -40.0;
        for (var index = 0; index < targets.Length; index++)
        {
            var phase = Elapsed * 1.4 + index * 0.55;
            var height = targets[index] * (0.55 + 0.45 * ((Math.Sin(phase) + 1) / 2));
            var rect = new Rect(x, 128 - height, 14, height);
            context.FillRectangle(new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0.5, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0.5, 1, RelativeUnit.Relative),
                GradientStops = { new GradientStop(GoldLight, 0), new GradientStop(Gold, 1) }
            }, rect, 4);
            x += 22;
        }
    }

    private void DrawIcon(DrawingContext context)
    {
        var breathe = 0.96 + 0.04 * Math.Sin(Elapsed * 2.2);
        var tilt = Math.Sin(Elapsed * 0.85) * 4 * Math.PI / 180;
        var glow = 0.9 + 0.1 * Math.Sin(Elapsed * 1.6);
        using (context.PushTransform(Matrix.CreateScale(glow, glow)))
            context.DrawEllipse(new RadialGradientBrush
            {
                GradientStops =
                {
                    new GradientStop(Color.FromArgb(90, Gold.R, Gold.G, Gold.B), 0),
                    new GradientStop(Colors.Transparent, 1)
                }
            }, null, new Point(0, 0), 95, 95);

        using (context.PushTransform(Matrix.CreateRotation(tilt)))
        using (context.PushTransform(Matrix.CreateScale(breathe, breathe)))
        {
            var icon = new Rect(-78, -78, 156, 156);
            using (context.PushClip(new RoundedRect(icon, 34)))
            {
                context.DrawImage(Brand.Icon, icon);
                var sweep = (Math.Sin(Elapsed * 1.1 - Math.PI / 2) + 1) / 2;
                context.FillRectangle(
                    new SolidColorBrush(Color.FromArgb(70, 255, 255, 255)),
                    new Rect(-78 + sweep * 156 - 28, -78, 46, 156));
            }
            context.DrawRectangle(null, new Pen(new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(1, 1, RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.FromArgb(115, 255, 255, 255), 0),
                    new GradientStop(Color.FromArgb(140, Gold.R, Gold.G, Gold.B), 1)
                }
            }, 2), new RoundedRect(icon, 34));
        }
    }

    private void DrawSparkles(DrawingContext context)
    {
        for (var index = 0; index < 6; index++)
        {
            var phase = Elapsed * 1.8 + index * 1.15;
            var radius = 88 + (index % 3) * 18;
            var angle = phase * 0.7 + index * (Math.PI / 3);
            var alpha = (byte)Math.Clamp((0.25 + 0.55 * ((Math.Sin(phase * 2.5) + 1) / 2)) * 255, 0, 255);
            context.DrawEllipse(
                new SolidColorBrush(Color.FromArgb(alpha, GoldLight.R, GoldLight.G, GoldLight.B)),
                null,
                new Point(Math.Cos(angle) * radius, Math.Sin(angle) * radius * 0.65),
                2,
                2);
        }
    }
}
