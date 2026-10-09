using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.Versioning;
using Microsoft.Win32;

namespace ERPMobile.Setup;

[SupportedOSPlatform("windows")]
public static class Installer
{
    public const string Version = "1.0.150";
    public const string DisplayName = "ERP Mobile";

    public static string InstallDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Programs",
        "Dateconta",
        "ERP Mobile");

    public static string AppExecutable => Path.Combine(InstallDirectory, "ERPMobile.exe");
    public static string UninstallExecutable => Path.Combine(InstallDirectory, "Dezinstaleaza ERP Mobile.exe");

    public static bool IsInstalled => File.Exists(AppExecutable);

    public static void Install(Action<string> report)
    {
        var payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip")
            ?? throw new InvalidOperationException("Kitul nu conține aplicația. Rulați din nou build-ul.");

        report("Se pregătește folderul...");
        if (Directory.Exists(InstallDirectory))
            Directory.Delete(InstallDirectory, recursive: true);
        Directory.CreateDirectory(InstallDirectory);

        report("Se copiază fișierele...");
        using (payload)
            ZipFile.ExtractToDirectory(payload, InstallDirectory);

        report("Se creează scurtăturile...");
        var setupSource = Environment.ProcessPath ?? Assembly.GetExecutingAssembly().Location;
        File.Copy(setupSource, UninstallExecutable, overwrite: true);
        CreateShortcut(DesktopShortcut, AppExecutable);
        CreateShortcut(StartMenuShortcut, AppExecutable);
        WriteUninstallKey();
        report("Instalarea s-a terminat.");
    }

    public static void Uninstall(Action<string> report)
    {
        report("Se șterg scurtăturile...");
        TryDelete(DesktopShortcut);
        TryDelete(StartMenuShortcut);
        try
        {
            Registry.CurrentUser.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\ERP Mobile", throwOnMissingSubKey: false);
        }
        catch
        {
            // The key may already be gone.
        }

        report("Se șterg fișierele...");
        var directory = InstallDirectory;
        if (Directory.Exists(directory))
        {
            var command = $"timeout /t 2 /nobreak > nul & rmdir /s /q \"{directory}\"";
            Process.Start(new ProcessStartInfo("cmd.exe", "/c " + command)
            {
                CreateNoWindow = true,
                UseShellExecute = false
            });
        }
        report("Dezinstalarea s-a terminat.");
    }

    public static void Launch()
    {
        if (File.Exists(AppExecutable))
            Process.Start(new ProcessStartInfo(AppExecutable) { UseShellExecute = true, WorkingDirectory = InstallDirectory });
    }

    private static string DesktopShortcut => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
        "ERP Mobile.lnk");

    private static string StartMenuShortcut => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
        "Programs",
        "ERP Mobile.lnk");

    private static void CreateShortcut(string shortcutPath, string target)
    {
        var directory = Path.GetDirectoryName(shortcutPath);
        if (!string.IsNullOrEmpty(directory))
            Directory.CreateDirectory(directory);
        var shellType = Type.GetTypeFromProgID("WScript.Shell")
            ?? throw new InvalidOperationException("Nu pot crea scurtătura Windows.");
        dynamic shell = Activator.CreateInstance(shellType)!;
        dynamic shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = target;
        shortcut.WorkingDirectory = Path.GetDirectoryName(target) ?? InstallDirectory;
        shortcut.Description = DisplayName;
        shortcut.IconLocation = target + ",0";
        shortcut.Save();
    }

    private static void WriteUninstallKey()
    {
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\ERP Mobile");
        key.SetValue("DisplayName", DisplayName);
        key.SetValue("DisplayVersion", Version);
        key.SetValue("Publisher", "Dateconta");
        key.SetValue("InstallLocation", InstallDirectory);
        key.SetValue("DisplayIcon", AppExecutable);
        key.SetValue("UninstallString", $"\"{UninstallExecutable}\" /uninstall");
        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
    }

    private static void TryDelete(string path)
    {
        if (File.Exists(path))
            File.Delete(path);
    }
}
