import Foundation

struct SupplierDueSummary: Identifiable, Sendable {
    let supplierId: UUID
    let supplierName: String
    let invoiceCount: Int
    let totalAmount: Decimal
    let moneda: String
    let daysOverdue: Int?
    let daysUntilDue: Int?

    var id: UUID { supplierId }
}

struct DueDateCategorySection: Identifiable, Sendable {
    let kind: DueDateCategoryKind
    let title: String
    let rows: [SupplierDueSummary]
    let categoryTotal: Decimal
    let moneda: String

    var id: String { kind.rawValue }

    var isEmpty: Bool { rows.isEmpty }
}

@MainActor
enum DueDatesGrouping {
    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    static func buildSections(from invoices: [SupplierInvoiceRow]) -> [DueDateCategorySection] {
        let today = calendar.startOfDay(for: Date())
        let weekStart = startOfWeek(containing: today)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today

        let summaries = supplierSummaries(from: invoices, today: today, weekEnd: weekEnd)

        var overdue: [SupplierDueSummary] = []
        var currentWeek: [SupplierDueSummary] = []
        var future: [SupplierDueSummary] = []

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

    private static func supplierSummaries(
        from invoices: [SupplierInvoiceRow],
        today: Date,
        weekEnd: Date
    ) -> [SupplierDueSummary] {
        let openInvoices = invoices.filter(isOpenInvoice)
        let grouped = Dictionary(grouping: openInvoices, by: \.supplierId)

        return grouped.compactMap { supplierId, supplierInvoices in
            let netRest = supplierInvoices.reduce(Decimal.zero) { $0 + $1.restDePlata }
            guard netRest > 0 else { return nil }

            let referenceDueDate = earliestPositiveDueDate(in: supplierInvoices)
                ?? supplierInvoices.map(\.effectiveDueDate).min()

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

            return SupplierDueSummary(
                supplierId: supplierId,
                supplierName: supplierInvoices.first?.supplierName ?? "—",
                invoiceCount: supplierInvoices.count,
                totalAmount: netRest,
                moneda: supplierInvoices.first?.moneda ?? "RON",
                daysOverdue: daysOverdue,
                daysUntilDue: daysUntilDue
            )
        }
        .sorted { lhs, rhs in
            lhs.supplierName.localizedStandardCompare(rhs.supplierName) == .orderedAscending
        }
    }

    private static func referenceDueDate(
        for summary: SupplierDueSummary,
        in invoices: [SupplierInvoiceRow]
    ) -> Date? {
        let supplierInvoices = invoices.filter { $0.supplierId == summary.supplierId && isOpenInvoice($0) }
        return earliestPositiveDueDate(in: supplierInvoices) ?? supplierInvoices.map(\.effectiveDueDate).min()
    }

    private static func makeSection(
        kind: DueDateCategoryKind,
        title: String,
        rows: [SupplierDueSummary]
    ) -> DueDateCategorySection {
        let categoryTotal = rows.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let moneda = rows.first?.moneda ?? "RON"
        return DueDateCategorySection(
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

    private static func isOpenInvoice(_ invoice: SupplierInvoiceRow) -> Bool {
        (invoice.status == .neplatita || invoice.status == .partial) && invoice.restDePlata != 0
    }

    private static func isOpenInvoice(_ invoice: SupplierInvoice) -> Bool {
        (invoice.status == .neplatita || invoice.status == .partial) && invoice.restDePlata != 0
    }

    private static func earliestPositiveDueDate(in invoices: [SupplierInvoiceRow]) -> Date? {
        invoices
            .filter { $0.restDePlata > 0 }
            .map(\.effectiveDueDate)
            .min()
    }

    private static func earliestPositiveDueDate(in invoices: [SupplierInvoice]) -> Date? {
        invoices
            .filter { $0.restDePlata > 0 }
            .map(\.effectiveDueDate)
            .min()
    }

    static func category(
        for invoice: SupplierInvoiceRow,
        referenceDate: Date = Date()
    ) -> DueDateCategoryKind? {
        guard isOpenInvoice(invoice) else { return nil }
        let today = calendar.startOfDay(for: referenceDate)
        let weekStart = startOfWeek(containing: today)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        return category(forEffectiveDueDate: invoice.effectiveDueDate, today: today, weekEnd: weekEnd)
    }

    static func category(
        for invoice: SupplierInvoice,
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
