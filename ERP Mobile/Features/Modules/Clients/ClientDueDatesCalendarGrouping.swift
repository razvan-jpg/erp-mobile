import Foundation

struct DueDateCalendarClientRow: Identifiable, Sendable {
    let clientId: UUID
    let clientName: String
    let invoiceCount: Int
    let totalAmount: Decimal
    let moneda: String

    var id: UUID { clientId }
}

struct ClientDueDateCalendarDay: Identifiable, Sendable {
    let date: Date
    let totalAmount: Decimal
    let moneda: String
    let clientRows: [DueDateCalendarClientRow]
    let containsOverdue: Bool
    let containsOverflow: Bool

    var id: Date { date }

    var hasAmount: Bool { totalAmount != 0 }
}

@MainActor
enum ClientDueDatesCalendarGrouping {
    private static let dayCount = 30

    static func buildCalendar(
        from invoices: [ClientInvoiceRow],
        referenceDate: Date = Date()
    ) -> [ClientDueDateCalendarDay] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let today = calendar.startOfDay(for: referenceDate)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let calendarEnd = calendar.date(byAdding: .day, value: dayCount - 1, to: yesterday) else {
            return []
        }

        let openInvoices = invoices.filter(isOpenInvoice)
        var bucketInvoices: [Date: [ClientInvoiceRow]] = [:]

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

        return (0..<dayCount).compactMap { offset -> ClientDueDateCalendarDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: yesterday) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            let dayInvoices = bucketInvoices[dayStart] ?? []
            let clientRows = clientRows(from: dayInvoices)
            let totalAmount = clientRows.reduce(Decimal.zero) { $0 + $1.totalAmount }
            let moneda = clientRows.first?.moneda ?? "RON"
            let containsOverdue = dayStart == yesterday && dayInvoices.contains {
                calendar.startOfDay(for: $0.effectiveDueDate) < today
            }
            let containsOverflow = dayStart == calendarEnd && dayInvoices.contains {
                calendar.startOfDay(for: $0.effectiveDueDate) > calendarEnd
            }

            return ClientDueDateCalendarDay(
                date: dayStart,
                totalAmount: totalAmount,
                moneda: moneda,
                clientRows: clientRows,
                containsOverdue: containsOverdue,
                containsOverflow: containsOverflow
            )
        }
    }

    private static func clientRows(from invoices: [ClientInvoiceRow]) -> [DueDateCalendarClientRow] {
        let grouped = Dictionary(grouping: invoices, by: \.clientId)
        return grouped.compactMap { clientId, clientInvoices in
            let total = clientInvoices.reduce(Decimal.zero) { partial, invoice in
                partial + invoice.restDePlata
            }
            guard total != 0 else { return nil }
            return DueDateCalendarClientRow(
                clientId: clientId,
                clientName: clientInvoices.first?.clientName ?? "—",
                invoiceCount: clientInvoices.count,
                totalAmount: total,
                moneda: clientInvoices.first?.moneda ?? "RON"
            )
        }
        .sorted { lhs, rhs in
            lhs.clientName.localizedStandardCompare(rhs.clientName) == .orderedAscending
        }
    }

    private static func isOpenInvoice(_ invoice: ClientInvoiceRow) -> Bool {
        (invoice.status == .neplatita || invoice.status == .partial) && invoice.restDePlata != 0
    }
}
