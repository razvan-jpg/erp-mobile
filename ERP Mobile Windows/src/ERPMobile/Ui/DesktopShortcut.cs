namespace ERPMobile.Ui;

public static class DesktopShortcut
{
    public static string Create()
    {
        var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        if (string.IsNullOrWhiteSpace(desktop))
            desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
        var path = Path.Combine(desktop, "ERP Mobile.lnk");
        if (File.Exists(path))
            return "Scurtătura există deja pe Desktop.";
        var exe = Environment.ProcessPath;
        if (string.IsNullOrWhiteSpace(exe))
            throw new InvalidOperationException("Nu am găsit executabilul aplicației.");
        var type = Type.GetTypeFromProgID("WScript.Shell");
        if (type == null)
            throw new InvalidOperationException("Scurtătura se creează când aplicația rulează pe Windows.");
        dynamic shell = Activator.CreateInstance(type) ?? throw new InvalidOperationException("Nu am putut crea scurtătura.");
        dynamic shortcut = shell.CreateShortcut(path);
        shortcut.TargetPath = exe;
        shortcut.WorkingDirectory = Path.GetDirectoryName(exe);
        shortcut.Description = "ERP Mobile";
        shortcut.Save();
        return "Scurtătura a fost creată pe Desktop.";
    }
}
