using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;

namespace ERPMobile.Services.Utilities;

public sealed class PayrollNoteLine
{
    public int Number { get; set; }
    public string Journal { get; set; } = "OD";
    public int Date { get; set; }
    public string DocumentNumber { get; set; } = "";
    public string Account { get; set; } = "";
    public string AccountTitle { get; set; } = "";
    public string Explanation { get; set; } = "";
    public decimal Amount { get; set; }
    public string DebitCredit { get; set; } = "";
    public string EmployeeCode { get; set; } = "";
}

public enum PayrollNoteStyle
{
    Simple,
    Collected
}

public static class PayrollNcEngine
{
    private static readonly string[] Headers =
    [
        "Numar inregistrare", "Jurnal", "Data", "Data Scadenta", "Numar Document", "Cont", "Explicatie",
        "Valoare", "Debit/credit", "Marca", "Cod Buget", "Titlu Cont", "Deviza-Cod deviza",
        "Deviza-valoare debit in deviza", "Deviza-valoare credti in deviza", "Deviza - valoare in deviza",
        "Partener- Cod fiscal", "Partener - Partener", "Denumire buget", "Optiune Tva", "Cod Auxiliar"
    ];

    public static (List<PayrollNoteLine> Lines, string Company) Read(byte[] pdf, int firstNumber, PayrollNoteStyle style)
    {
        List<string> lines;
        try
        {
            lines = PdfText.Lines(pdf);
        }
        catch
        {
            throw new InvalidOperationException("Fișierul nu este un PDF valid.");
        }
        if (lines.Count == 0 || lines.All(line => string.IsNullOrWhiteSpace(line)))
            throw new InvalidOperationException("PDF-ul nu are text selectabil (probabil scan). Folosiți un PDF generat, nu o poză.");

        var cleaned = lines.Select(line => line.Replace('\u00A0', ' ').Trim()).Where(line => line.Length > 0).ToList();
        var date = ExtractDate(cleaned);
        var journal = ExtractJournal(cleaned);
        var company = ExtractCompany(cleaned);
        var entries = LooksLikeSaga(cleaned)
            ? ParseSaga(cleaned, firstNumber, journal, date)
            : new List<PayrollNoteLine>();
        if (entries.Count == 0)
        {
            foreach (var line in cleaned)
            {
                if (IsNoise(line))
                    continue;
                if (ParseRow(line, firstNumber, journal, date) is { } row)
                    entries.Add(row);
            }
        }
        if (entries.Count == 0)
            throw new InvalidOperationException("Nu am găsit linii de notă (cont + D/C + valoare). Verificați PDF-ul.");

        entries = Remap(entries, firstNumber);
        if (style == PayrollNoteStyle.Collected)
            entries = Collect(entries);
        return (entries, company);
    }

    public static void WriteXlsx(string path, IReadOnlyList<PayrollNoteLine> entries)
    {
        var files = new Dictionary<string, string>
        {
            ["[Content_Types].xml"] = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                  <Default Extension="xml" ContentType="application/xml"/>
                  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
                  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
                  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
                </Types>
                """,
            ["_rels/.rels"] = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
                </Relationships>
                """,
            ["xl/workbook.xml"] = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
                </workbook>
                """,
            ["xl/_rels/workbook.xml.rels"] = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
                  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
                </Relationships>
                """,
            ["xl/styles.xml"] = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                  <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
                  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
                  <borders count="1"><border/></borders>
                  <cellStyleXfs count="1"><xf/></cellStyleXfs>
                  <cellXfs count="2"><xf fontId="0" fillId="0" borderId="0"/><xf fontId="1" fillId="0" borderId="0" applyFont="1"/></cellXfs>
                </styleSheet>
                """,
            ["xl/worksheets/sheet1.xml"] = Sheet(entries)
        };
        if (File.Exists(path))
            File.Delete(path);
        using var zip = ZipFile.Open(path, ZipArchiveMode.Create);
        foreach (var (name, xml) in files)
        {
            var entry = zip.CreateEntry(name, CompressionLevel.Optimal);
            using var writer = new StreamWriter(entry.Open(), new UTF8Encoding(false));
            writer.Write(xml.Trim());
        }
    }

    private static string Sheet(IReadOnlyList<PayrollNoteLine> entries)
    {
        var xml = new StringBuilder();
        xml.Append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>""");
        xml.Append(Row(1, Headers.Select(header => (header, false)).ToList(), bold: true));
        for (var i = 0; i < entries.Count; i++)
        {
            var entry = entries[i];
            var cells = new List<(string Text, bool Number)>
            {
                (entry.Number.ToString(CultureInfo.InvariantCulture), true),
                (entry.Journal, false),
                (entry.Date.ToString(CultureInfo.InvariantCulture), true),
                (entry.Date.ToString(CultureInfo.InvariantCulture), true),
                (entry.DocumentNumber, false),
                (entry.Account, false),
                (entry.Explanation, false),
                (entry.Amount.ToString(CultureInfo.InvariantCulture), true),
                (entry.DebitCredit, false),
                (entry.EmployeeCode, false),
                ("", false),
                (entry.AccountTitle, false),
                ("", false), ("", false), ("", false), ("", false), ("", false), ("", false), ("", false), ("", false), ("", false)
            };
            xml.Append(Row(i + 2, cells, bold: false));
        }
        xml.Append("</sheetData></worksheet>");
        return xml.ToString();
    }

    private static string Row(int index, IReadOnlyList<(string Text, bool Number)> cells, bool bold)
    {
        var xml = new StringBuilder();
        xml.Append("<row r=\"").Append(index).Append("\">");
        for (var column = 0; column < cells.Count; column++)
        {
            var (text, number) = cells[column];
            var style = bold ? " s=\"1\"" : "";
            var reference = Cell(column, index);
            if (number && text.Length > 0)
                xml.Append("<c r=\"").Append(reference).Append('"').Append(style).Append("><v>").Append(text).Append("</v></c>");
            else
                xml.Append("<c r=\"").Append(reference).Append("\" t=\"inlineStr\"").Append(style).Append("><is><t>").Append(Escape(text)).Append("</t></is></c>");
        }
        xml.Append("</row>");
        return xml.ToString();
    }

    private static string Cell(int column, int row)
    {
        var name = "";
        var n = column + 1;
        while (n > 0)
        {
            var rem = (n - 1) % 26;
            name = (char)('A' + rem) + name;
            n = (n - 1) / 26;
        }
        return name + row.ToString(CultureInfo.InvariantCulture);
    }

    private static List<PayrollNoteLine> ParseSaga(List<string> lines, int note, string journal, int date)
    {
        var pattern = new Regex(@"(\d+)\s+(.+?)\s+(\d{3,4}|%)(?:\s+(\d{3,4}|%))?\s+(\d{1,3}(?:[ \u00A0]\d{3})*\.\d{2})\s+(\d+)\s+(\S+)", RegexOptions.Singleline);
        var sources = new List<string> { string.Join("\n", lines) };
        sources.AddRange(lines);
        var rows = new List<SagaRow>();
        var seen = new HashSet<string>();
        foreach (var source in sources)
        {
            foreach (Match match in pattern.Matches(source))
            {
                var amountText = match.Groups[5].Value.Replace('\u00A0', ' ');
                if (!TryMoney(amountText, out var amount) || amount <= 0)
                    continue;
                var row = new SagaRow(
                    int.TryParse(match.Groups[1].Value, out var crt) ? crt : 0,
                    match.Groups[2].Value.Trim(),
                    match.Groups[3].Value,
                    match.Groups[4].Success ? match.Groups[4].Value : "",
                    amount,
                    match.Groups[6].Value);
                if (seen.Add(row.Key))
                    rows.Add(row);
            }
        }
        rows.Sort((a, b) => a.Crt.CompareTo(b.Crt));
        var entries = new List<PayrollNoteLine>();
        (string Account, string Side)? compound = null;
        foreach (var row in rows)
        {
            var document = row.Document.Length == 0 ? note.ToString(CultureInfo.InvariantCulture) : row.Document;
            var debit = AccountOf(row.Debit);
            var credit = AccountOf(row.Credit);
            if (debit != null && credit != null)
            {
                entries.Add(Entry(note, journal, date, document, debit, row.Explanation, row.Amount, "D"));
                entries.Add(Entry(note, journal, date, document, credit, row.Explanation, row.Amount, "C"));
                compound = null;
            }
            else if (debit != null && row.Credit == "%")
                compound = (debit, "D");
            else if (row.Debit == "%" && credit != null)
                compound = (credit, "C");
            else if ((debit ?? credit) is { } only)
            {
                if (compound is { } pair)
                {
                    var debitAccount = pair.Side == "D" ? pair.Account : only;
                    var creditAccount = pair.Side == "C" ? pair.Account : only;
                    entries.Add(Entry(note, journal, date, document, debitAccount, row.Explanation, row.Amount, "D"));
                    entries.Add(Entry(note, journal, date, document, creditAccount, row.Explanation, row.Amount, "C"));
                }
                else
                    entries.Add(Entry(note, journal, date, document, only, row.Explanation, row.Amount, "D"));
            }
        }
        return entries;
    }

    private static PayrollNoteLine? ParseRow(string line, int defaultNote, string defaultJournal, int date)
    {
        var tokens = line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (tokens.Length < 3)
            return null;
        var note = defaultNote;
        var journal = defaultJournal;
        var start = 0;
        if (int.TryParse(tokens[0], out var first) && first > 0 && first < 1_000_000 && !IsAccount(tokens[0])
            && tokens.Length > 1 && (IsJournal(tokens[1]) || IsAccount(tokens[1])))
        {
            note = first;
            start = 1;
        }
        if (start < tokens.Length && IsJournal(tokens[start]))
        {
            journal = tokens[start].ToUpperInvariant();
            start++;
        }
        if (start >= tokens.Length || !IsAccount(tokens[start]))
            return null;
        var account = tokens[start];
        start++;
        string? side = null;
        var marca = "";
        if (start < tokens.Length && SideOf(tokens[start]) is { } side1)
        {
            side = side1;
            start++;
        }
        if (start < tokens.Length && IsMarca(tokens[start]))
        {
            marca = tokens[start];
            start++;
        }
        if (side == null && start < tokens.Length && SideOf(tokens[start]) is { } side2)
        {
            side = side2;
            start++;
        }
        var amountIndex = -1;
        for (var i = tokens.Length - 1; i >= start; i--)
        {
            var raw = StripCurrency(tokens[i]);
            if (TryMoney(raw, out var _) && raw.Any(char.IsDigit) && (raw.Contains(',') || raw.Contains('.') || raw.Length >= 2))
            {
                amountIndex = i;
                break;
            }
        }
        if (amountIndex < start || !TryMoney(StripCurrency(tokens[amountIndex]), out var amount) || amount <= 0)
            return null;
        var explanation = tokens.Skip(start).Take(amountIndex - start).ToList();
        if (side == null && explanation.Count > 0 && SideOf(explanation[^1]) is { } side3)
        {
            side = side3;
            explanation.RemoveAt(explanation.Count - 1);
        }
        if (side == null)
            return null;
        var entry = Entry(note, journal, date, note.ToString(CultureInfo.InvariantCulture), account, string.Join(" ", explanation), amount, side);
        entry.EmployeeCode = marca;
        return entry;
    }

    private static List<PayrollNoteLine> Remap(List<PayrollNoteLine> entries, int firstNumber)
    {
        if (firstNumber < 1)
            return entries;
        var map = new Dictionary<int, int>();
        var next = firstNumber;
        foreach (var entry in entries)
        {
            if (!map.ContainsKey(entry.Number))
                map[entry.Number] = next++;
            var mapped = map[entry.Number];
            if (entry.DocumentNumber == entry.Number.ToString(CultureInfo.InvariantCulture))
                entry.DocumentNumber = mapped.ToString(CultureInfo.InvariantCulture);
            entry.Number = mapped;
        }
        return entries;
    }

    private static List<PayrollNoteLine> Collect(List<PayrollNoteLine> entries)
    {
        var collected = new HashSet<string> { "444", "4315", "4316", "436" };
        var result = new List<PayrollNoteLine>();
        foreach (var entry in entries)
        {
            result.Add(entry);
            var digits = new string(entry.Account.Trim().TakeWhile(char.IsDigit).ToArray());
            if (entry.DebitCredit != "C" || !collected.Contains(digits))
                continue;
            result.Add(Clone(entry, entry.Account, entry.AccountTitle, "D"));
            result.Add(Clone(entry, "4311", "Contribuții sociale (cont unic)", "C"));
        }
        return result;
    }

    private static PayrollNoteLine Entry(int note, string journal, int date, string document, string account, string explanation, decimal amount, string side) =>
        new()
        {
            Number = note,
            Journal = journal,
            Date = date,
            DocumentNumber = document,
            Account = account,
            AccountTitle = explanation,
            Explanation = explanation,
            Amount = amount,
            DebitCredit = side
        };

    private static PayrollNoteLine Clone(PayrollNoteLine entry, string account, string title, string side) =>
        new()
        {
            Number = entry.Number,
            Journal = entry.Journal,
            Date = entry.Date,
            DocumentNumber = entry.DocumentNumber,
            Account = account,
            AccountTitle = title,
            Explanation = entry.Explanation,
            Amount = entry.Amount,
            DebitCredit = side,
            EmployeeCode = entry.EmployeeCode
        };

    private static string? AccountOf(string token)
    {
        var value = token.Trim();
        return value == "%" || value.Length == 0 || !IsAccount(value) ? null : value;
    }

    private static bool LooksLikeSaga(List<string> lines) =>
        lines.Any(line =>
        {
            var folded = Fold(line);
            return (folded.Contains("cont debitor") && folded.Contains("cont creditor")) || folded.Contains("sagaweb");
        });

    private static bool IsNoise(string line)
    {
        var folded = Fold(line);
        return folded.Contains("numar inregistrare")
            || (folded.Contains("debit/credit") && folded.Contains("cont"))
            || (folded.StartsWith("nr.", StringComparison.Ordinal) && folded.Contains("jurnal"))
            || folded.Contains("nota contabila")
            || folded.Contains("stat de plata")
            || folded.Contains("cui:")
            || (folded.Contains("cont debitor") && folded.Contains("cont creditor"))
            || folded.StartsWith("total:", StringComparison.Ordinal)
            || folded.StartsWith("intocmit", StringComparison.Ordinal)
            || folded.Contains("sagaweb");
    }

    private static bool IsAccount(string token)
    {
        var value = token.Trim().Trim('.', ',', ';');
        if (!Regex.IsMatch(value, @"^\d{3,4}(?:\.\d{1,4})?$"))
            return false;
        if (int.TryParse(value, out var year) && year is >= 2000 and <= 2100)
            return false;
        var digits = value.Split('.')[0];
        return digits.Length is >= 3 and <= 4 && digits[0] is >= '1' and <= '8';
    }

    private static bool IsJournal(string token) =>
        token.ToUpperInvariant() is "OD" or "NC" or "JV" or "RC" or "RF" or "LN";

    private static string? SideOf(string token)
    {
        var value = token.Trim().Trim('.', ',', ';', ':').ToUpperInvariant();
        if (value is "D" or "DEBIT")
            return "D";
        if (value is "C" or "CREDIT")
            return "C";
        return null;
    }

    private static bool IsMarca(string token)
    {
        if (SideOf(token) != null || IsJournal(token))
            return false;
        if (TryMoney(StripCurrency(token), out _) && (token.Contains(',') || token.Contains('.')))
            return false;
        return token.Length is >= 2 and <= 12 && token.All(char.IsLetterOrDigit);
    }

    private static string StripCurrency(string token)
    {
        var value = token.Trim();
        foreach (var suffix in new[] { "lei", "RON", "ron" })
        {
            if (value.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                value = value[..^suffix.Length];
        }
        return value.Trim().Trim(';');
    }

    private static bool TryMoney(string raw, out decimal amount)
    {
        var text = raw.Replace('\u00A0', ' ').Replace(" ", "");
        if (text.Contains(',') && text.Contains('.'))
            text = text.LastIndexOf(',') > text.LastIndexOf('.') ? text.Replace(".", "").Replace(',', '.') : text.Replace(",", "");
        else if (text.Contains(','))
            text = text.Replace(',', '.');
        return decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out amount);
    }

    private static int ExtractDate(List<string> lines)
    {
        var joined = string.Join(" ", lines);
        var match = Regex.Match(joined, @"\b(\d{2})[./-](\d{2})[./-](\d{4})\b");
        if (match.Success
            && int.TryParse(match.Groups[1].Value, out var day)
            && int.TryParse(match.Groups[2].Value, out var month)
            && int.TryParse(match.Groups[3].Value, out var year)
            && day is >= 1 and <= 31 && month is >= 1 and <= 12 && year >= 2000)
            return year * 10_000 + month * 100 + day;
        var today = DateTime.Today;
        return today.Year * 10_000 + today.Month * 100 + today.Day;
    }

    private static string ExtractJournal(List<string> lines)
    {
        foreach (var line in lines)
        {
            var folded = line.ToUpperInvariant();
            if (!folded.Contains("JURNAL", StringComparison.Ordinal))
                continue;
            foreach (var token in new[] { "OD", "NC", "JV" })
            {
                if (folded.Contains(token, StringComparison.Ordinal))
                    return token;
            }
        }
        return "OD";
    }

    private static string ExtractCompany(List<string> lines)
    {
        foreach (var line in lines.Take(8))
        {
            var folded = Fold(line);
            if (!folded.Contains("s.r.l") && !folded.Contains("srl") && !folded.Contains("s.a."))
                continue;
            var name = line;
            foreach (var marker in new[] { "c.f.", "c.f ", "CUI:", "CUI ", "r.c.", "R.C." })
            {
                var index = name.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
                if (index > 0)
                {
                    name = name[..index];
                    break;
                }
            }
            name = name.Trim();
            return name.Length == 0 ? line.Trim() : name;
        }
        return "";
    }

    private static string Fold(string value)
    {
        var text = value.ToLowerInvariant();
        return text.Replace('ă', 'a').Replace('â', 'a').Replace('î', 'i').Replace('ș', 's').Replace('ţ', 't').Replace('ț', 't');
    }

    private static string Escape(string text) =>
        text.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("\"", "&quot;");

    private sealed record SagaRow(int Crt, string Explanation, string Debit, string Credit, decimal Amount, string Document)
    {
        public string Key => Crt + "|" + Debit + "|" + Credit + "|" + Amount.ToString(CultureInfo.InvariantCulture) + "|" + Document;
    }
}
