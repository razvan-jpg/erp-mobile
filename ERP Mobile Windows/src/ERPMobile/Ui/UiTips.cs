using Avalonia.Controls;

namespace ERPMobile.Ui;

internal static class UiTips
{
    public static T WithTip<T>(this T control, string? tip) where T : Control
    {
        if (!string.IsNullOrWhiteSpace(tip))
            ToolTip.SetTip(control, tip);
        return control;
    }
}
