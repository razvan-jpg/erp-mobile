import SwiftUI

enum AccountLedgerPeriodFilter: CaseIterable, Identifiable {
    case thisMonth
    case last7Days
    case last3Days
    case customRange
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .thisMonth: return L10n.tr("account.period_this_month")
        case .last7Days: return L10n.tr("account.period_last_7_days")
        case .last3Days: return L10n.tr("account.period_last_3_days")
        case .customRange: return L10n.tr("account.period_custom")
        case .all: return L10n.tr("account.period_all")
        }
    }

    func includes(documentDate: Date, customFrom: Date, customTo: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: documentDate)
        let today = calendar.startOfDay(for: Date())

        switch self {
        case .thisMonth:
            return calendar.isDate(day, equalTo: today, toGranularity: .month)
        case .last7Days:
            guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return false }
            return day >= start && day <= today
        case .last3Days:
            guard let start = calendar.date(byAdding: .day, value: -2, to: today) else { return false }
            return day >= start && day <= today
        case .customRange:
            let from = calendar.startOfDay(for: min(customFrom, customTo))
            let to = calendar.startOfDay(for: max(customFrom, customTo))
            return day >= from && day <= to
        case .all:
            return true
        }
    }
}

struct AccountLedgerPeriodFilterBar: View {
    @Binding var periodFilter: AccountLedgerPeriodFilter
    @Binding var openOnlyFilter: Bool
    @Binding var customDateFrom: Date
    @Binding var customDateTo: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterCapsule(
                        label: L10n.tr("account.filter_open_only"),
                        isSelected: openOnlyFilter
                    ) {
                        openOnlyFilter = true
                    }

                    filterCapsule(
                        label: L10n.tr("account.filter_all_invoices"),
                        isSelected: !openOnlyFilter
                    ) {
                        openOnlyFilter = false
                    }

                    Divider()
                        .frame(height: 24)

                    ForEach(AccountLedgerPeriodFilter.allCases) { filter in
                        filterCapsule(
                            label: filter.label,
                            isSelected: periodFilter == filter
                        ) {
                            periodFilter = filter
                        }
                    }
                }
            }

            if periodFilter == .customRange {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("account.period_from_date"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        AppDatePicker(selection: $customDateFrom)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("account.period_to_date"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        AppDatePicker(selection: $customDateTo)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private func filterCapsule(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}
