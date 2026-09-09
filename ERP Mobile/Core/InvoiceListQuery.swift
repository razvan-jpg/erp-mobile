import Foundation

enum InvoiceListPeriodFilter: CaseIterable, Identifiable {
    case today
    case last5Days
    case thisMonth
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .today: return L10n.tr("invoices.period_today")
        case .last5Days: return L10n.tr("invoices.period_last_5_days")
        case .thisMonth: return L10n.tr("invoices.period_this_month")
        case .all: return L10n.tr("invoices.period_all")
        }
    }

    func includes(createdAt: Date?, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .today, .last5Days, .thisMonth:
            guard let createdAt else { return true }
            guard let range = createdAtRange(calendar: calendar) else { return true }
            return createdAt >= range.from && createdAt < range.toExclusive
        }
    }

    func createdAtRange(calendar: Calendar = .current, now: Date = Date()) -> (from: Date, toExclusive: Date)? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
            return (today, tomorrow)
        case .last5Days:
            guard let start = calendar.date(byAdding: .day, value: -4, to: today),
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
            return (start, tomorrow)
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: today)
            guard let monthStart = calendar.date(from: components),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
            return (monthStart, nextMonth)
        case .all:
            return nil
        }
    }
}

enum InvoiceListDateFilter: Equatable, Sendable {
    case none
    case created(from: Date, toExclusive: Date)
    case invoiceDate(from: Date, to: Date)

    static func listQuery(
        period: InvoiceListPeriodFilter,
        intervalEnabled: Bool,
        intervalFrom: Date,
        intervalTo: Date,
        calendar: Calendar = .current
    ) -> InvoiceListDateFilter {
        if intervalEnabled {
            let start = calendar.startOfDay(for: min(intervalFrom, intervalTo))
            let end = calendar.startOfDay(for: max(intervalFrom, intervalTo))
            return .invoiceDate(from: start, to: end)
        }
        if let range = period.createdAtRange(calendar: calendar) {
            return .created(from: range.from, toExclusive: range.toExclusive)
        }
        return .none
    }

    static func timestampString(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func dateOnlyString(_ date: Date) -> String {
        SupabaseDecoding.dateOnlyString(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
