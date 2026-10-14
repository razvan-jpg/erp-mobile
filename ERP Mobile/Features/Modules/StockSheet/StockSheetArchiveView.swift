import SwiftUI
import UIKit

struct StockSheetArchiveView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var sheets: [ZStockSheetRow] = []
    @State private var locations: [CompanyWorkLocation] = []
    @State private var selectedLocationId: UUID?
    @State private var asOf = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoadingAccess {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !access.canView {
                AppEmptyStateView(
                    L10n.tr("module.stock_sheet.access_restricted"),
                    systemImage: "lock.fill",
                    description: Text(L10n.tr("module.no_access"))
                )
            } else {
                List {
                    Section {
                        Picker(L10n.tr("stock_sheet.filter_location"), selection: $selectedLocationId) {
                            Text(L10n.tr("stock_sheet.filter_location_all")).tag(Optional<UUID>.none)
                            ForEach(locations) { location in
                                Text(location.denumire).tag(Optional(location.id))
                            }
                        }
                        DatePicker(L10n.tr("stock_sheet.filter_date"), selection: $asOf, displayedComponents: .date)
                    }
                    Section {
                        if sheets.isEmpty && !isLoading {
                            Text("Nu există foaie de stoc pentru data aleasă. Foaia se creează la închiderea Raportului Z.")
                                .foregroundColor(AppColors.secondary)
                        }
                        ForEach(sheets) { sheet in
                            NavigationLink {
                                StockSheetArchiveDetailView(
                                    sheet: sheet,
                                    locationName: locations.first { $0.id == sheet.workLocationId }?.denumire ?? ""
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sheet.title)
                                        .font(.body.weight(.semibold))
                                    Text("\(sheet.documentNumber) · \(locations.first { $0.id == sheet.workLocationId }?.denumire ?? "")")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("module.stock_sheet.tile_generate"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask {
            await loadAccess()
            await reload()
        }
        .onChange(of: selectedLocationId) { _, _ in Task { await reload() } }
        .onChange(of: asOf) { _, _ in Task { await reload() } }
        .onChange(of: companyManager.currentCompany?.id) { _, _ in Task { await loadAccess(); await reload() } }
    }

    private func loadAccess() async {
        isLoadingAccess = true
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            access = .none
            isLoadingAccess = false
            return
        }
        do {
            let moduleAccess = try await ModuleAccessRights.load(moduleId: module.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }

    private func reload() async {
        guard access.canView, let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
            sheets = try await StockSheetService.fetchZSheets(
                companyId: companyId,
                locationId: selectedLocationId,
                date: asOf
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct StockSheetArchiveDetailView: View {
    let sheet: ZStockSheetRow
    let locationName: String
    @State private var lines: [ZStockSheetLine] = []
    @State private var errorMessage: String?

    private var sections: [(String, [ZStockSheetLine])] {
        let order = ["finite", "drinks", "materials"]
        return order.compactMap { key in
            let rows = lines.filter { $0.category == key }
            guard let first = rows.first else { return nil }
            return (first.categoryTitle, rows)
        }
    }

    var body: some View {
        List {
            Section {
                Text(sheet.title).font(.headline)
                Text("\(sheet.documentNumber) · \(locationName)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            }
            ForEach(sections, id: \.0) { title, rows in
                Section(title) {
                    ForEach(rows) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(line.nrCrt). \(line.denumire)")
                                .font(.subheadline.weight(.semibold))
                            Text("Inițial \(qty(line.openingQty)) \(line.unitateMasura) · Intrări \(qty(line.inflowQty)) · Final \(qty(line.closingQty))")
                                .font(.caption)
                                .foregroundColor(line.mismatch ? .red : AppColors.secondary)
                            Text("Ieșiri magazin \(qty(line.saleStoreQty)) · online \(qty(line.saleOnlineQty)) · Transfer \(qty(line.transferOutQty))")
                                .font(.caption)
                            Text("Preț \(money(line.priceStore)) / \(money(line.priceOnline)) · Valoare \(money(line.valueStore)) / \(money(line.valueOnline)) · Profit \(money(line.profit))")
                                .font(.caption)
                            if line.recipeOutQty > 0 {
                                Text("Consum rețetă \(qty(line.recipeOutQty))")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                        }
                    }
                }
            }
            Section("Tură") {
                Text("Glovo \(money(sheet.glovo))")
                Text("Bolt \(money(sheet.bolt))")
                Text("Wolt \(money(sheet.wolt))")
            }
            Section("Raport Z") {
                Text("Z = \(sheet.zNumber.isEmpty ? "—" : sheet.zNumber)")
                Text("Total vânzare = \(money(sheet.totalVanzare))")
                Text("Plată card = \(money(sheet.plataCard))")
                Text("Plată modernă = \(money(sheet.plataModerna))")
                Text("Numerar = \(money(sheet.numerar))")
                Text("Bani predați = \(money(sheet.baniPredati))")
            }
            if let errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
        }
        .navigationTitle(sheet.documentNumber)
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await load() }
    }

    private func load() async {
        do {
            lines = try await StockSheetService.fetchZSheetLines(sheetId: sheet.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func qty(_ value: Decimal) -> String {
        SupplierFormatting.stockQuantityString(value)
    }

    private func money(_ value: Decimal) -> String {
        SupplierFormatting.currency(value)
    }
}
