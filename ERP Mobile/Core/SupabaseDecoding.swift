import Foundation

enum SupabaseDecoding {
    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                if let date = parseDate(string) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Format dată invalid: \(string)"
                )
            }
            // JSONEncoder default Date = seconds since reference date (local cash-register fallback).
            if let interval = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: interval)
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Format dată invalid."
            )
        }
        return decoder
    }()

    static func parseDate(_ string: String, calendar: Calendar = .current) -> Date? {
        let trimmed = normalizePostgreSQLTimestamp(string.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty else { return nil }

        // Date-only values are calendar days (invoice / NIR / cash-register date), not UTC midnights.
        if let date = calendarDate(from: trimmed, calendar: calendar) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) { return date }

        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        if let date = internet.date(from: trimmed) { return date }

        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        let posix = DateFormatter()
        posix.calendar = Calendar(identifier: .gregorian)
        posix.locale = Locale(identifier: "en_US_POSIX")
        posix.timeZone = TimeZone(secondsFromGMT: 0)
        for pattern in patterns {
            posix.dateFormat = pattern
            if let date = posix.date(from: trimmed) { return date }
        }

        return nil
    }

    static func dateOnlyString(from date: Date, calendar: Calendar = .current) -> String {
        formattedDateOnly(date, calendar: calendar)
    }

    static func dateOnlyString(from date: Date?, calendar: Calendar = .current) -> String? {
        guard let date else { return nil }
        return formattedDateOnly(date, calendar: calendar)
    }

    /// Calendar Y/M/D in the given timezone — never UTC, so 5 Aug 00:00 EEST stays `2026-08-05`.
    private static func formattedDateOnly(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func calendarDate(from string: String, calendar: Calendar) -> Date? {
        guard string.count == 10 else { return nil }
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day)
        else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    /// Normalizează fracțiunile de secundă PostgreSQL (1–6 cifre) pentru decodare stabilă.
    private static func normalizePostgreSQLTimestamp(_ string: String) -> String {
        guard let dotIndex = string.firstIndex(of: ".") else { return string }

        let afterDot = string[string.index(after: dotIndex)...]
        guard let timezoneIndex = afterDot.firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" || $0 == "z" }) else {
            return string
        }

        let fraction = String(afterDot[..<timezoneIndex])
        let timezone = String(afterDot[timezoneIndex...])
        let normalizedFraction: String
        if fraction.count < 6 {
            normalizedFraction = fraction + String(repeating: "0", count: 6 - fraction.count)
        } else if fraction.count > 6 {
            normalizedFraction = String(fraction.prefix(6))
        } else {
            normalizedFraction = fraction
        }

        return "\(string[..<dotIndex]).\(normalizedFraction)\(timezone)"
    }

    nonisolated static func decodeDecimal(from container: SingleValueDecodingContainer) throws -> Decimal {
        if let string = try? container.decode(String.self) {
            let normalized = string
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            if let decimal = Decimal(string: normalized) {
                return decimal
            }
        }
        if let double = try? container.decode(Double.self) {
            return Decimal(double)
        }
        if let int = try? container.decode(Int.self) {
            return Decimal(int)
        }
        throw DecodingError.typeMismatch(
            Decimal.self,
            DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Valoare numerică invalidă."
            )
        )
    }
}

@propertyWrapper
struct SupabaseOptionalDecimal: Codable, Hashable, Sendable {
    var wrappedValue: Decimal?

    nonisolated init(wrappedValue: Decimal?) {
        self.wrappedValue = wrappedValue
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = nil
            return
        }
        wrappedValue = try SupabaseDecoding.decodeDecimal(from: container)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let wrappedValue else {
            try container.encodeNil()
            return
        }
        try container.encode(NSDecimalNumber(decimal: wrappedValue).stringValue)
    }
}

@propertyWrapper
struct SupabaseDecimal: Codable, Hashable, Sendable {
    var wrappedValue: Decimal

    nonisolated init(wrappedValue: Decimal) {
        self.wrappedValue = wrappedValue
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = try SupabaseDecoding.decodeDecimal(from: container)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(NSDecimalNumber(decimal: wrappedValue).stringValue)
    }
}
