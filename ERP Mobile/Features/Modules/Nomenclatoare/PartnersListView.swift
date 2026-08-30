import SwiftUI

struct PartnersListView: View {
    let supplierAccess: ModuleAccessRights
    let clientAccess: ModuleAccessRights
    let onChanged: () async -> Void

    @State private var partnerRows: [PartnerListRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPartner: PartnerListRow?
    @State private var searchText = ""

    private var filteredPartnerRows: [PartnerListRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return partnerRows }
        return partnerRows.filter {
            $0.denumire.localizedCaseInsensitiveContains(query)
                || ($0.cui?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        Group {
            if filteredPartnerRows.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("partners.empty"),
                    systemImage: "person.2",
                    description: Text(L10n.tr("partners.empty_hint"))
                )
            } else {
                List {
                    ForEach(filteredPartnerRows) { row in
                        PartnerRowView(row: row) {
                            selectedPartner = row
                        }
                    }
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("partners.search_prompt"))
                .appScrollBottomPadding()
            }
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
        .appTask { await loadPartners() }
        .appRefreshable { await loadPartners() }
        .fullScreenCover(item: $selectedPartner) { partner in
            PartnerDetailView(
                partner: partner,
                supplierAccess: supplierAccess,
                clientAccess: clientAccess
            ) {
                await loadPartners()
                await onChanged()
            }
        }
    }

    private func loadPartners() async {
        isLoading = true
        errorMessage = nil
        do {
            partnerRows = try await PartnerService.fetchPartnerListRows()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct PartnerRowView: View {
    let row: PartnerListRow
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.denumire)
                            .font(.headline)
                            .foregroundColor(AppColors.primary)
                        if !row.isActive {
                            Text(L10n.tr("common.inactive"))
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    PartnerRoleBadge(role: row.role)
                    if let cui = row.cui, !cui.isEmpty {
                        Text(L10n.tr("common.cui_label", cui))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    if let telefon = row.telefon, !telefon.isEmpty {
                        Text(L10n.tr("common.phone_label", telefon))
                            .font(.caption)
                            .foregroundColor(AppColors.tertiary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    if row.role == .both {
                        Text(SupplierFormatting.currency(row.netSold, code: row.displayMoneda))
                            .font(.subheadline.bold())
                            .foregroundColor(row.netSold != 0 ? Color.orange : Color.secondary)
                        Text(L10n.tr("partners.net_balance_label"))
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiary)
                    } else {
                        Text(SupplierFormatting.currency(row.netSold, code: row.displayMoneda))
                            .font(.subheadline.bold())
                            .foregroundColor(row.netSold > 0 ? Color.orange : Color.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
