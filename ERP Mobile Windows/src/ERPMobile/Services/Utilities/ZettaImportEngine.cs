using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using ERPMobile.Services;

namespace ERPMobile.Services.Utilities;

public sealed class ZReportDraft
{
    public string Source { get; set; } = "";
    public string Firma { get; set; } = "";
    public string Cui { get; set; } = "";
    public string Locatie { get; set; } = "";
    public int ZNumber { get; set; }
    public DateTime Date { get; set; } = DateTime.Today;
    public decimal Total { get; set; }
    public decimal Vanzari21 { get; set; }
    public decimal Tva21 { get; set; }
    public decimal Vanzari11 { get; set; }
    public decimal Tva11 { get; set; }
    public decimal Vanzari11C { get; set; }
    public decimal Tva11C { get; set; }
    public decimal Vanzari0 { get; set; }
    public decimal Numerar { get; set; }
    public decimal Card { get; set; }
    public decimal PlataModerna { get; set; }
    public string Note { get; set; } = "";
}

public sealed class ZettaLedger
{
    public bool HasSettings { get; set; }
    public bool MultiLocation { get; set; }
    public string Headquarters { get; set; } = "5311.0";
    public string CardAccount { get; set; } = "5125";
    public string ModernAccount { get; set; } = "5113";
    public string CompanyName { get; set; } = "";
    public string CompanyCui { get; set; } = "";
    public List<ZettaLocationAccount> Locations { get; } = [];
    public Dictionary<string, ZettaVatSlot> Slots { get; } = new(StringComparer.OrdinalIgnoreCase);
}

public sealed class ZettaLocationAccount
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Account { get; set; } = "5311";
}

public sealed class ZettaVatSlot
{
    public bool Enabled { get; set; }
    public int Rate { get; set; }
    public string Account { get; set; } = "";
    public bool Bacsis { get; set; }
    public bool Sgr { get; set; }
}

public sealed class ZettaNcRow
{
    public int Number { get; set; }
    public string Journal { get; set; } = "";
    public int Date { get; set; }
    public string Document { get; set; } = "";
    public string Debit { get; set; } = "";
    public string DebitTitle { get; set; } = "";
    public string Credit { get; set; } = "";
    public string CreditTitle { get; set; } = "";
    public string Explanation { get; set; } = "";
    public decimal Amount { get; set; }
    public string PartnerCode { get; set; } = "";
    public string PartnerName { get; set; } = "";
    public string FirmCui { get; set; } = "";
    public string VatOption { get; set; } = "";
    public decimal? VatRate { get; set; }
    public string Saft { get; set; } = "";
}

public static class ZettaImportEngine
{
    private static readonly CultureInfo Ro = CultureInfo.GetCultureInfo("ro-RO");

    public static async Task<ZettaLedger> LoadLedger(AppSession session)
    {
        var ledger = new ZettaLedger();
        var company = session.CurrentCompany;
        if (company == null)
            return ledger;
        ledger.CompanyName = company.Denumire;
        ledger.CompanyCui = Digits(company.Cui);

        var locations = await session.SelectRows("company_work_locations", "company_id=eq." + company.Id + "&select=id,denumire&order=denumire.asc");
        var settingsRows = await session.SelectRows("company_zetta_settings", "company_id=eq." + company.Id + "&select=settings");
        JsonElement settings = default;
        ledger.HasSettings = settingsRows.ValueKind == JsonValueKind.Array && settingsRows.GetArrayLength() > 0
            && settingsRows[0].TryGetProperty("settings", out settings)
            && settings.ValueKind == JsonValueKind.Object;

        var accounts = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (ledger.HasSettings && settings.TryGetProperty("locationCasaAccounts", out var stored) && stored.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in stored.EnumerateArray())
            {
                var id = Text(item, "workLocationId");
                var account = Text(item, "account");
                if (id.Length > 0 && account.Length > 0)
                    accounts[id] = account;
            }
        }

        if (locations.ValueKind == JsonValueKind.Array)
        {
            var index = 0;
            foreach (var row in locations.EnumerateArray())
            {
                var id = row.TryGetProperty("id", out var idValue) ? idValue.GetString() ?? "" : "";
                var name = Text(row, "denumire");
                if (name.Length == 0)
                    name = "Punct de lucru";
                var account = accounts.TryGetValue(id, out var saved)
                    ? saved
                    : locations.GetArrayLength() == 1 ? "5311" : "5311." + (index + 1);
                ledger.Locations.Add(new ZettaLocationAccount { Id = id, Name = name, Account = account });
                index++;
            }
        }

        if (!ledger.HasSettings)
            return ledger;

        ledger.MultiLocation = settings.TryGetProperty("usesRegistersOnMultipleWorkLocations", out var multi) && multi.ValueKind == JsonValueKind.True;
        ledger.Headquarters = Text(settings, "headquartersCasaAccount");
        if (ledger.Headquarters.Length == 0)
            ledger.Headquarters = "5311.0";
        ledger.CardAccount = Text(settings, "cardPaymentAccount");
        if (ledger.CardAccount.Length == 0)
            ledger.CardAccount = "5125";
        ledger.ModernAccount = Text(settings, "modernPaymentAccount");
        if (ledger.ModernAccount.Length == 0)
            ledger.ModernAccount = "5113";

        if (settings.TryGetProperty("vatCategories", out var categories) && categories.ValueKind == JsonValueKind.Object)
        {
            foreach (var slot in new[] { "A", "B", "C", "D" })
            {
                if (!categories.TryGetProperty(slot, out var vat) || vat.ValueKind != JsonValueKind.Object)
                    continue;
                var parsed = new ZettaVatSlot
                {
                    Enabled = vat.TryGetProperty("isEnabled", out var enabled) && enabled.ValueKind == JsonValueKind.True,
                    Rate = vat.TryGetProperty("rate", out var rate) && rate.TryGetInt32(out var rateValue) ? rateValue : 0
                };
                if (vat.TryGetProperty("salesMappings", out var mappings) && mappings.ValueKind == JsonValueKind.Array)
                {
                    foreach (var mapping in mappings.EnumerateArray())
                    {
                        if (!(mapping.TryGetProperty("isEnabled", out var on) && on.ValueKind == JsonValueKind.True))
                            continue;
                        var category = Text(mapping, "category");
                        parsed.Account = Text(mapping, "account");
                        parsed.Bacsis = category == "bacsis";
                        parsed.Sgr = category == "sgr";
                        break;
                    }
                }
                ledger.Slots[slot] = parsed;
            }
        }
        return ledger;
    }

    public static List<ZReportDraft> Read(string name, byte[] data, out string warning)
    {
        warning = "";
        var ext = Path.GetExtension(name).ToLowerInvariant();
        var chunks = new List<(string Label, List<string> Lines)>();
        if (ext == ".pdf")
        {
            List<List<string>> pages;
            try
            {
                pages = PdfText.Pages(data);
            }
            catch (Exception ex)
            {
                warning = name + ": PDF-ul nu a putut fi citit (" + ex.Message + ").";
                return [];
            }
            for (var i = 0; i < pages.Count; i++)
            {
                if (pages[i].Count == 0)
                {
                    warning = Join(warning, name + " pagina " + (i + 1) + " nu are text. Exportați PDF-ul din casă sau completați Z-ul manual.");
                    chunks.Add((name + " p." + (i + 1), []));
                    continue;
                }
                chunks.Add((name + " p." + (i + 1), pages[i]));
            }
        }
        else if (ext is ".png" or ".jpg" or ".jpeg" or ".tif" or ".tiff" or ".bmp" or ".webp")
        {
            string? text;
            try
            {
                text = ZettaOcr.Read(data, ext);
            }
            catch (Exception ex)
            {
                warning = name + ": poza nu a putut fi citită (" + ex.Message + "). Completați Z-ul manual.";
                text = null;
            }
            if (string.IsNullOrWhiteSpace(text))
                warning = Join(warning, name + ": nu am recunoscut text pe poză. Completați sumele în tabel.");
            chunks.Add((name, SplitLines(text ?? "")));
        }
        else
        {
            var text = Encoding.UTF8.GetString(data);
            chunks.Add((name, SplitLines(text)));
        }

        var reports = new List<ZReportDraft>();
        foreach (var (label, lines) in chunks)
        {
            var parts = SplitReports(lines);
            if (parts.Count == 0)
                parts.Add(lines);
            var index = 0;
            foreach (var part in parts)
            {
                index++;
                var source = parts.Count == 1 ? label : label + " / " + index;
                reports.Add(Parse(source, part));
            }
        }
        return reports;
    }

    public static List<(string FileName, List<ZettaNcRow> Rows)> Build(IReadOnlyList<ZReportDraft> reports, int firstNumber, ZettaLedger ledger)
    {
        var start = Math.Max(1, firstNumber);
        var groups = new List<(string Key, string Firm, List<ZReportDraft> Reports)>();
        foreach (var report in reports.OrderBy(item => item.Date).ThenBy(item => item.ZNumber))
        {
            var firm = string.IsNullOrWhiteSpace(report.Firma) ? ledger.CompanyName : report.Firma.Trim();
            if (firm.Length == 0)
                firm = "Firma";
            var key = Compact(firm);
            var existing = groups.FirstOrDefault(group => group.Key == key);
            if (existing.Reports == null)
                groups.Add((key, firm, [report]));
            else
                existing.Reports.Add(report);
        }

        var files = new List<(string FileName, List<ZettaNcRow> Rows)>();
        foreach (var group in groups)
        {
            var rows = new List<ZettaNcRow>();
            for (var i = 0; i < group.Reports.Count; i++)
                rows.AddRange(RowsFor(group.Reports[i], start + i, ledger));
            if (rows.Count == 0)
                continue;
            files.Add((FileName(group.Firm, group.Reports), rows));
        }
        return files;
    }

    public static void WriteXlsx(string path, IReadOnlyList<ZettaNcRow> rows)
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
                  <sheets><sheet name="NC" sheetId="1" r:id="rId1"/></sheets>
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
            ["xl/worksheets/sheet1.xml"] = Sheet(rows)
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

    public static string MoneyText(decimal value) => value.ToString("0.00", Ro);

    public static decimal ParseMoney(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return 0;
        var value = text.Trim().Replace(" ", "").Replace("RON", "", StringComparison.OrdinalIgnoreCase);
        if (value.Contains(',') && value.Contains('.'))
            value = value.Replace(".", "").Replace(',', '.');
        else if (value.Contains(','))
            value = value.Replace(',', '.');
        return decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed)
            ? Math.Round(parsed, 2, MidpointRounding.AwayFromZero)
            : 0;
    }

    public static string SafeFile(string name)
    {
        var cleaned = Regex.Replace(name, @"[\\/?:*|""<>\.\n\t]", "");
        cleaned = cleaned.Trim().Replace(' ', '_');
        while (cleaned.Contains("__"))
            cleaned = cleaned.Replace("__", "_");
        cleaned = cleaned.Trim('_', '+');
        if (cleaned.Length == 0)
            cleaned = "Firma";
        return cleaned.Length > 80 ? cleaned[..80] : cleaned;
    }

    private static List<ZettaNcRow> RowsFor(ZReportDraft report, int number, ZettaLedger ledger)
    {
        var cui = Digits(report.Cui);
        if (cui.Length == 0)
            cui = ledger.CompanyCui;
        var date = int.Parse(report.Date.ToString("yyyyMMdd"), CultureInfo.InvariantCulture);
        var document = report.ZNumber.ToString("D4", CultureInfo.InvariantCulture);
        var rows = new List<ZettaNcRow>();
        if (ledger.HasSettings)
            AddFromSettings(rows, report, number, date, document, cui, ledger);
        else
            AddGeneric(rows, report, number, date, document, cui);
        return rows.Where(row => row.Amount != 0).ToList();
    }

    private static void AddGeneric(List<ZettaNcRow> rows, ZReportDraft z, int number, int date, string document, string cui)
    {
        Tax(rows, z, number, date, document, cui, "JV", z.Tva11, 11, "310351", "4427", "TVA colectata");
        Tax(rows, z, number, date, document, cui, "JV", Net(z.Vanzari11, z.Tva11), 11, "310351", "701", "Venituri din vanzarea produselor finite");
        Tax(rows, z, number, date, document, cui, "JV", z.Tva21, 21, "310344", "4427", "TVA colectata");
        Tax(rows, z, number, date, document, cui, "JV", Net(z.Vanzari21, z.Tva21), 21, "310344", "707", "Venituri din vanzarea marfurilor");
        Tax(rows, z, number, date, document, cui, "JV", z.Tva11C, 11, "310351", "4427", "TVA colectata");
        Tax(rows, z, number, date, document, cui, "JV", Net(z.Vanzari11C, z.Tva11C), 11, "310351", "701", "Venituri din vanzarea produselor finite");
        Tax(rows, z, number, date, document, cui, "JV", z.Vanzari0, 0, "310324", "267.1", "GARANTIE depusa", "Neimpozabile");
        Payment(rows, z, number, date, document, cui, "RC", "5311", "Casa in lei", z.Numerar, true);
        var cardOnly = z.Numerar == 0 && z.Card > 0;
        Payment(rows, z, number, date, document, cui, cardOnly ? "RC" : "OD", "5125", "Sume in curs de decontare", z.Card, !cardOnly);
        Payment(rows, z, number, date, document, cui, "OD", "5113", "Efecte de incasat", z.PlataModerna, true);
    }

    private static void AddFromSettings(List<ZettaNcRow> rows, ZReportDraft z, int number, int date, string document, string cui, ZettaLedger ledger)
    {
        foreach (var slot in new[] { "A", "B", "C", "D" })
        {
            if (!ledger.Slots.TryGetValue(slot, out var settings) || !settings.Enabled)
                continue;
            var (tva, net, gross) = SlotAmounts(slot, z);
            if (settings.Rate != 0)
            {
                if (tva > 0)
                    Tax(rows, z, number, date, document, cui, "JV", tva, settings.Rate, Saft(settings.Rate), "4427", "TVA colectata");
                if (net > 0)
                    Tax(rows, z, number, date, document, cui, "JV", net, settings.Rate, Saft(settings.Rate), settings.Account, Title(settings.Account));
            }
            else if (gross > 0)
            {
                var account = settings.Account.Length == 0 ? "267.1" : settings.Account;
                Tax(rows, z, number, date, document, cui, "JV", gross, 0, "310324", account, Title(account), "Neimpozabile");
                if (settings.Bacsis)
                    Payment(rows, z, number, date, document, cui, "OD", account, Title(account), gross, false, credit: "446.2", creditTitle: "BACSIS");
            }
        }

        if (z.Numerar > 0)
        {
            var casa = CashAccount(z, ledger);
            Payment(rows, z, number, date, document, cui, "RC", casa, Title(casa), z.Numerar, true);
            if (ledger.MultiLocation)
            {
                Payment(rows, z, number, date, document, cui, "RC", "581", "Viramente interne", z.Numerar, false, credit: casa, creditTitle: Title(casa));
                Payment(rows, z, number, date, document, cui, "RC", ledger.Headquarters, Title(ledger.Headquarters), z.Numerar, false, credit: "581", creditTitle: "Viramente interne");
            }
        }
        if (z.Card > 0)
            Payment(rows, z, number, date, document, cui, "RC", ledger.CardAccount, Title(ledger.CardAccount), z.Card, true);
        if (z.PlataModerna > 0)
            Payment(rows, z, number, date, document, cui, "RC", ledger.ModernAccount, Title(ledger.ModernAccount), z.PlataModerna, true);
    }

    private static (decimal Tva, decimal Net, decimal Gross) SlotAmounts(string slot, ZReportDraft z) => slot switch
    {
        "A" => (z.Tva21, Net(z.Vanzari21, z.Tva21), z.Vanzari21),
        "B" => (z.Tva11, Net(z.Vanzari11, z.Tva11), z.Vanzari11),
        "C" => (z.Tva11C, Net(z.Vanzari11C, z.Tva11C), z.Vanzari11C),
        _ => (0, z.Vanzari0, z.Vanzari0)
    };

    private static string CashAccount(ZReportDraft z, ZettaLedger ledger)
    {
        if (ledger.Locations.Count == 0)
            return "5311";
        var label = Compact(z.Locatie);
        if (label.Length > 0)
        {
            var match = ledger.Locations.FirstOrDefault(location =>
            {
                var name = Compact(location.Name);
                return name == label || name.Contains(label) || label.Contains(name);
            });
            if (match != null && match.Account.Length > 0)
                return match.Account;
        }
        return ledger.Locations[0].Account.Length == 0 ? "5311" : ledger.Locations[0].Account;
    }

    private static void Tax(List<ZettaNcRow> rows, ZReportDraft z, int number, int date, string document, string cui, string journal, decimal amount, int rate, string saft, string credit, string creditTitle, string option = "Taxabile")
    {
        if (amount == 0)
            return;
        rows.Add(Line(z, number, date, document, cui, journal, "4111", "Clienti", credit, creditTitle, amount, true, option, rate, saft));
    }

    private static void Payment(List<ZettaNcRow> rows, ZReportDraft z, int number, int date, string document, string cui, string journal, string debit, string debitTitle, decimal amount, bool partner, string credit = "4111", string creditTitle = "Clienti")
    {
        if (amount == 0)
            return;
        rows.Add(Line(z, number, date, document, cui, journal, debit, debitTitle, credit, creditTitle, amount, partner, "", null, ""));
    }

    private static ZettaNcRow Line(ZReportDraft z, int number, int date, string document, string cui, string journal, string debit, string debitTitle, string credit, string creditTitle, decimal amount, bool partner, string option, int? rate, string saft) =>
        new()
        {
            Number = number,
            Journal = journal,
            Date = date,
            Document = document,
            Debit = debit,
            DebitTitle = debitTitle,
            Credit = credit,
            CreditTitle = creditTitle,
            Amount = amount,
            PartnerCode = partner ? "0000041" : "",
            PartnerName = partner ? "Clienti" : "",
            FirmCui = cui,
            VatOption = option,
            VatRate = string.IsNullOrEmpty(option) ? null : rate,
            Saft = saft
        };

    private static ZReportDraft Parse(string source, List<string> lines)
    {
        var folded = lines.Select(Fold).ToList();
        var blob = string.Join("\n", folded);
        var report = new ZReportDraft { Source = source, Date = DateTime.Today };
        report.ZNumber = ZNumber(blob);
        report.Cui = Cui(blob);
        report.Firma = Company(lines);
        report.Locatie = Location(folded);
        report.Date = BusinessDate(blob, report.Firma);

        report.Total = Label(lines, folded, ["VAL. TOTAL VANZARI", "TOTAL VANZARI", "TOTAL SALES"], ["CLIENTI", "COD FISCAL"]) ?? 0;
        report.Vanzari21 = Label(lines, folded, ["VAL. TOTAL VANZ - A", "TOTAL VANZ - A", "VANZ - A", "VANZ-A", "BRUT A", "BRUTA "]) ?? 0;
        report.Vanzari11 = Label(lines, folded, ["VAL. TOTAL VANZ - B", "TOTAL VANZ - B", "VANZ - B", "VANZ-B", "BRUT B", "BRUTB "]) ?? 0;
        report.Vanzari11C = Label(lines, folded, ["VAL. TOTAL VANZ - C", "TOTAL VANZ - C", "VANZ - C", "VANZ-C", "BRUT C", "BRUTC "]) ?? 0;
        report.Vanzari0 = Label(lines, folded, ["VAL. TOTAL SCUTIT", "TOTAL SCUTIT", "SCUTIT DE TVA", "SCUTIT DE TUR", "VANZ - S", "VANZ-S"]) ?? 0;
        if (report.Vanzari0 == 0 && !folded.Any(line => line.Contains("SCUTIT")))
            report.Vanzari0 = Label(lines, folded, ["VAL. TOTAL VANZ - D", "TOTAL VANZ - D", "VANZ - D", "BRUT D"]) ?? 0;

        var tva21 = Label(lines, folded, ["TOTAL TVA A", "TVA A - 21", "TVA A 21", "TVA A", "TVA - A", "VAT 21%"], ["BRUT", "TOTAL VANZ"]);
        var tva11 = Label(lines, folded, ["TOTAL TVA B", "TVA B - 11", "TVA B 11", "TVA B", "TVA - B", "VAT 11%"], ["BRUT", "TOTAL VANZ"]);
        var tvaC = Label(lines, folded, ["TOTAL TVA C", "TVA C - 11", "TVA C 11", "TVA C", "TVA - C"], ["BRUT", "TOTAL VANZ"]);
        report.Tva21 = tva21 ?? InferVat(report.Vanzari21, 21);
        report.Tva11 = tva11 ?? InferVat(report.Vanzari11, 11);
        report.Tva11C = tvaC ?? InferVat(report.Vanzari11C, 11);
        if (tva21 == null && report.Vanzari21 > 0)
            report.Note = Join(report.Note, "TVA 21% calculat din brut.");
        if (tva11 == null && report.Vanzari11 > 0)
            report.Note = Join(report.Note, "TVA 11% calculat din brut.");

        if (!ReadPaymentSection(lines, folded, report))
        {
            report.Numerar = PaymentAmount(lines, folded, ["NUMERAR", "CASH"]);
            report.Card = PaymentAmount(lines, folded, ["CARD"]);
            report.PlataModerna = PaymentAmount(lines, folded, ["PLATA MODERNA", "PLATA MODERN"]);
            var other = PaymentAmount(lines, folded, ["ALTE PLATI", "VOUCHER", "TICHET"]);
            if (other > 0)
                report.PlataModerna += other;
        }

        if (report.Total == 0)
            report.Total = report.Vanzari21 + report.Vanzari11 + report.Vanzari11C + report.Vanzari0;
        if (report.ZNumber == 0 && report.Total == 0)
            report.Note = Join(report.Note, "Nu am găsit numărul Z sau totalul. Completați rândul.");
        var paid = report.Numerar + report.Card + report.PlataModerna;
        if (report.Total > 0 && Math.Abs(paid - report.Total) > 0.05m)
            report.Note = Join(report.Note, "Încasările (" + MoneyText(paid) + ") nu bat cu totalul. Verificați numerar, card și plata modernă.");
        return report;
    }

    private static int ZNumber(string upper)
    {
        var text = upper.Replace("N2:", "NR:", StringComparison.Ordinal).Replace("Z N2", "Z NR", StringComparison.Ordinal);
        (int Score, int Value) best = (0, 0);
        void Add(string pattern, int score, string window)
        {
            foreach (Match match in Regex.Matches(window, pattern, RegexOptions.IgnoreCase))
            {
                if (!int.TryParse(match.Groups[1].Value, out var value) || value <= 0 || value > 9999)
                    continue;
                if (score > best.Score || (score == best.Score && (best.Value == 0 || value < best.Value)))
                    best = (score, value);
            }
        }

        var marker = IndexOfAny(text, ["RAPORT FISCAL ZILNIC", "FISCAL ZILNIC", "FISCAL ZINC"]);
        if (marker >= 0)
        {
            var window = text.Substring(marker, Math.Min(500, text.Length - marker));
            Add(@"Z\s*NR\s*[:\.]?\s*0*(\d{1,4})(?!\d)", 100, window);
            Add(@"NR\s*[:\.]?\s*0*(\d{3,4})(?!\d)", 92, window);
        }
        Add(@"PENTRU\s+Z\s*[:\.]?\s*0*(\d{1,4})(?!\d)", 95, text);
        Add(@"Z\s*REPORT\s*(?:NO\.?|NUMAR|NUMBER)\s*0*(\d{1,4})", 106, text);
        Add(@"Z\s*NR\s*[:\.]?\s*0*(\d{1,4})(?!\d)", 80, text);
        return best.Value;
    }

    private static string Cui(string upper)
    {
        var match = Regex.Match(upper, @"(?:CUI|CIF|COD\s+FISCAL|COD\s+UNIC)\s*[:\.]?\s*(?:RO\s*)?(\d{6,10})");
        if (match.Success)
            return match.Groups[1].Value;
        match = Regex.Match(upper, @"\bRO\s*(\d{6,10})\b");
        return match.Success ? match.Groups[1].Value : "";
    }

    private static string Company(List<string> lines)
    {
        foreach (var line in lines.Take(15))
        {
            var folded = Fold(line);
            if (folded.Contains("LOCATIA") || folded.Contains("LOCALIA") || folded.Contains("RAPORT") || folded.Contains("FISCAL"))
                continue;
            if (folded.Contains("SRL") || folded.Contains("S.R.L") || folded.Contains("PFA") || folded.Contains("S.A"))
                return line.Trim();
        }
        return "";
    }

    private static string Location(List<string> folded)
    {
        foreach (var line in folded)
        {
            var match = Regex.Match(line, @"(?:LOCATIA|LOCALIA|LOCATION)\s+(.+)$");
            if (match.Success)
                return match.Groups[1].Value.Trim();
        }
        return "";
    }

    private static DateTime BusinessDate(string upper, string firma)
    {
        var match = Regex.Match(upper, @"PANA LA\s+(\d{2})[./-](\d{2})[./-](\d{4})(?:\s+(\d{2}):(\d{2}))?");
        if (!match.Success)
            match = Regex.Match(upper, @"DATA\s*[:\.]?\s*(\d{2})[./-](\d{2})[./-](\d{4})(?:\s+(\d{2}):(\d{2}))?");
        if (!match.Success)
            match = Regex.Match(upper, @"(\d{2})[./-](\d{2})[./-](\d{4})(?:\s+(\d{2}):(\d{2}))?");
        if (!match.Success || !int.TryParse(match.Groups[1].Value, out var day) || !int.TryParse(match.Groups[2].Value, out var month) || !int.TryParse(match.Groups[3].Value, out var year))
            return DateTime.Today;
        try
        {
            var date = new DateTime(year, month, day);
            if (Fold(firma).Contains("NECTARIE") && match.Groups[4].Success && int.TryParse(match.Groups[4].Value, out var hour) && hour is >= 3 and < 10)
                date = date.AddDays(-1);
            return date;
        }
        catch
        {
            return DateTime.Today;
        }
    }

    private static decimal? Label(List<string> lines, List<string> folded, string[] labels, string[]? skip = null)
    {
        for (var i = 0; i < folded.Count; i++)
        {
            var line = folded[i];
            if (skip != null && skip.Any(line.Contains))
                continue;
            if (!labels.Any(line.Contains))
                continue;
            var onLine = Amounts(lines[i]);
            if (onLine.Count > 0)
                return onLine[^1];
            for (var j = i + 1; j < Math.Min(i + 6, lines.Count); j++)
            {
                var next = folded[j];
                if ((next.StartsWith("TOTAL ", StringComparison.Ordinal) || next == "TOTAL") && !next.Contains("TVA") && !next.Contains("VANZ"))
                    break;
                var values = Amounts(lines[j]);
                if (values.Count == 1)
                    return values[0];
            }
        }
        return null;
    }

    private static bool ReadPaymentSection(List<string> lines, List<string> folded, ZReportDraft report)
    {
        var start = -1;
        for (var i = 0; i < folded.Count; i++)
        {
            if (folded[i].Contains("METODE DE PLATA") || folded[i].Contains("METODE DE PLAT") || folded[i].Contains("PAYMENT TYPES"))
            {
                start = i;
                break;
            }
        }
        if (start < 0)
            return false;

        for (var i = start + 1; i < folded.Count; i++)
        {
            var line = folded[i];
            if (line.Contains("BRUT") || line.Contains("TOTAL VANZARI") || line == "TVA" || (line.StartsWith("TVA ", StringComparison.Ordinal) && !line.Contains("PLATA")))
                break;
            if ((line.StartsWith("TOTAL ", StringComparison.Ordinal) || line == "TOTAL") && !line.Contains("TVA") && !line.Contains("VANZARI"))
                break;

            var values = Amounts(lines[i]);
            decimal? amount = values.Count > 0 ? values[^1] : null;
            if (amount == null && i + 1 < lines.Count && Amounts(lines[i + 1]).Count == 1)
                amount = Amounts(lines[i + 1])[0];

            if (line.Contains("NUMERAR") || line == "CASH" || line.StartsWith("CASH ", StringComparison.Ordinal))
                report.Numerar = amount ?? 0;
            else if (line.Contains("CREDIT") && line.Contains("CARD") && !line.Contains("MASA") && !line.Contains("TICHET"))
                report.Card = amount ?? 0;
            else if (line.Contains("CARD") && (line.Contains("MASA") || line.Contains("TICHET")))
                report.PlataModerna += amount ?? 0;
            else if (line.Contains("PLATA MODERNA") || line.Contains("PLATA MODERN"))
                report.PlataModerna += amount ?? 0;
        }
        return true;
    }

    private static decimal PaymentAmount(List<string> lines, List<string> folded, string[] labels)
    {
        for (var i = 0; i < folded.Count; i++)
        {
            var line = folded[i];
            if (line.Contains("SERTAR") || line.Contains("AVANS") || line.Contains("VANZ") || line.Contains("TVA"))
                continue;
            if (!labels.Any(line.Contains))
                continue;
            var values = Amounts(lines[i]).Where(value => value > 0).ToList();
            if (values.Count > 0)
                return values[^1];
            for (var j = i + 1; j < Math.Min(i + 4, lines.Count); j++)
            {
                var next = folded[j];
                if (next.Contains("VANZ") || next.Contains("TVA") || next.Contains("TOTAL"))
                    break;
                var nextValues = Amounts(lines[j]);
                if (nextValues.Count == 1)
                    return nextValues[0];
            }
        }
        return 0;
    }

    private static List<decimal> Amounts(string line)
    {
        var values = new List<decimal>();
        foreach (Match match in Regex.Matches(line, @"\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2}|\d{1,3}(?:,\d{3})+\.\d{2}|\d+\.\d{2}"))
        {
            var token = match.Value;
            if (Regex.IsMatch(line, Regex.Escape(token) + @"[./-]\d"))
                continue;
            var normalized = token.Contains(',') && token.Contains('.')
                ? (token.LastIndexOf(',') > token.LastIndexOf('.') ? token.Replace(".", "").Replace(',', '.') : token.Replace(",", ""))
                : token.Replace(',', '.');
            if (decimal.TryParse(normalized, NumberStyles.Number, CultureInfo.InvariantCulture, out var value))
                values.Add(Math.Round(value, 2, MidpointRounding.AwayFromZero));
        }
        return values;
    }

    private static List<List<string>> SplitReports(List<string> lines)
    {
        var indexes = new List<int>();
        for (var i = 0; i < lines.Count; i++)
        {
            var folded = Fold(lines[i]);
            if (folded.Contains("RAPORT FISCAL") || folded.Contains("Z REPORT"))
                indexes.Add(i);
        }
        if (indexes.Count <= 1)
            return lines.Count == 0 ? [] : [lines];
        var parts = new List<List<string>>();
        for (var i = 0; i < indexes.Count; i++)
        {
            var start = i == 0 ? 0 : indexes[i];
            var end = i + 1 < indexes.Count ? indexes[i + 1] : lines.Count;
            parts.Add(lines.GetRange(start, end - start));
        }
        return parts;
    }

    private static List<string> SplitLines(string text) =>
        text.Replace("\r", "\n").Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();

    private static decimal InferVat(decimal gross, int rate) =>
        gross <= 0 ? 0 : Math.Round(gross * rate / (100m + rate), 2, MidpointRounding.AwayFromZero);

    private static decimal Net(decimal gross, decimal vat)
    {
        var net = Math.Round(gross - vat, 2, MidpointRounding.AwayFromZero);
        return net < 0 ? 0 : net;
    }

    private static string Saft(int rate) => rate switch
    {
        21 => "310344",
        11 => "310351",
        5 => "310352",
        _ => "310324"
    };

    private static string Title(string account)
    {
        var value = account.Trim();
        if (value == "4111") return "Clienti";
        if (value == "4427") return "TVA colectata";
        if (value.StartsWith("701", StringComparison.Ordinal)) return "Venituri din vanzarea produselor finite";
        if (value.StartsWith("707", StringComparison.Ordinal)) return "Venituri din vanzarea marfurilor";
        if (value.StartsWith("704", StringComparison.Ordinal)) return "Venituri din lucrari executate si servicii prestate";
        if (value.StartsWith("706", StringComparison.Ordinal)) return "Venituri din chirii";
        if (value.StartsWith("708", StringComparison.Ordinal)) return "Venituri diverse";
        if (value is "267" or "267.1") return "GARANTIE depusa";
        if (value == "462") return "Bacsis";
        if (value == "446.2") return "BACSIS";
        if (value == "581") return "Viramente interne";
        if (value == "5311.0") return "Casa in lei - sediu";
        if (value.StartsWith("5311", StringComparison.Ordinal)) return "Casa in lei";
        if (value == "5125") return "Sume in curs de decontare";
        if (value == "5113") return "Efecte de incasat";
        return value;
    }

    private static string FileName(string firm, List<ZReportDraft> reports)
    {
        var dates = reports.Select(report => report.Date.Date).OrderBy(date => date).ToList();
        var first = dates[0].ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var last = dates[^1].ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var range = first == last ? first : first + "_" + last;
        return "ZETTA - " + SafeFile(firm).Replace('_', ' ') + " - " + range + ".xlsx";
    }

    private static string Sheet(IReadOnlyList<ZettaNcRow> rows)
    {
        var xml = new StringBuilder();
        xml.Append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>""");
        xml.Append(HeaderRow());
        for (var i = 0; i < rows.Count; i++)
            xml.Append(DataRow(i + 2, rows[i]));
        xml.Append("</sheetData></worksheet>");
        return xml.ToString();
    }

    private static readonly string[] Headers =
    [
        "Nr. inreg.", "Tip inregistrare", "Jurnal", "Data", "Data scadenta", "Numar document", "Cod tip factura",
        "Cont debit simbol", "Cont debit titlu", "Metoda de plata SAF-T", "Mecanism de plata SAF-T", "Tip Taxa SAF-T", "Cod Taxa SAF-T",
        "Cont credit simbol", "Cont credit titlu", "Metoda de plata SAF-T    ", "Mecanism de plata SAFT-T", "Tip Taxa SAF_T", "Cod TAXA SAF_T",
        "Explicatie", "Valoare", "Cod Partener", "Partener CIF", "Partener Nume", "Partener Rezidenta", "Partener Judet", "Partener Cont",
        "Angajat CNP", "Angajat Nume", "Angajat Cont", "Optiune TVA", "Cota TVA", "Cod TVA SAF-T", "Moneda", "Curs", "Valoare deviza",
        "Stornare - Nr. inreg.", "Incasari/plati", "Diferente curs", "TVA la incasare", "Colectare/Deducere TVA", "Efect de incasat/platit",
        "Banca efect", "Centre de cost", "Informatii export", "Punct de lucru", "Deductibilitate", "Reevaluare", "Factura simplificata",
        "Borderou de achizitie", "Carnet prod. Agricole", "Contract", "Document stornat"
    ];

    private static string HeaderRow()
    {
        var cells = new StringBuilder();
        for (var i = 0; i < Headers.Length; i++)
            cells.Append(TextCell(i, 1, Headers[i], true));
        return "<row r=\"1\">" + cells + "</row>";
    }

    private static string DataRow(int index, ZettaNcRow row)
    {
        var cells = new StringBuilder();
        void Text(int column, string value)
        {
            if (value.Length > 0)
                cells.Append(TextCell(column, index, value, false));
        }
        void Number(int column, decimal value) => cells.Append(NumberCell(column, index, value));
        Number(0, row.Number);
        Text(1, "Bon fiscal vanzare");
        Text(2, row.Journal);
        Number(3, row.Date);
        Number(4, row.Date);
        Text(5, row.Document);
        Text(7, row.Debit);
        Text(8, row.DebitTitle);
        Text(13, row.Credit);
        Text(14, row.CreditTitle);
        Text(19, row.Explanation);
        Number(20, row.Amount);
        Text(21, row.PartnerCode);
        Text(23, row.PartnerName);
        if (row.Debit == "4111" || row.Debit.StartsWith("4111.", StringComparison.Ordinal))
            Text(26, "D");
        else if (row.Credit == "4111" || row.Credit.StartsWith("4111.", StringComparison.Ordinal))
            Text(26, "C");
        Text(30, row.VatOption);
        if (row.VatRate is decimal rate)
            Number(31, rate);
        Text(32, row.Saft);
        Text(33, "RON");
        Number(39, 0);
        Text(44, "20230601-20230630-CielStd_CodSoc");
        Number(48, 0);
        Number(49, 0);
        Number(50, 0);
        Number(51, 0);
        Number(52, 0);
        Text(77, row.FirmCui);
        return "<row r=\"" + index.ToString(CultureInfo.InvariantCulture) + "\">" + cells + "</row>";
    }

    private static string TextCell(int column, int row, string value, bool bold)
    {
        var style = bold ? " s=\"1\"" : "";
        return "<c r=\"" + Cell(column, row) + "\" t=\"inlineStr\"" + style + "><is><t>" + Xml(value) + "</t></is></c>";
    }

    private static string NumberCell(int column, int row, decimal value) =>
        "<c r=\"" + Cell(column, row) + "\"><v>" + value.ToString("0.##", CultureInfo.InvariantCulture) + "</v></c>";

    private static string Cell(int column, int row)
    {
        var name = "";
        var n = column + 1;
        while (n > 0)
        {
            n--;
            name = (char)('A' + n % 26) + name;
            n /= 26;
        }
        return name + row.ToString(CultureInfo.InvariantCulture);
    }

    private static string Xml(string value) =>
        value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;");

    private static string Fold(string value)
    {
        var form = value.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(form.Length);
        foreach (var ch in form)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark)
                builder.Append(char.ToUpperInvariant(ch));
        }
        return builder.ToString();
    }

    private static string Compact(string value) => new(Fold(value).Where(char.IsLetterOrDigit).ToArray());

    private static string Digits(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return "";
        var digits = new string(value.Where(char.IsDigit).ToArray());
        return digits.TrimStart('0').Length == 0 ? digits : digits;
    }

    private static string Text(JsonElement row, string name) =>
        row.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : "";

    private static int IndexOfAny(string text, string[] needles)
    {
        var index = -1;
        foreach (var needle in needles)
        {
            var found = text.IndexOf(needle, StringComparison.Ordinal);
            if (found >= 0 && (index < 0 || found < index))
                index = found;
        }
        return index;
    }

    private static string Join(string left, string right) =>
        left.Length == 0 ? right : left + " " + right;
}
