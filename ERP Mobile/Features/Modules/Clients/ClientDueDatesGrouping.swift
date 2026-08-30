import Foundation

struct ClientDueSummary: Identifiable, Sendable {
    let clientId: UUID
    let clientName: String
    let invoiceCount: Int
    let totalAmount: Decimal
    let moneda: String
    let daysOverdue: Int?
    let daysUntilDue: Int?

    var id: UUID { clientId }
}

struct ClientDueDateCategorySection: Identifiable, Sendable {
    let kind: DueDateCategoryKind
    let title: String
    let rows: [ClientDueSummary]
    let categoryTotal: Decimal
    let moneda: String

    var id: String { kind.rawValue }

    var isEmpty: Bool { rows.isEmpty }
}

@MainActor
enum ClientDueDatesGrouping {
    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    static func buildSections(from invoices: [ClientInvoiceRow]) -> [ClientDueDateCategorySection] {
        let today = calendar.startOfDay(for: Date())
        let weekStart = startOfWeek(containing: today)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today

        let summaries = clientSummaries(from: invoices, today: today, weekEnd: weekEnd)

        var overdue: [ClientDueSummary] = []
        var currentWeek: [ClientDueSummary] = []
        var future: [ClientDueSummary] = []

        for summary in summaries {
            guard let referenceDueDate = referenceDueDate(for: summary, in: invoices) else { continue }
            let kind = category(forEffectiveDueDate: referenceDueDate, today: today, weekEnd: weekEnd)
            switch kind {
            case .overdue: overdue.append(summary)
            case .currentWeek: currentWeek.append(summary)
            case .future: future.append(summary)
            }
        }

        return [
            makeSection(kind: .overdue, title: L10n.tr("due_dates.category_overdue"), rows: overdue),
            makeSection(
                kind: .currentWeek,
                title: currentWeekTitle(weekStart: weekStart, weekEnd: weekEnd),
                rows: currentWeek
            ),
            makeSection(kind: .future, title: L10n.tr("due_dates.category_future"), rows: future),
        ]
    }

    private static func clientSummaries(
        from invoices: [ClientInvoiceRow],
        today: Date,
        weekEnd: Date
    ) -> [ClientDueSummary] {
        let openInvoices = invoices.filter(isOpenInvoice)
        let grouped = Dictionary(grouping: openInvoices, by: \.clientId)

        return grouped.compactMap { clientId, clientInvoices in
            let netRest = clientInvoices.reduce(Decimal.zero) { $0 + $1.restDePlata }
            guard netRest > 0 else { return nil }

            let referenceDueDate = earliestPositiveDueDate(in: clientInvoices)
                ?? clientInvoices.map(\.effectiveDueDate).min()

            let daysOverdue: Int?
            let daysUntilDue: Int?

            if let referenceDueDate {
                let dueDay = calendar.startOfDay(for: referenceDueDate)
                let kind = category(forEffectiveDueDate: referenceDueDate, today: today, weekEnd: weekEnd)
                if kind == .overdue {
                    daysOverdue = max(0, calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0)
                    daysUntilDue = nil
                } else {
                    daysOverdue = nil
                    daysUntilDue = max(0, calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0)
                }
            } else {
                daysOverdue = nil
                daysUntilDue = nil
            }

            return ClientDueSummary(
                clientId: clientId,
                clientName: clientInvoices.first?.clientName ?? "—",
                invoiceCount: clientInvoices.count,
                totalAmount: netRest,
                moneda: clientInvoices.first?.moneda ?? "RON",
                daysOverdue: daysOverdue,
                daysUntilDue: daysUntilDue
            )
        }
        .sorted { lhs, rhs in
            lhs.clientName.localizedStandardCompare(rhs.clientName) == .orderedAscending
        }
    }

    private static func referenceDueDate(
        for summary: ClientDueSummary,
        in invoices: [ClientInvoiceRow]
    ) -> Date? {
        let clientInvoices = invoices.filter { $0.clientId == summary.clientId && isOpenInvoice($0) }
        return earliestPositiveDueDate(in: clientInvoices) ?? clientInvoices.map(\.effectiveDueDate).min()
    }

    private static func makeSection(
        kind: DueDateCategoryKind,
        title: String,
        rows: [ClientDueSummary]
    ) -> ClientDueDateCategorySection {
        let categoryTotal = rows.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let moneda = rows.first?.moneda ?? "RON"
        return ClientDueDateCategorySection(
            kind: kind,
            title: title,
            rows: rows,
            categoryTotal: categoryTotal,
            moneda: moneda
        )
    }

    private static func currentWeekTitle(weekStart: Date, weekEnd: Date) -> String {
        L10n.tr(
            "due_dates.category_current_week",
            SupplierFormatting.date(weekStart),
            SupplierFormatting.date(weekEnd)
        )
    }

    private static func startOfWeek(containing date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysFromMonday = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: day) ?? day
    }

    private static func isOpenInvoice(_ invoice: ClientInvoiceRow) -> Bool {
        (invoice.status == .neplatita || invoice.status == .partial) && invoice.restDePlata != 0
    }

    private static func isOpenInvoice(_ invoice: ClientInvoice) -> Bool {
        (invoice.status == .neplatita || invoice.status == .partial) && invoice.restDePlata != 0
    }

    private static func earliestPositiveDueDate(in invoices: [ClientInvoiceRow]) -> Date? {
        invoices
            .filter { $0.restDePlata > 0 }
            .map(\.effectiveDueDate)
            .min()
    }

    private static func earliestPositiveDueDate(in invoices: [ClientInvoice]) -> Date? {
        invoices
            .filter { $0.restDePlata > 0 }
            .map(\.effectiveDueDate)
            .min()
    }

    static func category(
        for invoice: ClientInvoiceRow,
        referenceDate: Date = Date()
    ) -> DueDateCategoryKind? {
        guard isOpenInvoice(invoice) else { return nil }
        let today = calendar.startOfDay(for: referenceDate)
        let weekStart = startOfWeek(containing: today)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        return category(forEffectiveDueDate: invoice.effectiveDueDate, today: today, weekEnd: weekEnd)
    }

    static func category(
        for invoice: ClientInvoice,
        referenceDate: Date = Date()
    ) -> DueDateCategoryKind? {
        guard isOpenInvoice(invoice) else { return nil }
        let today = calendar.startOfDay(for: referenceDate)
        let weekStart = startOfWeek(containing: today)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        return category(forEffectiveDueDate: invoice.effectiveDueDate, today: today, weekEnd: weekEnd)
    }

    private static func category(
        forEffectiveDueDate effectiveDueDate: Date,
        today: Date,
        weekEnd: Date
    ) -> DueDateCategoryKind {
        let dueDay = calendar.startOfDay(for: effectiveDueDate)
        if dueDay < today { return .overdue }
        if dueDay <= weekEnd { return .currentWeek }
        return .future
    }
}
