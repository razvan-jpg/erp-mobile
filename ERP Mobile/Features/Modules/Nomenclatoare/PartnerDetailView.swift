import SwiftUI

struct PartnerDetailView: View {
    let partner: PartnerListRow
    let supplierAccess: ModuleAccessRights
    let clientAccess: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var showSupplierAccount = false
    @State private var showClientAccount = false
    @State private var showCombinedAccount = false

    private var detail: PartnerDetailData { PartnerDetailData(row: partner) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    identityCard
                    contactCard
                    roleSpecificCards
                    accountActionsCard
                    Color.clear.frame(height: 24)
                }
                .padding()
                .frame(maxWidth: DeviceLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(L10n.tr("partners.detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("partners.back_to_list")) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showSupplierAccount) {
                if let supplierRow = partner.supplierRow {
                    SupplierAccountView(
                        context: SupplierAccountContext(row: supplierRow),
                        access: supplierAccess
                    ) {
                        await onChanged()
                    }
                }
            }
            .fullScreenCover(isPresented: $showClientAccount) {
                if let clientRow = partner.clientRow {
                    ClientAccountView(
                        context: ClientAccountContext(row: clientRow),
                        access: clientAccess
                    ) {
                        await onChanged()
                    }
                }
            }
            .fullScreenCover(isPresented: $showCombinedAccount) {
                PartnerCombinedAccountView(
                    partner: partner,
                    supplierAccess: supplierAccess,
                    clientAccess: clientAccess
                ) {
                    await onChanged()
                }
            }
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(partner.denumire)
                .font(.title2.bold())
            PartnerRoleBadge(role: partner.role)
            if !partner.isActive {
                Text(L10n.tr("partners.inactive_partner"))
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var contactCard: some View {
        infoCard(title: L10n.tr("partners.section_identity"), lines: [
            detailLine(L10n.tr("account.partner_role_label"), partner.role.displayLabel),
            detailLine(L10n.tr("common.cui"), detail.cui),
            detailLine(L10n.tr("common.field_nr_reg_com"), detail.nrRegCom),
            detailLine(L10n.tr("common.field_address"), detail.adresa),
            detailLine(L10n.tr("common.field_iban"), detail.iban),
            detailLine(L10n.tr("common.field_email"), detail.email),
            detailLine(L10n.tr("common.field_phone"), detail.telefon)
        ].compactMap(\.self))
    }

    @ViewBuilder
    private var roleSpecificCards: some View {
        if let supplierRow = partner.supplierRow {
            infoCard(title: L10n.tr("account.supplier_data"), lines: [
                detailLine(
                    L10n.tr("common.field_status"),
                    (detail.supplierIsActive ?? true) ? L10n.tr("common.active") : L10n.tr("common.inactive")
                ),
                supplierRow.supplier.nrZileScadenta > 0
                    ? L10n.tr("suppliers.payment_term_line", supplierRow.supplier.nrZileScadenta)
                    : L10n.tr("suppliers.payment_term_line_zero"),
                detailLine(L10n.tr("suppliers.field_notes"), detail.supplierObservatii)
            ].compactMap(\.self))
        }

        if let clientRow = partner.clientRow {
            infoCard(title: L10n.tr("account.client_data"), lines: [
                detailLine(
                    L10n.tr("common.field_status"),
                    (detail.clientIsActive ?? true) ? L10n.tr("common.active") : L10n.tr("common.inactive")
                ),
                clientRow.client.nrZileScadenta > 0
                    ? L10n.tr("clients.payment_term_line", clientRow.client.nrZileScadenta)
                    : L10n.tr("clients.payment_term_line_zero"),
                detailLine(L10n.tr("clients.field_notes"), detail.clientObservatii)
            ].compactMap(\.self))
        }
    }

    private var accountActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("partners.account_actions_title"))
                .font(.headline)

            switch partner.role {
            case .supplierOnly:
                accountButton(
                    title: L10n.tr("partners.open_supplier_account"),
                    systemImage: "doc.text.fill",
                    enabled: supplierAccess.canView
                ) {
                    showSupplierAccount = true
                }
            case .clientOnly:
                accountButton(
                    title: L10n.tr("partners.open_client_account"),
                    systemImage: "doc.text.fill",
                    enabled: clientAccess.canView
                ) {
                    showClientAccount = true
                }
            case .both:
                accountButton(
                    title: L10n.tr("partners.open_combined_account"),
                    systemImage: "doc.on.doc.fill",
                    enabled: supplierAccess.canView && clientAccess.canView
                ) {
                    showCombinedAccount = true
                }

                if supplierAccess.canView {
                    accountButton(
                        title: L10n.tr("partners.open_supplier_account"),
                        systemImage: "arrow.down.doc.fill",
                        enabled: true,
                        style: .bordered
                    ) {
                        showSupplierAccount = true
                    }
                }

                if clientAccess.canView {
                    accountButton(
                        title: L10n.tr("partners.open_client_account"),
                        systemImage: "arrow.up.doc.fill",
                        enabled: true,
                        style: .bordered
                    ) {
                        showClientAccount = true
                    }
                }
            }

            if !canOpenAnyAccount {
                Text(L10n.tr("partners.account_access_denied"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var canOpenAnyAccount: Bool {
        switch partner.role {
        case .supplierOnly: return supplierAccess.canView
        case .clientOnly: return clientAccess.canView
        case .both: return supplierAccess.canView || clientAccess.canView
        }
    }

    private func accountButton(
        title: String,
        systemImage: String,
        enabled: Bool,
        style: ButtonStyleKind = .prominent,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if style == .prominent {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyles.borderedProminent)
                .disabled(!enabled)
            } else {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyles.bordered)
                .disabled(!enabled)
            }
        }
    }

    private enum ButtonStyleKind {
        case prominent
        case bordered
    }

    private func infoCard(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private func detailLine(_ label: String, _ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return L10n.tr("common.detail_line", label, value)
    }
}
