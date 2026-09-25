import SwiftUI

struct HRTimesheetView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var period = HRMonthPeriod.current()
    @State private var run: HRPayrollRun?
    @State private var drafts: [HRPayrollLineDraft] = []
    @State private var days: [HRTimesheetDay] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var groupedDays: [UUID: [HRTimesheetDay]] {
        Dictionary(grouping: days, by: \.employeeId)
    }

    var body: some View {
        Group {
            if run == nil && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.hr.timesheet_no_payroll"),
                    systemImage: "calendar.badge.clock",
                    description: Text(L10n.tr("module.hr.timesheet_no_payroll_hint"))
                )
            } else if days.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.hr.timesheet_empty"),
                    systemImage: "calendar.badge.clock",
                    description: Text(L10n.tr("module.hr.timesheet_empty_hint"))
                )
            } else {
                List {
                    ForEach(drafts) { draft in
                        NavigationLink {
                            HRTimesheetEmployeeView(
                                draft: draft,
                                days: groupedDays[draft.line.employeeId] ?? []
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(draft.employeeName)
                                    .font(.headline)
                                Text(summary(for: draft.line.employeeId))
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                if let error = draft.line.timesheetError, !error.isEmpty {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("module.hr.tile_timesheet"))
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                HRPeriodPicker(period: $period)
                if access.canCreate || access.canEdit {
                    Button(L10n.tr("module.hr.generate_timesheet")) {
                        Task { await generate() }
                    }
                    .disabled(run == nil || run?.isClosed == true || isLoading)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .appBarBackground()
        }
        .appSafeAreaInsetBottom {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask(id: "\(companyManager.currentCompany?.id.uuidString ?? "")-\(period.year)-\(period.month)") {
            await load()
        }
        .onChange(of: period) { _ in
            Task { await load() }
        }
    }

    private func summary(for employeeId: UUID) -> String {
        let items = groupedDays[employeeId] ?? []
        let work = items.filter { $0.kind == .work }.count
        let rest = items.filter { $0.kind == .rest }.count
        return L10n.tr("module.hr.timesheet_summary", "\(work)", "\(rest)")
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            run = nil
            drafts = []
            days = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let employees = HRPersonnelService.fetchEmployees(companyId: companyId)
            async let contracts = HRPersonnelService.fetchContracts(companyId: companyId)
            async let locations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            if let existing = try await HRPersonnelService.fetchRun(companyId: companyId, period: period) {
                run = existing
                let lines = try await HRPersonnelService.fetchLines(runId: existing.id)
                drafts = HRPersonnelService.drafts(
                    lines: lines,
                    employees: try await employees,
                    contracts: try await contracts,
                    locations: try await locations
                )
                days = try await HRPersonnelService.fetchTimesheet(runId: existing.id)
            } else {
                run = nil
                drafts = []
                days = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generate() async {
        guard let run, let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let settings = try await HRPersonnelService.fetchSettings(companyId: companyId)
            try await HRPersonnelService.generateTimesheet(run: run, drafts: drafts, settings: settings)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct HRTimesheetEmployeeView: View {
    let draft: HRPayrollLineDraft
    let days: [HRTimesheetDay]

    var body: some View {
        List {
            ForEach(days.sorted { $0.workDate < $1.workDate }) { day in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SupplierFormatting.date(day.workDate))
                            .font(.headline)
                        Text(L10n.tr(day.kind.labelKey))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Spacer()
                    if day.kind == .work || day.kind == .co || day.kind == .cm {
                        Text("\(day.startTime ?? "—") – \(day.endTime ?? "—")")
                            .font(.subheadline)
                        Text(SupplierFormatting.amountString(day.hours))
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .navigationTitle(draft.employeeName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
