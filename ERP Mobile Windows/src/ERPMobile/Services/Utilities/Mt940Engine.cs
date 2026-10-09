using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;

namespace ERPMobile.Services.Utilities;

public sealed class Mt940DailyFile
{
    public required string FileName { get; init; }
    public required string Content { get; init; }
    public required DateTime Date { get; init; }
}

public static class Mt940Engine
{
    public static List<Mt940DailyFile> Build(IReadOnlyList<(string Name, byte[] Data)> files, string companyName)
    {
        var transactions = new List<Tx>();
        string currency = "RON";
        string field20 = "";
        string field25 = "";
        string field28 = "";
        decimal opening = 0;
        var footer = new List<string>();
        string holder = "";

        foreach (var file in files)
        {
            var text = ReadText(file.Name, file.Data);
            if (string.IsNullOrWhiteSpace(text))
                throw new InvalidOperationException("Fișierul " + file.Name + " este gol sau PDF-ul nu are text selectabil.");
            var parsed = Parse(text, file.Name);
            if (parsed.Transactions.Count == 0)
                throw new InvalidOperationException("Nu am găsit tranzacții în " + file.Name + ".");
            transactions.AddRange(parsed.Transactions);
            if (parsed.Currency.Length > 0)
                currency = parsed.Currency;
            if (field20.Length == 0)
                field20 = parsed.Field20;
            if (field25.Length == 0)
                field25 = parsed.Field25;
            if (field28.Length == 0)
                field28 = parsed.Field28;
            if (parsed.HasOpening)
                opening = parsed.Opening;
            footer.AddRange(parsed.Footer);
            if (holder.Length == 0)
                holder = parsed.Holder;
        }

        if (transactions.Count == 0)
            throw new InvalidOperationException("Nu am găsit tranzacții în fișierele încărcate.");

        if (holder.Length == 0)
            holder = companyName.Trim();

        var days = transactions
            .GroupBy(tx => tx.Date.Date)
            .OrderBy(group => group.Key)
            .ToList();
        var balance = opening;
        var firm = Sanitize(holder);
        var result = new List<Mt940DailyFile>();
        foreach (var day in days)
        {
            var items = day.OrderBy(tx => tx.Field61, StringComparer.Ordinal).ToList();
            var dayOpening = balance;
            foreach (var tx in items)
                balance += tx.IsDebit ? -tx.Amount : tx.Amount;
            var code = day.Key.ToString("yyMMdd", CultureInfo.InvariantCulture);
            var iso = day.Key.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            var lines = new List<string>
            {
                field20.Length == 0 ? ":20:STMT" + code : ReplaceDate(field20, ":20:", code),
                field25.Length == 0 ? ":25:IMPORT/BANK" : field25,
                field28.Length == 0 ? ":28C:00001/00001" : field28,
                ":60F:C" + code + currency + Amount(dayOpening)
            };
            foreach (var tx in items)
            {
                lines.Add(tx.Field61);
                lines.Add(":86:" + tx.Narrative);
            }
            lines.Add(":62F:C" + code + currency + Amount(balance));
            lines.Add(":64:C" + code + currency + Amount(balance));
            if (footer.Count > 0)
                lines.AddRange(footer.Distinct());
            else if (holder.Length > 0)
                lines.Add(":86:NAME ACCOUNT OWNER: " + holder);
            result.Add(new Mt940DailyFile
            {
                Date = day.Key,
                FileName = firm.Length == 0 ? "MT940_" + iso + ".txt" : "MT940_" + firm + "_" + iso + ".txt",
                Content = string.Join("\n", lines) + "\n"
            });
        }
        return result;
    }

    public static string ArchiveName(string companyName, IReadOnlyList<Mt940DailyFile> files)
    {
        var firm = Sanitize(companyName);
        var first = files.Min(file => file.Date).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var last = files.Max(file => file.Date).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var period = first == last ? first : first + "_" + last;
        return firm.Length == 0 ? "MT940_" + period + ".zip" : "MT940_" + firm + "_" + period + ".zip";
    }

    public static void Write(string folder, string archiveName, IReadOnlyList<Mt940DailyFile> files)
    {
        Directory.CreateDirectory(folder);
        foreach (var file in files)
            File.WriteAllText(Path.Combine(folder, file.FileName), file.Content, new UTF8Encoding(false));
        var zipPath = Path.Combine(folder, archiveName);
        if (File.Exists(zipPath))
            File.Delete(zipPath);
        using var zip = ZipFile.Open(zipPath, ZipArchiveMode.Create);
        foreach (var file in files)
        {
            var entry = zip.CreateEntry(file.FileName, CompressionLevel.Optimal);
            using var writer = new StreamWriter(entry.Open(), new UTF8Encoding(false));
            writer.Write(file.Content);
        }
    }

    private static string ReadText(string name, byte[] data)
    {
        if (name.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                return string.Join("\n", PdfText.Lines(data));
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Nu am putut citi PDF-ul " + name + ". " + ex.Message);
            }
        }
        return Encoding.UTF8.GetString(data);
    }

    private static Parsed Parse(string text, string fileName)
    {
        var normalized = text.Replace("\r\n", "\n").Replace('\r', '\n');
        if (normalized.Contains(":61:", StringComparison.Ordinal))
            return ParseNative(normalized);
        if (fileName.EndsWith(".csv", StringComparison.OrdinalIgnoreCase) || LooksLikeCsv(normalized))
            return ParseCsv(normalized);
        return ParseStatement(normalized);
    }

    private static bool LooksLikeCsv(string text)
    {
        var first = text.Split('\n', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? "";
        return first.Contains(';') || (first.Contains(',') && first.Contains("data", StringComparison.OrdinalIgnoreCase));
    }

    private static Parsed ParseNative(string text)
    {
        var parsed = new Parsed();
        string? pending = null;
        foreach (var raw in text.Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length == 0)
                continue;
            if (line.StartsWith(":20:", StringComparison.Ordinal))
                parsed.Field20 = line;
            else if (line.StartsWith(":25:", StringComparison.Ordinal))
                parsed.Field25 = line;
            else if (line.StartsWith(":28C:", StringComparison.Ordinal))
                parsed.Field28 = line;
            else if (line.StartsWith(":60F:", StringComparison.Ordinal))
            {
                if (TryBalance(line, out var date, out var currency, out var amount))
                {
                    parsed.Opening = amount;
                    parsed.HasOpening = true;
                    parsed.Currency = currency;
                    parsed.OpeningDate = date;
                }
            }
            else if (line.StartsWith(":61:", StringComparison.Ordinal))
                pending = line;
            else if (line.StartsWith(":86:", StringComparison.Ordinal))
            {
                var body = line.Length > 4 ? line[4..] : "";
                if (pending != null && TryTransaction(pending, body, out var tx))
                {
                    parsed.Transactions.Add(tx);
                    pending = null;
                }
                else
                    parsed.Footer.Add(line);
            }
        }
        parsed.Holder = HolderFrom(text);
        return parsed;
    }

    private static Parsed ParseCsv(string text)
    {
        var lines = text.Split('\n').Select(line => line.Trim()).Where(line => line.Length > 0).ToList();
        if (lines.Count < 2)
            throw new InvalidOperationException("CSV-ul nu are tranzacții.");
        var delimiter = lines[0].Contains(';') ? ';' : ',';
        var headers = lines[0].Split(delimiter).Select(Fold).ToList();
        var dateIndex = IndexOf(headers, "data", "date");
        var amountIndex = IndexOf(headers, "sum", "amount", "valoare");
        var detailsIndex = IndexOf(headers, "desc", "detal", "explic");
        if (dateIndex < 0)
            dateIndex = 0;
        if (amountIndex < 0)
            amountIndex = 1;
        var parsed = new Parsed { Field25 = ":25:IMPORT/CSV", Field28 = ":28C:00001/00001" };
        decimal running = 0;
        foreach (var line in lines.Skip(1))
        {
            var cols = line.Split(delimiter);
            if (cols.Length <= Math.Max(dateIndex, amountIndex))
                continue;
            if (!TryDate(cols[dateIndex], out var date))
                continue;
            if (!TryAmount(cols[amountIndex], out var signed, out _))
                continue;
            var details = detailsIndex >= 0 && detailsIndex < cols.Length ? cols[detailsIndex].Trim().Trim('"') : "";
            var debit = signed < 0;
            var amount = Math.Abs(signed);
            running += signed;
            parsed.Transactions.Add(Make(date, debit, amount, details));
        }
        if (parsed.Transactions.Count == 0)
            throw new InvalidOperationException("CSV-ul nu are tranzacții recunoscute.");
        parsed.Opening = 0;
        parsed.HasOpening = true;
        parsed.Field20 = ":20:STMT" + parsed.Transactions.Min(tx => tx.Date).ToString("yyMMdd", CultureInfo.InvariantCulture);
        parsed.Holder = HolderFrom(text);
        return parsed;
    }

    private static Parsed ParseStatement(string text)
    {
        var parsed = new Parsed { Field25 = ":25:IMPORT/PDF", Field28 = ":28C:00001/00001", HasOpening = true };
        var patterns = new[]
        {
            new Regex(@"(\d{2}[.\-/]\d{2}[.\-/]\d{2,4})\s+(.{4,180}?)\s+(\(?[-+]?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}\)?)", RegexOptions.IgnoreCase),
            new Regex(@"(\d{4}-\d{2}-\d{2})\s+(.{4,180}?)\s+(\(?[-+]?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}\)?)", RegexOptions.IgnoreCase)
        };
        var seen = new HashSet<string>();
        foreach (var pattern in patterns)
        {
            foreach (Match match in pattern.Matches(text))
            {
                if (!TryDate(match.Groups[1].Value, out var date))
                    continue;
                var narrative = match.Groups[2].Value.Trim();
                if (narrative.Length < 3 || IsHeader(narrative))
                    continue;
                if (!TryAmount(match.Groups[3].Value, out var signed, out var markedDebit))
                    continue;
                var amount = Math.Abs(signed);
                if (amount == 0)
                    continue;
                var debit = markedDebit || signed < 0;
                var key = date.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + "|" + debit + "|" + amount.ToString(CultureInfo.InvariantCulture) + "|" + narrative[..Math.Min(40, narrative.Length)];
                if (!seen.Add(key))
                    continue;
                parsed.Transactions.Add(Make(date, debit, amount, narrative));
            }
            if (parsed.Transactions.Count > 0)
                break;
        }
        parsed.Holder = HolderFrom(text);
        parsed.Field20 = parsed.Transactions.Count == 0
            ? ""
            : ":20:STMT" + parsed.Transactions.Min(tx => tx.Date).ToString("yyMMdd", CultureInfo.InvariantCulture);
        return parsed;
    }

    private static Tx Make(DateTime date, bool debit, decimal amount, string narrative)
    {
        var code = date.ToString("yyMMdd", CultureInfo.InvariantCulture);
        var reference = Guid.NewGuid().ToString("N")[..8];
        return new Tx(date, debit, amount, ":61:" + code + (debit ? "D" : "C") + Amount(amount) + "NTRFNONREF//" + reference, narrative.Length == 0 ? "Tranzactie extras banca" : narrative);
    }

    private static bool TryTransaction(string field61, string narrative, out Tx tx)
    {
        tx = null!;
        var body = field61.StartsWith(":61:", StringComparison.Ordinal) ? field61[4..] : field61;
        if (body.Length < 10 || !TrySwiftDate(body[..6], out var date))
            return false;
        var rest = body[6..];
        var mark = rest.IndexOfAny(['C', 'D']);
        if (mark < 0)
            return false;
        var debit = rest[mark] == 'D';
        var after = rest[(mark + 1)..];
        var end = 0;
        while (end < after.Length && (char.IsDigit(after[end]) || after[end] == ','))
            end++;
        if (end == 0 || !TryAmount(after[..end], out var amount, out _))
            return false;
        tx = new Tx(date, debit, Math.Abs(amount), field61.StartsWith(':') ? field61 : ":61:" + field61, narrative.Trim());
        return true;
    }

    private static bool TryBalance(string line, out DateTime date, out string currency, out decimal amount)
    {
        date = default;
        currency = "RON";
        amount = 0;
        var body = line.Contains(':') ? line.Split(':', 3).Last() : line;
        if (body.Length < 10)
            return false;
        var mark = body[0];
        if (!TrySwiftDate(body.Substring(1, 6), out date))
            return false;
        if (body.Length < 10)
            return false;
        currency = body.Substring(7, 3);
        if (!TryAmount(body[10..], out amount, out _))
            return false;
        if (mark == 'D')
            amount = -Math.Abs(amount);
        return true;
    }

    private static bool TrySwiftDate(string code, out DateTime date)
    {
        date = default;
        if (code.Length != 6 || !int.TryParse(code, out _))
            return false;
        var year = 2000 + int.Parse(code[..2], CultureInfo.InvariantCulture);
        var month = int.Parse(code.Substring(2, 2), CultureInfo.InvariantCulture);
        var day = int.Parse(code.Substring(4, 2), CultureInfo.InvariantCulture);
        if (month is < 1 or > 12 || day is < 1 or > 31)
            return false;
        date = new DateTime(year, month, day);
        return true;
    }

    private static bool TryDate(string raw, out DateTime date)
    {
        var text = raw.Trim();
        var formats = new[] { "yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yy", "dd/MM/yy", "dd-MM-yy" };
        if (DateTime.TryParseExact(text, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out date))
            return true;
        return DateTime.TryParse(text, CultureInfo.GetCultureInfo("ro-RO"), DateTimeStyles.None, out date);
    }

    private static bool TryAmount(string raw, out decimal signed, out bool markedDebit)
    {
        var text = raw.Trim();
        markedDebit = text.StartsWith('-') || text.StartsWith('(') || text.EndsWith('-');
        text = text.Trim().Trim('(', ')', '+', '-', ' ');
        var lastComma = text.LastIndexOf(',');
        var lastDot = text.LastIndexOf('.');
        if (lastComma >= 0 && lastDot >= 0)
            text = lastComma > lastDot ? text.Replace(".", "").Replace(',', '.') : text.Replace(",", "");
        else if (lastComma >= 0)
            text = text.Replace(" ", "").Replace('.', ' ').Replace(" ", "").Replace(',', '.');
        else
            text = text.Replace(" ", "");
        if (!decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var value))
        {
            signed = 0;
            return false;
        }
        signed = markedDebit ? -Math.Abs(value) : value;
        return true;
    }

    private static string Amount(decimal value)
    {
        var text = Math.Abs(value).ToString("0.00", CultureInfo.InvariantCulture).Replace('.', ',');
        return value < 0 ? "-" + text : text;
    }

    private static string ReplaceDate(string line, string prefix, string code)
    {
        if (!line.StartsWith(prefix, StringComparison.Ordinal))
            return line;
        var body = line[prefix.Length..];
        if (body.Length >= 6 && body[..6].All(char.IsDigit))
            return prefix + code + body[6..];
        return prefix + "STMT" + code;
    }

    private static string HolderFrom(string text)
    {
        foreach (var line in text.Split('\n').Take(12))
        {
            var folded = Fold(line);
            if (folded.Contains("srl") || folded.Contains("s.a") || folded.Contains("pfa"))
                return line.Trim();
        }
        return "";
    }

    private static bool IsHeader(string text)
    {
        var folded = Fold(text);
        return folded is "data" or "date" or "descriere" or "description" or "debit" or "credit" or "suma" or "amount" or "sold" or "balance";
    }

    private static int IndexOf(List<string> headers, params string[] needles)
    {
        for (var i = 0; i < headers.Count; i++)
        {
            if (needles.Any(needle => headers[i].Contains(needle, StringComparison.Ordinal)))
                return i;
        }
        return -1;
    }

    private static string Fold(string value)
    {
        var text = value.Trim().ToLowerInvariant();
        return text.Replace('ă', 'a').Replace('â', 'a').Replace('î', 'i').Replace('ș', 's').Replace('ţ', 't').Replace('ț', 't');
    }

    private static string Sanitize(string value)
    {
        var cleaned = value.Trim();
        foreach (var ch in "/\\?%*|\"<>:")
            cleaned = cleaned.Replace(ch, ' ');
        while (cleaned.Contains("  ", StringComparison.Ordinal))
            cleaned = cleaned.Replace("  ", " ");
        return cleaned.Trim();
    }

    private sealed class Parsed
    {
        public List<Tx> Transactions { get; } = [];
        public List<string> Footer { get; } = [];
        public string Field20 { get; set; } = "";
        public string Field25 { get; set; } = "";
        public string Field28 { get; set; } = "";
        public string Currency { get; set; } = "RON";
        public string Holder { get; set; } = "";
        public decimal Opening { get; set; }
        public bool HasOpening { get; set; }
        public DateTime OpeningDate { get; set; }
    }

    private sealed record Tx(DateTime Date, bool IsDebit, decimal Amount, string Field61, string Narrative);
}
