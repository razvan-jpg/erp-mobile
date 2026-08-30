import SwiftUI

private enum DueDatesViewMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .list: return L10n.tr("due_dates.view_list")
        case .calendar: return L10n.tr("due_dates.view_calendar")
        }
    }
}

struct DueDatesListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.appBottomBarClearance) private var bottomBarClearance
    @State private var invoices: [SupplierInvoiceRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAccount: SupplierAccountContext?
    @State private var isOpeningAccount = false
    @State private var viewMode: DueDatesViewMode = .calendar

    private var sections: [DueDateCategorySection] {
        DueDatesGrouping.buildSections(from: invoices)
    }

    private var calendarDays: [DueDateCalendarDay] {
        DueDatesCalendarGrouping.buildCalendar(from: invoices)
    }

    private var hasAnyDueDates: Bool {
        sections.contains { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("due_dates.view_mode"), selection: $viewMode) {
                ForEach(DueDatesViewMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                if !hasAnyDueDates && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("due_dates.empty"),
                        systemImage: "calendar.badge.clock",
                        description: Text(L10n.tr("due_dates.empty_hint"))
                    )
                } else {
                    switch viewMode {
                    case .list:
                        dueDatesListContent
                    case .calendar:
                        ScrollView {
                            DueDatesCalendarView(days: calendarDays) { row in
                                openAccount(for: row)
                            }
                            .padding(.vertical, 8)
                        }
                        .appScrollBottomPadding()
                    }
                }
            }
        }
        .appSafeAreaInsetBottom(spacing: 0) {
            VStack(spacing: 0) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .appBarBackground()
                }
                if !isLoading, viewMode == .list {
                    VStack(spacing: 0) {
                        Divider()
                        DueDatesCategoryChartView(sections: sections)
                    }
                    .background(Color(.secondarySystemBackground))
                }
            }
            .padding(.bottom, bottomBarClearance)
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading || isOpeningAccount) }
        .appTask { await loadInvoices() }
        .appRefreshable { await loadInvoices() }
        .fullScreenCover(item: $selectedAccount) { account in
            SupplierAccountView(context: account, access: access) {
                await loadInvoices()
                await onChanged()
            }
        }
    }

    private var dueDatesListContent: some View {
        List {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    DueDateCategoryDividerRow()
                }

                DueDateCategoryHeaderView(section: section)
                    .listRowInsets(EdgeInsets())
                    .appListRowSeparatorHidden()
                    .listRowBackground(section.kind.headerBackgroundColor)

                if section.rows.isEmpty {
                    Text(L10n.tr("due_dates.category_empty"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                        .listRowBackground(Color(.systemBackground))
                } else {
                    ForEach(section.rows) { row in
                        SupplierDueSummaryRowView(
                            row: row,
                            showDaysOverdue: section.kind == .overdue,
                            showDaysUntilDue: section.kind == .currentWeek || section.kind == .future
                        ) {
                            openAccount(for: row, categoryTitle: section.title)
                        }
                    }
                }
            }
        }
        .appScrollBottomPadding()
    }

    private func openAccount(for row: DueDateCalendarSupplierRow) {
        let summary = SupplierDueSummary(
            supplierId: row.supplierId,
            supplierName: row.supplierName,
            invoiceCount: row.invoiceCount,
            totalAmount: row.totalAmount,
            moneda: row.moneda,
            daysOverdue: nil,
            daysUntilDue: nil
        )
        openAccount(for: summary, categoryTitle: L10n.tr("due_dates.view_calendar"))
    }

    private func openAccount(
        for row: SupplierDueSummary,
        categoryTitle: String
    ) {
        Task {
            isOpeningAccount = true
            errorMessage = nil
            do {
                let supplier = try await SupplierService.fetchSupplier(id: row.supplierId)
                let listRow = try await SupplierService.fetchSupplierListRows()
                    .first(where: { $0.supplier.id == row.supplierId })
                    ?? SupplierListRow(
                        supplier: supplier,
                        soldRestant: row.totalAmount,
                        primaScadenta: nil,
                        moneda: row.moneda
                    )
                selectedAccount = SupplierAccountContext(
                    row: listRow,
                    dueDateCategoryTitle: categoryTitle
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isOpeningAccount = false
        }
    }

    private func loadInvoices() async {
        isLoading = true
        errorMessage = nil
        do {
            invoices = try await SupplierService.fetchInvoices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct DueDateCategoryDividerRow: View {
    var body: some View {
        Rectangle()
            .fill(Color(.label).opacity(0.35))
            .frame(height: 4)
            .listRowInsets(EdgeInsets())
            .appListRowSeparatorHidden()
            .listRowBackground(Color(.systemBackground))
    }
}

private struct DueDateCategoryHeaderView: View {
    let section: DueDateCategorySection

    private var titleFont: Font {
        headerFont(for: .headline)
    }

    private var totalFont: Font {
        headerFont(for: .subheadline)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(section.title)
                .font(titleFont)
                .bold()
                .foregroundColor(section.kind.headerForegroundColor)
            Spacer(minLength: 8)
            Text(
                L10n.tr(
                    "due_dates.category_total",
                    SupplierFormatting.currency(section.categoryTotal, code: section.moneda)
                )
            )
            .font(totalFont)
            .bold()
            .foregroundColor(section.kind.headerForegroundColor.opacity(0.95))
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(section.kind.headerBackgroundColor)
    }

    private func headerFont(for textStyle: UIFont.TextStyle) -> Font {
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        return Font(UIFont.systemFont(ofSize: base.pointSize * 1.5, weight: .bold))
    }
}

private struct SupplierDueSummaryRowView: View {
    let row: SupplierDueSummary
    let showDaysOverdue: Bool
    let showDaysUntilDue: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: onTap) {
                    Text(row.supplierName)
                        .font(.headline)
                        .foregroundColor(showDaysOverdue ? .red : .primary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onTap) {
                    Text(SupplierFormatting.currency(row.totalAmount, code: row.moneda))
                        .font(.subheadline.bold())
                        .foregroundColor(showDaysOverdue ? .red : .orange)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Text(L10n.tr("due_dates.invoice_count", row.invoiceCount))
                if showDaysOverdue, let days = row.daysOverdue {
                    Text(L10n.tr("due_dates.days_overdue", days))
                        .foregroundColor(.red)
                }
                if showDaysUntilDue, let days = row.daysUntilDue {
                    Text(L10n.tr("due_dates.days_until_due", days))
                }
            }
            .font(.caption)
            .foregroundColor(AppColors.secondary)
        }
        .padding(.vertical, 2)
    }
}
