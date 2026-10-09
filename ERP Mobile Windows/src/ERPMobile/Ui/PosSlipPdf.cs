using QRCoder;
using SkiaSharp;

namespace ERPMobile.Ui;

public static class PosSlipPdf
{
    private const string AdFactura = "https://factura.dateconta.ro";
    private const string AdBeauty = "https://www.beautymanager.net";

    public readonly record struct Row(string Left, string Right, float Size, bool Bold, bool Center, string[]? Columns = null, string? Qr = null, string? QrLeft = null, string? QrRight = null);

    public static Row Title(string text) => new(text, "", 10, true, true);
    public static Row Center(string text, float size = 8) => new(text, "", size, false, true);
    public static Row Line(string text, float size = 8, bool bold = false) => new(text, "", size, bold, false);
    public static Row Pair(string left, string right, bool bold = false) => new(left, right, 8, bold, false);
    public static Row Cells(IReadOnlyList<string> values, float size = 7) => new("", "", size, false, false, values.ToArray());
    public static Row Qr(string text) => new("", "", 8, false, false, null, text, AdFactura, AdBeauty);

    public static byte[] Make(IReadOnlyList<Row> rows)
    {
        const float width = 227;
        const float margin = 8;
        var content = width - margin * 2;
        var typeface = SKTypeface.FromFamilyName("Segoe UI") ?? SKTypeface.FromFamilyName("Arial") ?? SKTypeface.Default;
        var boldTypeface = SKTypeface.FromFamilyName("Segoe UI", SKFontStyle.Bold)
            ?? SKTypeface.FromFamilyName("Arial", SKFontStyle.Bold)
            ?? typeface;
        var prepared = new List<Row>();
        foreach (var row in rows)
            prepared.AddRange(Wrap(row, content, row.Bold ? boldTypeface : typeface));

        float height = 12;
        foreach (var row in prepared)
            height += LineHeight(row, row.Bold ? boldTypeface : typeface) + 2;
        height += 10;

        using var stream = new MemoryStream();
        using var document = SKDocument.CreatePdf(stream);
        var canvas = document.BeginPage(width, Math.Max(height, 80));
        canvas.Clear(SKColors.White);
        float y = 10;
        foreach (var row in prepared)
        {
            var face = row.Bold ? boldTypeface : typeface;
            using var paint = new SKPaint
            {
                Color = SKColors.Black,
                IsAntialias = true,
                TextSize = row.Size,
                Typeface = face
            };
            var lineHeight = LineHeight(row, face);
            var baseline = y - paint.FontMetrics.Ascent;
            if (!string.IsNullOrEmpty(row.Qr))
            {
                var large = content;
                using (var bitmap = QrBitmap(row.Qr))
                {
                    if (bitmap != null)
                        canvas.DrawBitmap(bitmap, new SKRect(margin, y, margin + large, y + large));
                }
                var gap = 8f;
                var small = (content - gap) / 2f;
                var smallY = y + large + 6;
                using (var bitmap = QrBitmap(row.QrLeft ?? ""))
                {
                    if (bitmap != null)
                        canvas.DrawBitmap(bitmap, new SKRect(margin, smallY, margin + small, smallY + small));
                }
                using (var bitmap = QrBitmap(row.QrRight ?? ""))
                {
                    if (bitmap != null)
                        canvas.DrawBitmap(bitmap, new SKRect(margin + small + gap, smallY, margin + content, smallY + small));
                }
            }
            else if (row.Columns is { Length: > 0 } cells)
            {
                var slot = content / cells.Length;
                paint.TextAlign = SKTextAlign.Right;
                for (var i = 0; i < cells.Length; i++)
                {
                    canvas.Save();
                    canvas.ClipRect(new SKRect(margin + slot * i, y - 1, margin + slot * (i + 1) - 1, y + lineHeight + 4));
                    canvas.DrawText(cells[i], margin + slot * (i + 1) - 2, baseline, paint);
                    canvas.Restore();
                }
            }
            else if (row.Center)
            {
                paint.TextAlign = SKTextAlign.Center;
                canvas.DrawText(row.Left, width / 2, baseline, paint);
            }
            else if (row.Right.Length > 0)
            {
                var rightWidth = paint.MeasureText(row.Right);
                var leftLimit = Math.Max(40, content - rightWidth - 6);
                canvas.Save();
                canvas.ClipRect(new SKRect(0, y - 1, margin + leftLimit, y + lineHeight + 4));
                paint.TextAlign = SKTextAlign.Left;
                canvas.DrawText(row.Left, margin, baseline, paint);
                canvas.Restore();
                paint.TextAlign = SKTextAlign.Right;
                canvas.DrawText(row.Right, width - margin, baseline, paint);
            }
            else
            {
                paint.TextAlign = SKTextAlign.Left;
                canvas.DrawText(row.Left, margin, baseline, paint);
            }
            y += lineHeight + 2;
        }
        document.EndPage();
        document.Close();
        return stream.ToArray();
    }

    private static SKBitmap? QrBitmap(string text)
    {
        if (text.Length == 0)
            return null;
        using var generator = new QRCodeGenerator();
        var data = generator.CreateQrCode(text, QRCodeGenerator.ECCLevel.M);
        var png = new PngByteQRCode(data);
        return SKBitmap.Decode(png.GetGraphic(8));
    }

    private static float LineHeight(Row row, SKTypeface typeface)
    {
        if (!string.IsNullOrEmpty(row.Qr))
        {
            const float content = 211;
            return content + 6 + (content - 8) / 2f;
        }
        using var paint = new SKPaint { TextSize = row.Size, Typeface = typeface };
        return paint.FontMetrics.Descent - paint.FontMetrics.Ascent;
    }

    private static IEnumerable<Row> Wrap(Row row, float width, SKTypeface typeface)
    {
        if (!string.IsNullOrEmpty(row.Qr) || row.Columns is { Length: > 0 })
        {
            yield return row;
            yield break;
        }
        using var paint = new SKPaint { TextSize = row.Size, Typeface = typeface };
        var limit = width;
        if (row.Right.Length > 0)
            limit = Math.Max(40, width - paint.MeasureText(row.Right) - 6);
        var lines = BreakText(row.Left, limit, paint);
        var first = true;
        foreach (var line in lines)
        {
            yield return row with { Left = line, Right = first ? row.Right : "" };
            first = false;
        }
    }

    private static List<string> BreakText(string text, float limit, SKPaint paint)
    {
        var result = new List<string>();
        var current = "";
        foreach (var word in Pieces(text, limit, paint))
        {
            var trial = current.Length == 0 ? word : current + " " + word;
            if (paint.MeasureText(trial) <= limit)
                current = trial;
            else
            {
                if (current.Length > 0)
                    result.Add(current);
                current = word;
            }
        }
        if (current.Length > 0)
            result.Add(current);
        if (result.Count == 0)
            result.Add("");
        return result;
    }

    private static IEnumerable<string> Pieces(string text, float limit, SKPaint paint)
    {
        foreach (var word in text.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            if (paint.MeasureText(word) <= limit)
            {
                yield return word;
                continue;
            }
            var chunk = "";
            foreach (var character in word)
            {
                var trial = chunk + character;
                if (paint.MeasureText(trial) <= limit)
                    chunk = trial;
                else
                {
                    if (chunk.Length > 0)
                        yield return chunk;
                    chunk = character.ToString();
                }
            }
            if (chunk.Length > 0)
                yield return chunk;
        }
    }
}
