import SwiftUI

private struct ClientDueDateChartItem: Identifiable {
    let kind: DueDateCategoryKind
    let label: String
    let amount: Decimal
    let color: Color

    var id: String { kind.rawValue }
}

struct ClientDueDatesCategoryChartView: View {
    let sections: [ClientDueDateCategorySection]

    private var currencyCode: String {
        sections.first(where: { $0.categoryTotal > 0 })?.moneda ?? sections.first?.moneda ?? "RON"
    }

    private var items: [ClientDueDateChartItem] {
        sections.map { section in
            ClientDueDateChartItem(
                kind: section.kind,
                label: chartLabel(for: section.kind),
                amount: section.categoryTotal,
                color: chartColor(for: section.kind)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("due_dates.chart_title"))
                .font(.subheadline.bold())

            SimpleDueDatesBarChart(
                items: items.map { ($0.label, $0.amount, $0.color) },
                currencyCode: currencyCode
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.secondarySystemBackground))
    }

    private func chartLabel(for kind: DueDateCategoryKind) -> String {
        switch kind {
        case .overdue: return L10n.tr("due_dates.chart_label_overdue")
        case .currentWeek: return L10n.tr("due_dates.chart_label_current_week")
        case .future: return L10n.tr("due_dates.chart_label_future")
        }
    }

    private func chartColor(for kind: DueDateCategoryKind) -> Color {
        switch kind {
        case .overdue: return .red
        case .currentWeek: return .orange
        case .future: return .blue
        }
    }
}
