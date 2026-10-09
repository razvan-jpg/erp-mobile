using System.Net.Http;
using System.Net.Sockets;
using System.Text.Json;

namespace ERPMobile.Services;

public sealed class OfflineItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = "";
    public string Operation { get; set; } = "insert";
    public string Table { get; set; } = "";
    public string? RowId { get; set; }
    public Dictionary<string, object?>? Payload { get; set; }
    public string Status { get; set; } = "pending";
    public string? Error { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

public static class OfflineOutbox
{
    private static readonly JsonSerializerOptions Json = new() { WriteIndented = true };
    private static string PathName => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Dateconta",
        "ERP Mobile",
        "outbox.json");

    public static bool IsTransient(Exception exception)
    {
        for (var current = exception; current != null; current = current.InnerException)
        {
            if (current is HttpRequestException or TaskCanceledException or TimeoutException or SocketException)
                return true;
        }
        return false;
    }

    public static IReadOnlyList<OfflineItem> Load()
    {
        try
        {
            if (!File.Exists(PathName))
                return [];
            return JsonSerializer.Deserialize<List<OfflineItem>>(File.ReadAllText(PathName), Json) ?? [];
        }
        catch
        {
            return [];
        }
    }

    public static void Add(string operation, string table, string? rowId, Dictionary<string, object?>? payload, string title)
    {
        var items = Load().ToList();
        items.Add(new OfflineItem
        {
            Title = title,
            Operation = operation,
            Table = table,
            RowId = rowId,
            Payload = payload,
            Status = "pending"
        });
        Save(items);
    }

    public static void Discard(Guid id) => Save(Load().Where(item => item.Id != id).ToList());

    public static void Save(IReadOnlyList<OfflineItem> items)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(PathName)!);
        File.WriteAllText(PathName, JsonSerializer.Serialize(items, Json));
    }
}
