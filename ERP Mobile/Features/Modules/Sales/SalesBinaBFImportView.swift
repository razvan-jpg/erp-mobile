import SwiftUI

/// Preluare / pregătire bonuri fiscale legate de Rapoartele Z (pas înainte de conectorul BINA BF complet).
struct SalesBinaBFImportView: View {
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var isWorking = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 560) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)

                Text(L10n.tr("module.sales.tab_bina_bf"))
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)

                Text(L10n.tr("module.sales.bina_bf_intro"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button {
                    Task { await seedReceiptsFromZDocuments() }
                } label: {
                    Label(
                        L10n.tr("module.sales.bina_bf_seed_from_z"),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || companyManager.currentCompany == nil)

                Text(L10n.tr("module.sales.bina_bf_seed_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .appFullOverlay { LoadingOverlay(isLoading: isWorking) }
    }

    /// Pentru fiecare Z cu „Documente” > 0 și fără suficiente bonuri legate, creează sloturi (nr. secvențial).
    private func seedReceiptsFromZDocuments() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isWorking = true
        message = nil
        errorMessage = nil
        defer { isWorking = false }

        do {
            let locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
            let activeLocations = locations.filter(\.isActive)
            let reports = try await ClientZReportService.fetchReports(companyId: companyId)
            let existing = try await FiscalSaleReceiptService.fetchReceipts(companyId: companyId)
            let existingByZ = Dictionary(
                grouping: existing.filter { $0.closingZReportId != nil },
                by: { $0.closingZReportId! }
            )

            var created = 0
            for report in reports {
                let visual = ZettaModelZReportFormatter.visualModel(for: report.reportData)
                let trimmedDocs = visual.documents.trimmingCharacters(in: .whitespacesAndNewlines)
                let digits = trimmedDocs.filter(\.isNumber)
                let target = Int(digits.isEmpty ? trimmedDocs : String(digits)) ?? 0
                guard target > 0 else { continue }

                let already = existingByZ[report.id]?.count ?? 0
                let missing = target - already
                guard missing > 0 else { continue }

                let locationId = FiscalSaleReceiptService.resolvedLocationId(
                    for: report,
                    locations: activeLocations
                )
                let saleDate = report.accountingDate
                let issuedBase = report.payload.printDateTime ?? report.reportDate

                for index in 0..<missing {
                    let seq = already + index + 1
                    let issued = Calendar.current.date(byAdding: .minute, value: -index, to: issuedBase) ?? issuedBase
                    let insert = FiscalSaleReceiptInsert(
                        id: UUID(),
                        companyId: companyId,
                        workLocationId: locationId,
                        saleDate: SupabaseDecoding.dateOnlyString(from: saleDate),
                        issuedAt: issued,
                        receiptNumber: "Z\(report.zNumber)-\(seq)",
                        totalAmount: "0",
                        numerar: "0",
                        card: "0",
                        plataModerna: "0",
                        closingZReportId: report.id,
                        source: FiscalSaleReceiptSource.binaImport.rawValue,
                        clientLabel: L10n.tr("module.sales.cash_sale.client_implicit"),
                        notes: L10n.tr("module.sales.bina_bf_seed_note", report.zNumber, seq)
                    )
                    _ = try await FiscalSaleReceiptService.upsertReceipt(insert)
                    created += 1
                }
            }

            message = created == 0
                ? L10n.tr("module.sales.bina_bf_seed_none")
                : L10n.tr("module.sales.bina_bf_seed_done", created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
