import SwiftUI

struct CompanyPermissionsEditorView: View {
    let companies: [Company]
    @Binding var companyAccess: [UUID: CompanyAccessLevel]

    var body: some View {
        if companies.isEmpty {
            Text(L10n.tr("admin.no_companies_defined"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        } else {
            ForEach(companies) { company in
                VStack(alignment: .leading, spacing: 8) {
                    Text(company.denumire)
                        .font(.subheadline.bold())
                    if let cui = company.cui, !cui.isEmpty {
                        Text(L10n.tr("common.cui_label", cui))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Picker(L10n.tr("admin.company_access_picker"), selection: accessBinding(for: company.id)) {
                        ForEach(CompanyAccessLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func accessBinding(for companyId: UUID) -> Binding<CompanyAccessLevel> {
        Binding(
            get: { companyAccess[companyId] ?? .noAccess },
            set: { companyAccess[companyId] = $0 }
        )
    }
}
