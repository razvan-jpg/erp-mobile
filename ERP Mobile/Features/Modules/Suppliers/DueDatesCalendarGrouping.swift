import Foundation

struct DueDateCalendarSupplierRow: Identifiable, Sendable {
    let supplierId: UUID
    let supplierName: String
    let invoiceCount: Int
    let totalAmount: Decimal
    let moneda: String

    var id: UUID { supplierId }
}

struct DueDateCalendarDay: Identifiable, Sendable {
    let date: Date
    let totalAmount: Decimal
    let moneda: String
    let supplierRows: [DueDateCalendarSupplierRow]
    let containsOverdue: Bool
    let containsOverflow: Bool

    var id: Date { date }

    var hasAmount: Bool { totalAmount != 0 }
}

@MainActor
enum DueDatesCalendarGrouping {
    private static let dayCount = 30

    static func buildCalendar(
        from invoices: [SupplierInvoiceRow],
        referenceDate: Date = Date()
    ) -> [DueDateCalendarDay] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let today = calendar.startOfDay(for: referenceDate)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let calendarEnd = calendar.date(byAdding: .day, value: dayCount - 1, to: yesterday) else {
            return []
        }

        let openInvoices = invoices.filter(isOpenInvoice)
        var bucketInvoices: [Date: [SupplierInvoiceRow]] = [:]

        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: yesterday) else { continue }
            bucketInvoices[calendar.startOfDay(for: day)] = []
        }

        for invoice in openInvoices {
            let dueDay = calendar.startOfDay(for: invoice.effectiveDueDate)
            let bucketDay: Date
            if dueDay < today {
                bucketDay = yesterday
            } else if dueDay > calendarEnd {
                bucketDay = calendarEnd
            } else {
                bucketDay = dueDay
            }
            bucketInvoices[bucketDay, default: []].append(invoice)
        }

        return (0..<dayCount).compactMap { offset -> DueDateCalendarDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: yesterday) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            let dayInvoices = bucketInvoices[dayStart] ?? []
            let supplierRows = supplierRows(from: dayInvoices)
            let totalAmount = supplierRows.reduce(Decimal.zero) { $0 + $1.totalAmount }
            let moneda = supplierRows.first?.moneda ?? "RON"
            let containsOverdue = dayStart == yesterday && dayInvoices.contains {
                calendar.startOfDay(for: $0.effectiveDueDate) < today
            }
            let containsOverflow = dayStart == calendarEnd && dayInvoices.contains {
                calendar.startOfDay(for: $0.effectiveDueDate) > calendarEnd
            }

            return DueDateCalendarDay(
                date: dayStart,
                totalAmount: totalAmount,
                moneda: moneda,
                supplierRows: supplierRows,
                containsOverdue: containsOverdue,
                containsOverflow: containsOverflow
            )
        }
    }

    private static func supplierRows(from invoices: [SupplierInvoiceRow]) -> [DueDateCalendarSupplierRow] {
        let grouped = Dictionary(grouping: invoices, by: \.supplierId)
        return grouped.compactMap { supplierId, supplierInvoices in
            let total = supplierInvoices.reduce(Decimal.zero) { partial, invoice in
                partial + invoice.restDePlata
            }
            guard total != 0 else { return nil }
            return DueDateCalendarSupplierRow(
                supplierId: supplierId,
                supplierName: supplierInvoices.first?.supplierName ?? "—",
                invoiceCount: supplierInvoices.count,
                totalAmount: total,
                moneda: supplierInvoices.first?.moneda ?? "RON"
            )
        }
        .sorted { lhs, rhs in
            lhs.supplierName.localizedStandardCompare(rhs.supplierName) == .orderedAscending
        }
    }

    private static func isOpenInvoice(_ invoice: SupplierInvoiceRow) -> Bool {
        (invoice.status == .neplatita || invoice.status == .partial) && invoice.restDePlata != 0
    }
}
