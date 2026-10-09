using System.Runtime.InteropServices;
using Tesseract;

namespace ERPMobile.Services.Utilities;

public static class ZettaOcr
{
    [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool SetDllDirectory(string path);

    public static string? Read(byte[] data, string extension)
    {
        var dir = Path.Combine(AppContext.BaseDirectory, "tessdata");
        if (!File.Exists(Path.Combine(dir, "ron.traineddata")))
            return null;
        if (OperatingSystem.IsWindows())
        {
            var native = Path.Combine(AppContext.BaseDirectory, Environment.Is64BitProcess ? "x64" : "x86");
            if (Directory.Exists(native))
                SetDllDirectory(native);
        }

        var temp = Path.Combine(Path.GetTempPath(), "erp-zetta-" + Guid.NewGuid().ToString("N") + extension);
        File.WriteAllBytes(temp, data);
        try
        {
            using var engine = new TesseractEngine(dir, "ron", EngineMode.Default);
            using var pix = Pix.LoadFromFile(temp);
            using var page = engine.Process(pix);
            var text = page.GetText()?.Trim();
            return string.IsNullOrWhiteSpace(text) ? null : text;
        }
        finally
        {
            try { File.Delete(temp); } catch { /* fișierul temporar poate fi încă deschis */ }
        }
    }
}
