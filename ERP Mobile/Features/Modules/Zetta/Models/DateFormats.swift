import Foundation

/// Format afișare date Zetta — același pattern ca SupplierFormatting (zz/ll/aaaa), nonisolated pentru modele Z.
nonisolated enum DateFormats {
    static func displayDate(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func displayDateTime(from date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    private static let romanianLocale = Locale(identifier: "ro_RO")

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = romanianLocale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = romanianLocale
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()
}
