using System.Globalization;

namespace ERPMobile.Services;

public static class StockFormat
{
    public static int Digits { get; private set; } = 2;

    public static int Normalize(int digits) => digits is 2 or 3 or 4 ? digits : 2;

    public static void Apply(int digits) => Digits = Normalize(digits);

    public static int Fallback(CompanyRow? company)
    {
        if (company?.IsNectarie == true)
            return 4;
        return 2;
    }

    public static string Text(decimal value)
    {
        var digits = Digits;
        var rounded = decimal.Round(value, digits, MidpointRounding.AwayFromZero);
        return rounded.ToString("0." + new string('0', digits), CultureInfo.GetCultureInfo("ro-RO"));
    }
}
