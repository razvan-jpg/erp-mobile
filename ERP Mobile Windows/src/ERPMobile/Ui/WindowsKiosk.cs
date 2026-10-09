using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace ERPMobile.Ui;

[SupportedOSPlatform("windows")]
internal static class WindowsKiosk
{
    private const int WhKeyboardLl = 13;
    private const int WmKeyDown = 0x0100;
    private const int WmSysKeyDown = 0x0104;
    private const int VkTab = 0x09;
    private const int VkEscape = 0x1B;
    private const int VkControl = 0x11;
    private const int VkLWin = 0x5B;
    private const int VkRWin = 0x5C;
    private const int LlkhfAltDown = 0x20;

    private static IntPtr _hook;
    private static LowLevelKeyboardProc? _proc;

    public static void Install()
    {
        if (_hook != IntPtr.Zero)
            return;
        _proc = OnKey;
        _hook = SetWindowsHookEx(WhKeyboardLl, _proc, GetModuleHandle(null), 0);
    }

    public static void Remove()
    {
        if (_hook == IntPtr.Zero)
            return;
        UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
        _proc = null;
    }

    private static IntPtr OnKey(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && (wParam == WmKeyDown || wParam == WmSysKeyDown))
        {
            var info = Marshal.PtrToStructure<KbdLlHook>(lParam);
            var alt = (info.Flags & LlkhfAltDown) != 0;
            var windowsKey = info.VkCode is VkLWin or VkRWin;
            var startMenu = info.VkCode == VkEscape && (alt || IsDown(VkControl));
            var switchApp = info.VkCode == VkTab && alt;
            if (windowsKey || startMenu || switchApp)
                return 1;
        }
        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    private static bool IsDown(int virtualKey) => (GetAsyncKeyState(virtualKey) & 0x8000) != 0;

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct KbdLlHook
    {
        public uint VkCode;
        public uint ScanCode;
        public uint Flags;
        public uint Time;
        public IntPtr Extra;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc proc, IntPtr module, uint threadId);

    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hook);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hook, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int virtualKey);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string? moduleName);
}
