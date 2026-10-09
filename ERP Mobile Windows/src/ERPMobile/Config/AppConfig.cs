using System.Text.Json;

namespace ERPMobile.Config;

public sealed class AppConfig
{
    public string SupabaseUrl { get; init; } = "";
    public string SupabaseAnonKey { get; init; } = "";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(SupabaseUrl)
        && !string.IsNullOrWhiteSpace(SupabaseAnonKey)
        && !SupabaseUrl.Contains("YOUR_", StringComparison.Ordinal)
        && !SupabaseAnonKey.Contains("YOUR_", StringComparison.Ordinal);

    public static AppConfig Load()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "appconfig.json");
        if (!File.Exists(path))
            return new AppConfig();

        try
        {
            var json = File.ReadAllText(path);
            var parsed = JsonSerializer.Deserialize<AppConfig>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            return parsed ?? new AppConfig();
        }
        catch
        {
            return new AppConfig();
        }
    }
}
