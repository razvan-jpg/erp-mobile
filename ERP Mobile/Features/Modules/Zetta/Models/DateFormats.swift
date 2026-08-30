import Foundation

/// Format afișare date Zetta — delegat la formatarea standard a aplicației (zz/ll/aaaa).
enum DateFormats {
    static func displayDate(from date: Date) -> String {
        SupplierFormatting.inputDateString(date)
    }

    static func displayDateTime(from date: Date) -> String {
        SupplierFormatting.dateTime(date, includeSeconds: true)
    }
}
