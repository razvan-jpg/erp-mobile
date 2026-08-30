import SwiftUI

struct CRMOverviewView: View {
    let access: ModuleAccessRights

    @State private var ticketSummary = CRMTicketSummary()
    @State private var dealSummary = CRMDealSummary()
    @State private var recentTickets: [CRMTicket] = []
    @State private var recentDeals: [CRMLead] = []
    @State private var clientNames: [UUID: String] = [:]
    @State private var selectedTicket: CRMTicket?
    @State private var selectedDeal: CRMLead?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    CRMMetricCard(title: L10n.tr("crm.metric.weighted_pipeline"), value: SupplierFormatting.currency(dealSummary.weightedPipeline), color: .indigo)
                    CRMMetricCard(title: L10n.tr("crm.metric.pipeline_value"), value: SupplierFormatting.currency(dealSummary.pipelineValue), color: .blue)
                    CRMMetricCard(title: L10n.tr("crm.metric.open_deals"), value: "\(dealSummary.openCount)", color: .orange)
                    CRMMetricCard(title: L10n.tr("crm.metric.won_deals"), value: "\(dealSummary.wonCount)", color: .green)
                    CRMMetricCard(title: L10n.tr("crm.metric.active_tickets_label"), value: "\(ticketSummary.activeCount)", color: .purple)
                }

                if dealSummary.openCount > 0 {
                    CRMInfoBanner(
                        text: L10n.tr("crm.metric.open_deals_banner", dealSummary.openCount),
                        color: .blue,
                        icon: "rectangle.grid.3x2.fill"
                    )
                }

                if ticketSummary.activeCount > 0 {
                    CRMInfoBanner(
                        text: L10n.tr("crm.metric.active_tickets", ticketSummary.activeCount),
                        color: .purple,
                        icon: "ticket.fill"
                    )
                }

                sectionHeader(L10n.tr("crm.recent_deals"))
                if recentDeals.isEmpty {
                    Text(L10n.tr("crm.no_deals"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                } else {
                    ForEach(recentDeals.prefix(6)) { deal in
                        Button {
                            selectedDeal = deal
                        } label: {
                            CRMDealOverviewRow(deal: deal)
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionHeader(L10n.tr("crm.recent_tickets"))
                if recentTickets.isEmpty {
                    Text(L10n.tr("crm.no_tickets"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                } else {
                    ForEach(recentTickets.prefix(8)) { ticket in
                        Button {
                            selectedTicket = ticket
                        } label: {
                            CRMTicketOverviewRow(ticket: ticket, clientName: clientNames[ticket.clientId])
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .frame(maxWidth: DeviceLayout.contentMaxWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .appScrollBottomPadding()
        .crmErrorFooter(errorMessage)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .fullScreenCover(item: $selectedTicket) { ticket in
            CRMTicketDetailView(ticket: ticket, access: access, clientName: clientNames[ticket.clientId]) {
                await reload()
            }
        }
        .fullScreenCover(item: $selectedDeal) { deal in
            CRMDealDetailView(lead: deal, access: access) {
                await reload()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            async let ticketsTask = CRMService.fetchTickets()
            async let leadsTask = CRMLeadService.fetchLeads(pipelineType: .deal)
            let tickets = try await ticketsTask
            let leads = try await leadsTask
            ticketSummary = CRMService.buildTicketSummary(tickets: tickets)
            dealSummary = CRMLeadService.buildDealSummary(leads: leads)
            recentTickets = tickets.filter { !$0.status.isClosed }
            recentDeals = leads.filter { !$0.stage.isClosed }
            let clients = try await ClientService.fetchClients()
            clientNames = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.denumire) })
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CRMMetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CRMTicketOverviewRow: View {
    let ticket: CRMTicket
    let clientName: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.ticketNumber)
                    .font(.caption.bold())
                    .foregroundColor(AppColors.secondary)
                Text(ticket.subject)
                    .font(.subheadline.weight(.semibold))
                if let clientName {
                    Text(clientName)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            Spacer()
            Text(ticket.status.label)
                .font(.caption.bold())
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

private struct CRMDealOverviewRow: View {
    let deal: CRMLead

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(deal.title)
                    .font(.subheadline.weight(.semibold))
                Text(deal.stage.label)
                    .font(.caption)
                    .foregroundColor(CRMDealStageColors.foreground(for: deal.stage))
            }
            Spacer()
            Text(SupplierFormatting.currency(deal.estimatedValue, code: deal.currency))
                .font(.caption.bold())
        }
        .padding(.vertical, 4)
    }
}
