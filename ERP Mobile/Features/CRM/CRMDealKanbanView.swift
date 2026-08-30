import SwiftUI

struct CRMDealKanbanView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var leads: [CRMLead] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLead: CRMLead?
    @State private var quickCreateStage: CRMLeadStage?
    @State private var searchText = ""
    @State private var showMyOnly = false

    private var filteredLeads: [CRMLead] {
        var items = leads
        if showMyOnly, let uid = session.currentProfile?.id {
            items = items.filter { $0.assignedTo == uid }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || ($0.organizationName ?? "").localizedCaseInsensitiveContains(query)
                || ($0.contactName ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(L10n.tr("crm.show_my_items_only"), isOn: $showMyOnly)
                .padding(.horizontal)
                .padding(.top, 8)
            if !leads.isEmpty {
                pipelineSummaryBar
            }

            Group {
                if filteredLeads.isEmpty && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("crm.no_deals"),
                        systemImage: "rectangle.grid.3x2",
                        description: Text(access.canCreate ? L10n.tr("crm.no_deals_create") : L10n.tr("crm.no_deals_readonly"))
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(CRMLeadStage.kanbanOrder) { stage in
                                kanbanColumn(stage: stage, items: filteredLeads.filter { $0.stage == stage })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .appSearchable(text: $searchText, prompt: L10n.tr("crm.search_deals"))
        .crmErrorFooter(errorMessage)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .crmLeadsDidChange)) { _ in
            Task { await reload() }
        }
        .fullScreenCover(item: $selectedLead) { lead in
            CRMDealDetailView(lead: lead, access: access) {
                await reload()
            }
        }
        .sheet(item: $quickCreateStage) { stage in
            CRMDealFormView(access: access, presetStage: stage) {
                await reload()
            }
        }
    }

    private var pipelineSummaryBar: some View {
        let summary = CRMLeadService.buildDealSummary(leads: filteredLeads)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CRMDealMetricPill(title: L10n.tr("crm.metric.weighted_pipeline"), value: SupplierFormatting.currency(summary.weightedPipeline))
                CRMDealMetricPill(title: L10n.tr("crm.metric.pipeline_value"), value: SupplierFormatting.currency(summary.pipelineValue))
                CRMDealMetricPill(title: L10n.tr("crm.metric.open_deals"), value: "\(summary.openCount)")
                CRMDealMetricPill(title: L10n.tr("crm.metric.won_deals"), value: "\(summary.wonCount)")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func kanbanColumn(stage: CRMLeadStage, items: [CRMLead]) -> some View {
        let total = items.reduce(Decimal(0)) { $0 + $1.estimatedValue }
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.label)
                    .font(.subheadline.weight(.semibold))
                Text(L10n.tr("crm.kanban_column_summary", items.count, SupplierFormatting.currency(total)))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(CRMDealStageColors.background(for: stage))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if access.canCreate {
                Button {
                    quickCreateStage = stage
                } label: {
                    Label(L10n.tr("crm.quick_deal"), systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { lead in
                        CRMDealKanbanCard(lead: lead, access: access) {
                            selectedLead = lead
                        } moveTo: { newStage in
                            Task { await moveLead(lead, to: newStage) }
                        }
                    }
                }
            }
        }
        .frame(width: 272)
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            leads = try await CRMLeadService.fetchLeads(pipelineType: .deal)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveLead(_ lead: CRMLead, to stage: CRMLeadStage) async {
        guard access.canEdit else { return }
        errorMessage = nil
        do {
            _ = try await CRMLeadService.updateLeadStage(id: lead.id, to: stage)
            NotificationCenter.default.post(name: .crmLeadsDidChange, object: nil)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CRMDealKanbanCard: View {
    let lead: CRMLead
    let access: ModuleAccessRights
    let onOpen: () -> Void
    let moveTo: (CRMLeadStage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lead.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            if !lead.displaySubtitle.isEmpty {
                Text(lead.displaySubtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(2)
            }
            HStack {
                Text(SupplierFormatting.currency(lead.estimatedValue, code: lead.currency))
                    .font(.caption.bold())
                Spacer()
                Text("\(lead.probability)%")
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
            }
            if let closeDate = lead.expectedCloseDate {
                Text(SupplierFormatting.date(closeDate))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button(L10n.tr("crm.action_open_deal"), action: onOpen)
            if access.canEdit {
                Menu(L10n.tr("crm.action_move_stage")) {
                    ForEach(CRMLeadStage.kanbanOrder) { stage in
                        if stage != lead.stage {
                            Button(stage.label) { moveTo(stage) }
                        }
                    }
                }
            }
        }
    }
}

private struct CRMDealMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }
}

enum CRMDealStageColors {
    static func background(for stage: CRMLeadStage) -> Color {
        switch stage {
        case .new: return Color.blue.opacity(0.15)
        case .contacted: return Color.cyan.opacity(0.15)
        case .qualified: return Color.purple.opacity(0.15)
        case .proposal: return Color.orange.opacity(0.15)
        case .negotiation: return Color.yellow.opacity(0.2)
        case .won: return Color.green.opacity(0.15)
        case .lost: return Color.red.opacity(0.12)
        }
    }

    static func foreground(for stage: CRMLeadStage) -> Color {
        switch stage {
        case .new: return .blue
        case .contacted: return .cyan
        case .qualified: return .purple
        case .proposal: return .orange
        case .negotiation: return .yellow
        case .won: return .green
        case .lost: return .red
        }
    }
}