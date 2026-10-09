using UglyToad.PdfPig;

namespace ERPMobile.Services.Utilities;

public static class PdfText
{
    public static List<string> Lines(byte[] data) => Pages(data).SelectMany(page => page).ToList();

    public static List<List<string>> Pages(byte[] data)
    {
        using var document = PdfDocument.Open(data);
        var pages = new List<List<string>>();
        foreach (var page in document.GetPages())
            pages.Add(PageLines(page));
        return pages;
    }

    private static List<string> PageLines(UglyToad.PdfPig.Content.Page page)
    {
        var lines = new List<string>();
        var words = page.GetWords().ToList();
        if (words.Count == 0)
        {
            var plain = page.Text?.Trim();
            if (!string.IsNullOrEmpty(plain))
                lines.AddRange(plain.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
            return lines;
        }

        var rows = words
            .GroupBy(word => Math.Round(word.BoundingBox.Bottom / 3.0) * 3.0)
            .OrderByDescending(group => group.Key);
        foreach (var row in rows)
        {
            var text = string.Join(" ", row.OrderBy(word => word.BoundingBox.Left).Select(word => word.Text)).Trim();
            if (text.Length > 0)
                lines.Add(text);
        }
        return lines;
    }
}
