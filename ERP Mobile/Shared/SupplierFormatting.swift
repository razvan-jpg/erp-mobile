import Foundation

enum SupplierFormatting {
    private static let romanianLocale = Locale(identifier: "ro_RO")

    private static let displayAmountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = romanianLocale
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = "."
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RON"
        formatter.locale = romanianLocale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let inputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = romanianLocale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let inputDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = romanianLocale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()

    private static let inputDateTimeSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = romanianLocale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()

    static func currency(_ value: Decimal, code: String = "RON") -> String {
        let amount = roundedToTwoDecimals(value)
        if code == "RON" {
            return currencyFormatter.string(from: amount) ?? "\(displayAmount(amount)) lei"
        }
        return "\(displayAmount(amount)) \(code)"
    }

    static func date(_ value: Date?) -> String {
        guard let value else { return "—" }
        return inputDateString(value)
    }

    static func compactDate(_ value: Date?) -> String {
        date(value)
    }

    static func dateTime(_ value: Date?, includeSeconds: Bool = false) -> String {
        guard let value else { return "—" }
        let formatter = includeSeconds ? inputDateTimeSecondsFormatter : inputDateTimeFormatter
        return formatter.string(from: value)
    }

    static func monthYear(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: value).capitalized
    }

    static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    static func isInMonth(_ date: Date, month: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.year, from: date) == calendar.component(.year, from: month)
            && calendar.component(.month, from: date) == calendar.component(.month, from: month)
    }

    static func weekdayName(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "EEEE"
        let name = formatter.string(from: value)
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    static func compactAmount(_ value: Decimal, code: String = "RON") -> String {
        let amount = amountString(value)
        guard code != "RON" else { return amount }
        return "\(amount) \(code)"
    }

    /// Data scadență = data facturii + număr zile (0 = aceeași zi; negativ → fără calcul).
    static func dueDate(from invoiceDate: Date, paymentTermDays: Int) -> Date? {
        guard paymentTermDays >= 0 else { return nil }
        let start = Calendar.current.startOfDay(for: invoiceDate)
        return Calendar.current.date(byAdding: .day, value: paymentTermDays, to: start)
    }

    /// Scadență Metro: achiziție/factură 1–15 → ziua 23 în aceeași lună; 16–sfârșit lună → ziua 8 în luna următoare.
    static func metroDueDate(from referenceDate: Date) -> Date {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let dayOfMonth = calendar.component(.day, from: referenceDay)

        var components = calendar.dateComponents([.year, .month], from: referenceDay)
        if dayOfMonth <= 15 {
            components.day = 23
        } else {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: referenceDay) else {
                return referenceDay
            }
            components = calendar.dateComponents([.year, .month], from: nextMonth)
            components.day = 8
        }

        return calendar.startOfDay(for: calendar.date(from: components) ?? referenceDay)
    }

    /// Număr zile scadență = diferența în zile calendaristice între data facturii și data scadenței.
    static func paymentTermDays(from invoiceDate: Date, dueDate: Date?) -> Int {
        guard let dueDate else { return 0 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: invoiceDate)
        let end = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, days)
    }

    static func inputDateString(_ value: Date) -> String {
        inputDateFormatter.string(from: value)
    }

    static func parseInputDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = inputDateFormatter.date(from: trimmed) {
            return Calendar.current.startOfDay(for: date)
        }

        let dotted = trimmed.replacingOccurrences(of: ".", with: "/")
        if dotted != trimmed, let date = inputDateFormatter.date(from: dotted) {
            return Calendar.current.startOfDay(for: date)
        }

        let digits = trimmed.filter(\.isNumber)
        if digits.count == 8 {
            let day = String(digits.prefix(2))
            let month = String(digits.dropFirst(2).prefix(2))
            let year = String(digits.suffix(4))
            let normalized = "\(day)/\(month)/\(year)"
            if let date = inputDateFormatter.date(from: normalized) {
                return Calendar.current.startOfDay(for: date)
            }
        }

        return nil
    }

    /// Acceptă atât virgula cât și punctul ca separator zecimal (ex. 1500,50 / 1500.50 / 1.234,56).
    static func parseAmount(_ text: String, maxFractionDigits: Int = 2) -> Decimal? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        value = value.replacingOccurrences(of: " ", with: "")
        value = value.replacingOccurrences(of: "\u{00A0}", with: "")

        let isNegative = value.hasPrefix("-")
        if isNegative {
            value = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
        }

        let hasComma = value.contains(",")
        let hasDot = value.contains(".")

        if hasComma && hasDot {
            value = normalizeMixedSeparators(value)
        } else if hasComma {
            value = normalizeSingleSeparator(value, separator: ",", maxFractionDigits: maxFractionDigits)
        } else if hasDot {
            value = normalizeSingleSeparator(value, separator: ".", maxFractionDigits: maxFractionDigits)
        }

        guard let amount = Decimal(string: value) else { return nil }
        return isNegative ? -amount : amount
    }

    /// Limitează partea zecimală introdusă (ex. facturi: max. 4 zecimale).
    static func limitAmountInputFractionDigits(_ text: String, maxFractionDigits: Int) -> String {
        guard maxFractionDigits >= 0,
              let sepIndex = text.lastIndex(where: { $0 == "," || $0 == "." }) else {
            return text
        }

        let before = text[..<sepIndex]
        let separator = text[sepIndex]
        let after = text[text.index(after: sepIndex)...]
        let digits = after.filter(\.isNumber)
        guard digits.count > maxFractionDigits else { return text }

        let trimmedDigits = String(digits.prefix(maxFractionDigits))
        return String(before) + String(separator) + trimmedDigits
    }

    static func roundAmount(_ value: Decimal) -> Decimal {
        var rounded = Decimal()
        var input = value
        NSDecimalRound(&rounded, &input, 2, .plain)
        return rounded
    }

    private static func normalizeMixedSeparators(_ value: String) -> String {
        guard let lastComma = value.lastIndex(of: ","),
              let lastDot = value.lastIndex(of: ".") else {
            return value
        }

        if lastComma > lastDot {
            // Format românesc: 1.234,56
            return value
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }

        // Format internațional: 1,234.56
        return value.replacingOccurrences(of: ",", with: "")
    }

    private static func normalizeSingleSeparator(
        _ value: String,
        separator: Character,
        maxFractionDigits: Int
    ) -> String {
        let parts = value.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else { return value }

        if parts.count == 2 {
            let fractional = parts[1]
            if fractional.count <= maxFractionDigits {
                return "\(parts[0]).\(fractional)"
            }
            return parts.joined()
        }

        let last = parts.last ?? ""
        if last.count <= maxFractionDigits {
            let integerPart = parts.dropLast().joined()
            return "\(integerPart).\(last)"
        }

        return parts.joined()
    }

    static func amountString(_ value: Decimal) -> String {
        displayAmount(roundedToTwoDecimals(value))
    }

    static var invoiceAmountInputMaxFractionDigits: Int { 4 }

    static var invoiceAmountHint: String { L10n.tr("invoices.amount_input_hint") }

    private static func displayAmount(_ value: NSDecimalNumber) -> String {
        displayAmountFormatter.string(from: value) ?? fallbackTwoDecimals(value)
    }

    private static func roundedToTwoDecimals(_ value: Decimal) -> NSDecimalNumber {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        return rounded as NSDecimalNumber
    }

    private static func fallbackTwoDecimals(_ value: NSDecimalNumber) -> String {
        String(format: "%.2f", value.doubleValue).replacingOccurrences(of: ".", with: ",")
    }

    static var amountPlaceholder: String { L10n.tr("format.amount_placeholder") }

    static var amountHint: String { L10n.tr("format.amount_hint") }
}
