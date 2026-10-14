using System.Globalization;
using System.Text;
using System.Text.Json;

namespace ERPMobile.Services;

/// <summary>
/// Comenzi pentru driverul FiscalNet (Datecs FP-700): fișier în folderul Bonuri, răspuns în folderul Răspuns.
/// </summary>
public static class FiscalNet
{
    public const string AdDateconta = "https://factura.dateconta.ro";
    public const string AdBeauty = "https://www.beautymanager.net";

    public sealed record SaleLine(
        string Name,
        decimal UnitPrice,
        decimal Quantity,
        int VatGroup,
        bool FullDiscount,
        bool Discountable,
        string? Note);

    public readonly record struct BuiltReceipt(IReadOnlyList<string> Commands, decimal Payment, decimal CashTaken, decimal CardTaken);

    public readonly record struct SplitPay(decimal Cash, decimal Card);

    public readonly record struct Reply(
        int BonOk,
        string Number,
        string ErrorCode,
        string ErrorInfo,
        string Authorization,
        bool TimedOut,
        bool Incomplete);

    public static int VatGroup(decimal? rate)
    {
        if (rate == null)
            return 1;
        if (rate >= 19)
            return 1;
        if (rate >= 9)
            return 2;
        return 4;
    }

    public static int PayType(string channel) => channel switch
    {
        "card" => 2,
        "cash" => 1,
        _ => 7
    };

    public static BuiltReceipt BuildReceipt(
        string? fiscalCode,
        IReadOnlyList<SaleLine> lines,
        decimal targetTotal,
        int paymentType,
        decimal tender,
        string? documentUrl,
        decimal? splitEntered = null,
        bool splitEnteredIsCash = true)
    {
        var prepared = new List<(SaleLine Line, int Gross)>();
        foreach (var line in lines)
        {
            if (line.UnitPrice <= 0 || line.Quantity <= 0)
                continue;
            prepared.Add((line, LineBani(line.UnitPrice, line.Quantity)));
        }

        var discountable = new List<int>();
        var discountableIndex = new List<int>();
        var natural = 0;
        for (var i = 0; i < prepared.Count; i++)
        {
            var item = prepared[i];
            if (item.Line.FullDiscount)
                continue;
            natural += item.Gross;
            if (item.Line.Discountable)
            {
                discountable.Add(item.Gross);
                discountableIndex.Add(i);
            }
        }

        var target = Math.Max(0, Bani(targetTotal));
        var needed = Math.Max(0, natural - target);
        var cuts = Cuts(discountable, needed);
        var cutByLine = new int[prepared.Count];
        var cutSum = 0;
        for (var i = 0; i < discountableIndex.Count; i++)
        {
            cutByLine[discountableIndex[i]] = cuts[i];
            cutSum += cuts[i];
        }

        var payment = Math.Max(0, natural - cutSum);
        var commands = new List<string>();
        var notes = new List<string>();
        var code = Sanitize(fiscalCode ?? "", 20);
        if (code.Length > 0)
            commands.Add("CF^" + code);

        for (var i = 0; i < prepared.Count; i++)
        {
            var line = prepared[i].Line;
            var price = Bani(line.UnitPrice);
            var qty = Milli(line.Quantity);
            var group = line.VatGroup is >= 1 and <= 5 ? line.VatGroup : 1;
            commands.Add("S^" + Sanitize(line.Name, 42) + "^" + price + "^" + qty + "^buc^" + group + "^1");
            if (line.FullDiscount)
                commands.Add("DV^" + prepared[i].Gross + "^" + group);
            else if (cutByLine[i] > 0)
                commands.Add("DV^" + cutByLine[i] + "^" + group);
            var note = Sanitize(line.Note ?? "", 42);
            if (note.Length > 0)
                notes.Add(note);
        }

        foreach (var note in notes)
            commands.Add("TL^" + note);

        if (!string.IsNullOrWhiteSpace(documentUrl))
            commands.Add("CB^" + documentUrl.Trim() + "^4");
        commands.Add("CB^" + AdDateconta + "^4");
        commands.Add("CB^" + AdBeauty + "^4");

        var parts = SplitBani(payment, splitEntered, splitEnteredIsCash);
        if (splitEntered != null)
        {
            if (parts.Cash > 0)
                commands.Add("P^1^" + parts.Cash);
            if (parts.Card > 0)
                commands.Add("P^2^" + parts.Card);
        }
        else
        {
            var cashIn = paymentType == 1 && tender > 0 ? Bani(tender) : 0;
            var sent = cashIn > payment ? cashIn : payment;
            commands.Add("P^" + paymentType + "^" + sent);
        }
        var cashTaken = splitEntered != null ? parts.Cash : paymentType == 1 ? payment : 0;
        var cardTaken = splitEntered != null ? parts.Card : paymentType == 2 ? payment : 0;
        return new BuiltReceipt(commands, payment / 100m, cashTaken / 100m, cardTaken / 100m);
    }

    public static SplitPay Split(decimal payment, decimal entered, bool enteredIsCash)
    {
        var parts = SplitBani(Math.Max(0, Bani(payment)), entered, enteredIsCash);
        return new SplitPay(parts.Cash / 100m, parts.Card / 100m);
    }

    public static IReadOnlyList<string> Pos(decimal amount) => new[] { "POS^" + Math.Max(0, Bani(amount)) };

    public static IReadOnlyList<string> Report(string kind) => new[] { kind + "^" };

    /// <summary>Deschidere sertar. Se trimite după un bon încasat numerar sau numerar + card.</summary>
    public static IReadOnlyList<string> OpenDrawer() => new[] { "DS^" };

    public static IReadOnlyList<string> NonFiscal(IEnumerable<string> lines, string? documentUrl)
    {
        var commands = new List<string>();
        foreach (var line in lines)
        {
            foreach (var part in Wrap(Sanitize(line, 400), 42))
            {
                if (part.Length > 0)
                    commands.Add("TL^" + part);
            }
        }
        if (!string.IsNullOrWhiteSpace(documentUrl))
            commands.Add("CB^" + documentUrl.Trim() + "^4");
        commands.Add("CB^" + AdDateconta + "^4");
        commands.Add("CB^" + AdBeauty + "^4");
        return commands;
    }

    public static Reply Parse(string text)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var raw in text.Split('\n'))
        {
            var line = raw.Trim().Trim('\r');
            var split = line.IndexOf('=');
            if (split <= 0)
                continue;
            map[line[..split].Trim()] = line[(split + 1)..].Trim();
        }
        if (!map.TryGetValue("BONOK", out var okText) || !int.TryParse(okText, NumberStyles.Integer, CultureInfo.InvariantCulture, out var ok))
            return new Reply(0, "", "", "", "", false, true);
        map.TryGetValue("NRBON", out var number);
        map.TryGetValue("ERRCODE", out var code);
        map.TryGetValue("ERRINFO", out var info);
        map.TryGetValue("CodAutorizare", out var auth);
        return new Reply(ok, number ?? "", code ?? "", info ?? "", auth ?? "", false, false);
    }

    public static string Failure(Reply reply, string fallback)
    {
        if (reply.TimedOut)
            return "FiscalNet nu a răspuns la timp. Verificați că driverul rulează și că folderul Răspuns este lângă Bonuri.";
        var text = fallback;
        if (reply.ErrorInfo.Length > 0)
            text += "\n" + reply.ErrorInfo;
        else if (reply.ErrorCode.Length > 0)
            text += "\nCod " + reply.ErrorCode;
        return text;
    }

    public static string FileName(string prefix, bool nonFiscal)
    {
        var stamp = DateTime.Now.ToString("yyyyMMddHHmmssfff", CultureInfo.InvariantCulture);
        var noise = Random.Shared.Next(1000, 10000).ToString(CultureInfo.InvariantCulture);
        var name = prefix + stamp + noise;
        return (nonFiscal ? "nf_" : "") + name + ".txt";
    }

    private static (int Cash, int Card) SplitBani(int payment, decimal? entered, bool enteredIsCash)
    {
        if (entered == null)
            return (0, 0);
        var total = Math.Max(0, payment);
        var taken = Math.Min(Math.Max(0, Bani(entered.Value)), total);
        var rest = total - taken;
        return enteredIsCash ? (taken, rest) : (rest, taken);
    }

    private static int Bani(decimal value) =>
        (int)Math.Round(value * 100m, 0, MidpointRounding.AwayFromZero);

    private static int Milli(decimal value) =>
        (int)Math.Round(value * 1000m, 0, MidpointRounding.AwayFromZero);

    private static int LineBani(decimal unitPrice, decimal quantity)
    {
        var price = Bani(unitPrice);
        var qty = Milli(quantity);
        return (int)Math.Round(price * qty / 1000m, 0, MidpointRounding.AwayFromZero);
    }

    private static int[] Cuts(IReadOnlyList<int> gross, int needed)
    {
        var cuts = new int[gross.Count];
        if (needed <= 0 || gross.Count == 0)
            return cuts;
        var sum = gross.Sum();
        if (sum <= 0)
            return cuts;
        var left = Math.Min(needed, sum);
        var allocated = 0;
        for (var i = 0; i < gross.Count; i++)
        {
            int share;
            if (i == gross.Count - 1)
                share = left - allocated;
            else
                share = (int)Math.Round(gross[i] * (decimal)left / sum, 0, MidpointRounding.AwayFromZero);
            share = Math.Max(0, Math.Min(gross[i], Math.Min(share, left - allocated)));
            cuts[i] = share;
            allocated += share;
        }
        var drift = left - cuts.Sum();
        for (var i = cuts.Length - 1; i >= 0 && drift != 0; i--)
        {
            var step = drift > 0 ? Math.Min(gross[i] - cuts[i], drift) : -Math.Min(cuts[i], -drift);
            cuts[i] += step;
            drift -= step;
        }
        return cuts;
    }

    private static string Sanitize(string value, int max)
    {
        var builder = new StringBuilder(value.Length);
        foreach (var character in value)
        {
            if (character is '^' or '\r' or '\n' or '\t')
            {
                builder.Append(' ');
                continue;
            }
            builder.Append(character switch
            {
                'ă' or 'â' => 'a',
                'Ă' or 'Â' => 'A',
                'î' => 'i',
                'Î' => 'I',
                'ș' or 'ş' => 's',
                'Ș' or 'Ş' => 'S',
                'ț' or 'ţ' => 't',
                'Ț' or 'Ţ' => 'T',
                _ => character
            });
        }
        var text = builder.ToString().Trim();
        while (text.Contains("  ", StringComparison.Ordinal))
            text = text.Replace("  ", " ", StringComparison.Ordinal);
        return text.Length <= max ? text : text[..max].Trim();
    }

    private static IEnumerable<string> Wrap(string text, int width)
    {
        if (text.Length == 0)
            yield break;
        var rest = text;
        while (rest.Length > width)
        {
            var cut = rest.LastIndexOf(' ', width);
            if (cut < 8)
                cut = width;
            yield return rest[..cut].Trim();
            rest = rest[cut..].Trim();
        }
        if (rest.Length > 0)
            yield return rest;
    }
}

public static class FiscalNetStation
{
    private static string ConfigPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Dateconta",
        "ERP Mobile",
        "fiscalnet.json");

    public static bool IsReady
    {
        get
        {
            var bonuri = LoadBonuri();
            return !string.IsNullOrEmpty(bonuri)
                && Directory.Exists(bonuri)
                && Directory.Exists(ReplyFolder(bonuri));
        }
    }

    public static string? SaveBonuriFolder(string path)
    {
        if (!Directory.Exists(path))
            return "Folderul ales nu există.";
        if (!Directory.Exists(ReplyFolder(path)))
            return "Lângă folderul Bonuri trebuie să existe folderul Răspuns al FiscalNet.";
        Directory.CreateDirectory(Path.GetDirectoryName(ConfigPath)!);
        File.WriteAllText(ConfigPath, JsonSerializer.Serialize(new Dictionary<string, string> { ["bonuri"] = path }));
        return null;
    }

    public static async Task<FiscalNet.Reply> SendAsync(string fileName, IReadOnlyList<string> commands, TimeSpan timeout)
    {
        var bonuri = LoadBonuri();
        if (string.IsNullOrEmpty(bonuri) || !Directory.Exists(bonuri))
            return new FiscalNet.Reply(0, "", "", "Folderul Bonuri nu este ales.", "", false, false);
        var raspuns = ReplyFolder(bonuri);
        if (!Directory.Exists(raspuns))
            return new FiscalNet.Reply(0, "", "", "Lipsește folderul Răspuns de lângă Bonuri.", "", false, false);

        var finalPath = Path.Combine(bonuri, fileName);
        var replyPath = Path.Combine(raspuns, fileName);
        try
        {
            if (File.Exists(replyPath))
                File.Delete(replyPath);
        }
        catch
        {
            // Un răspuns vechi blocat nu oprește comanda nouă; numele este unic.
        }

        var body = string.Join("\r\n", commands) + "\r\n";
        var temp = Path.Combine(Path.GetTempPath(), fileName + ".part");
        await File.WriteAllTextAsync(temp, body, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        try
        {
            File.Move(temp, finalPath, overwrite: true);
        }
        catch
        {
            File.Copy(temp, finalPath, overwrite: true);
            File.Delete(temp);
        }

        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (File.Exists(replyPath))
            {
                try
                {
                    string text;
                    await using (var stream = new FileStream(replyPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                    using (var reader = new StreamReader(stream, Encoding.UTF8))
                        text = await reader.ReadToEndAsync();
                    var parsed = FiscalNet.Parse(text);
                    if (!parsed.Incomplete)
                        return parsed;
                }
                catch (IOException)
                {
                    // Driverul încă scrie fișierul.
                }
            }
            await Task.Delay(300);
        }
        return new FiscalNet.Reply(0, "", "", "", "", true, false);
    }

    private static string? LoadBonuri()
    {
        try
        {
            if (!File.Exists(ConfigPath))
                return null;
            var json = File.ReadAllText(ConfigPath);
            var parsed = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
            return parsed != null && parsed.TryGetValue("bonuri", out var path) ? path : null;
        }
        catch
        {
            return null;
        }
    }

    private static string ReplyFolder(string bonuri) =>
        Path.Combine(Directory.GetParent(bonuri)?.FullName ?? bonuri, "Raspuns");
}
