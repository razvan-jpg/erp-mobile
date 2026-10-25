import SwiftUI
import UIKit
import Supabase

/// Listare de stoc la momentul deschiderii: toate articolele active, fara Garantie SGR,
/// cu stocul pe gestiuni. Filtrele nu reincarca datele.
struct StockListingView: View {
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var snapshot: StockListingSnapshot?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var locationId: UUID?
    @State private var selectedKinds: Set<ProductKind> = []
    @State private var selectedGroupIds: Set<UUID> = []
    @State private var fromDate = WarehouseCardPeriod.startOfMonth()
    @State private var toDate = Date()
    @State private var shift = 0
    @State private var showCategories = false
    @State private var showGroups = false
    @State private var showPrintSheet = false
    @State private var showExportShare = false
    @State private var exportShareItems: [Any] = []
    @State private var pdfURL: URL?
    @State private var showCard = false
    @State private var cardPack: WarehouseCardPack?

    private var sections: [StockListingSection] {
        guard let snapshot else { return [] }
        return snapshot.sections(
            locationId: locationId,
            kinds: selectedKinds,
            groupIds: selectedGroupIds
        )
    }

    private var articleCount: Int {
        sections.reduce(0) { $0 + $1.lines.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            ListingsBackButton()
            filters
            columnHeader
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L10n.tr("listings.tile_stocks"))
        .navigationBarTitleDisplayMode(.inline)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
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
        .appTask { await load() }
        .sheet(isPresented: $showPrintSheet) {
            if let pdfURL, let data = try? Data(contentsOf: pdfURL) {
                PrintDocumentView(
                    pdfData: data,
                    jobName: L10n.tr("listings.stock_print_job"),
                    onFinish: { showPrintSheet = false }
                )
            }
        }
        .sheet(isPresented: $showExportShare) {
            ActivityShareSheet(
                items: exportShareItems,
                excludedActivityTypes: nil,
                onFinish: { showExportShare = false }
            )
        }
        .background(
            ProgrammaticNavigationLink(isActive: $showCard) {
                if let cardPack {
                    WarehouseCardResultView(pack: cardPack)
                } else {
                    EmptyView()
                }
            }
        )
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                Menu {
                    Button(L10n.tr("listings.stock_all_company")) { locationId = nil }
                    if let snapshot {
                        ForEach(snapshot.locations) { location in
                            Button(location.name) { locationId = location.id }
                        }
                    }
                } label: {
                    chip(locationTitle, systemImage: "mappin.and.ellipse")
                }
                Button { showCategories = true } label: {
                    chip(categoryTitle, systemImage: "square.grid.2x2")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCategories) {
                    kindPicker
                }
                Button { showGroups = true } label: {
                    chip(groupTitle, systemImage: "rectangle.3.group")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showGroups) {
                    groupPicker
                }
                Text(L10n.tr("listings.card_from"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                AppDatePicker(selection: $fromDate)
                Text(L10n.tr("listings.card_to"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                AppDatePicker(selection: $toDate)
                Picker(L10n.tr("listings.shift"), selection: $shift) {
                    Text(L10n.tr("listings.shift_all")).tag(0)
                    Text(L10n.tr("listings.shift_1")).tag(1)
                    Text(L10n.tr("listings.shift_2")).tag(2)
                }
                .pickerStyle(.menu)
                }
            }
            HStack(spacing: 12) {
                Button {
                    Task { await exportPDF() }
                } label: {
                    PdfActionLabel(title: L10n.tr("account.export_pdf"), saves: true)
                }
                .disabled(sections.isEmpty || isLoading)
                Button {
                    Task { await printPDF() }
                } label: {
                    Label(L10n.tr("account.print"), systemImage: "printer.fill")
                }
                .disabled(sections.isEmpty || isLoading)
                Spacer()
                if let snapshot {
                    Text(L10n.tr("listings.stock_moment", snapshot.stamp, articleCount) + " · " + periodCaption)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text(L10n.tr("listings.stock_col_nr")).frame(width: 36, alignment: .trailing)
            Text(L10n.tr("listings.stock_col_code")).frame(minWidth: 0, maxWidth: 120, alignment: .leading)
            Text(L10n.tr("listings.stock_col_name")).frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text(L10n.tr("listings.stock_col_unit")).frame(width: 56, alignment: .leading).layoutPriority(2)
            Text(L10n.tr("listings.stock_col_qty")).frame(width: 112, alignment: .trailing).layoutPriority(2)
            Text(L10n.tr("listings.stock_col_factual")).frame(width: 100, alignment: .trailing).layoutPriority(2)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(AppColors.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var list: some View {
        if sections.isEmpty && !isLoading {
            AppEmptyStateView(
                L10n.tr("listings.stock_empty"),
                systemImage: "shippingbox",
                description: Text(L10n.tr("listings.stock_empty_hint"))
            )
        } else {
            List {
                ForEach(sections) { section in
                    Section(header: Text("\(section.title) (\(section.lines.count))")) {
                        ForEach(section.lines) { line in
                            Button {
                                Task { await openCard(productId: line.id) }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("\(line.number)")
                                        .frame(width: 36, alignment: .trailing)
                                        .foregroundColor(AppColors.secondary)
                                    Text(line.code)
                                        .lineLimit(1)
                                        .frame(minWidth: 0, maxWidth: 120, alignment: .leading)
                                    Text(line.name)
                                        .lineLimit(2)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    Text(line.unit)
                                        .lineLimit(1)
                                        .frame(width: 56, alignment: .leading)
                                        .layoutPriority(2)
                                        .foregroundColor(AppColors.secondary)
                                    Text(SupplierFormatting.stockQuantityString(line.quantity))
                                        .lineLimit(1)
                                        .frame(width: 112, alignment: .trailing)
                                        .layoutPriority(2)
                                        .font(.body.monospacedDigit())
                                        .foregroundColor(line.quantity < 0 ? .red : AppColors.primary)
                                    Text("")
                                        .frame(width: 100, alignment: .trailing)
                                        .layoutPriority(2)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.tertiary)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(L10n.tr("listings.stock_all_categories")) {
                selectedKinds = []
            }
            .padding()
            List(StockListingCatalog.kinds, id: \.self) { kind in
                Button {
                    toggleKind(kind)
                } label: {
                    HStack {
                        Text(kind.label)
                            .foregroundColor(AppColors.primary)
                        Spacer()
                        if selectedKinds.isEmpty || selectedKinds.contains(kind) {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 280, minHeight: 360)
    }

    private var groupPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(L10n.tr("listings.stock_all_groups")) {
                selectedGroupIds = []
            }
            .padding()
            List(snapshot?.groups ?? []) { group in
                Button {
                    toggleGroup(group.id)
                } label: {
                    HStack {
                        Text(group.name)
                            .foregroundColor(AppColors.primary)
                        Spacer()
                        if selectedGroupIds.isEmpty || selectedGroupIds.contains(group.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 280, minHeight: 360)
    }

    private func chip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
    }

    private var locationTitle: String {
        guard let locationId, let name = snapshot?.locations.first(where: { $0.id == locationId })?.name else {
            return L10n.tr("listings.stock_all_company")
        }
        return name
    }

    private var categoryTitle: String {
        if selectedKinds.isEmpty { return L10n.tr("listings.stock_all_categories") }
        if selectedKinds.count == 1, let kind = selectedKinds.first { return kind.label }
        return L10n.tr("listings.stock_categories_count", selectedKinds.count)
    }

    private var groupTitle: String {
        guard let snapshot else { return L10n.tr("listings.stock_all_groups") }
        let names = snapshot.groups.filter { selectedGroupIds.contains($0.id) }.map(\.name)
        if names.isEmpty { return L10n.tr("listings.stock_all_groups") }
        if names.count == 1 { return names[0] }
        return L10n.tr("listings.stock_groups_count", names.count)
    }

    private func toggleKind(_ kind: ProductKind) {
        if selectedKinds.isEmpty {
            selectedKinds = [kind]
            return
        }
        if selectedKinds.contains(kind) {
            selectedKinds.remove(kind)
        } else {
            selectedKinds.insert(kind)
        }
        if selectedKinds.count == StockListingCatalog.kinds.count {
            selectedKinds = []
        }
    }

    private func toggleGroup(_ id: UUID) {
        let all = Set(snapshot?.groups.map(\.id) ?? [])
        if selectedGroupIds.isEmpty {
            selectedGroupIds = [id]
            return
        }
        if selectedGroupIds.contains(id) {
            selectedGroupIds.remove(id)
        } else {
            selectedGroupIds.insert(id)
        }
        if !all.isEmpty, selectedGroupIds == all {
            selectedGroupIds = []
        }
    }

    private func openCard(productId: UUID) async {
        guard let snapshot, let companyId = companyManager.currentCompany?.id,
              let product = snapshot.products.first(where: { $0.id == productId }) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let movementRows = WarehouseCardMovementLoader.fetch(
                companyId: companyId,
                productIds: [productId]
            )
            async let shiftWindows = WarehouseCardMovementLoader.fetchSheets(companyId: companyId)
            let movements = try await movementRows
            let windows = try await shiftWindows
            let warehouseIds: Set<UUID>? = {
                guard let locationId else { return nil }
                return Set(snapshot.warehouses.filter { $0.locationId == locationId }.map(\.id))
            }()
            let period = cardPeriod()
            cardPack = WarehouseCardPack(
                companyName: snapshot.companyName,
                scope: locationTitle,
                from: period.from,
                to: period.to,
                shift: shift,
                windows: windows,
                products: [product],
                movements: movements,
                warehouseIds: warehouseIds,
                locationByWarehouse: Dictionary(uniqueKeysWithValues: snapshot.warehouses.compactMap { warehouse in
                    guard let linked = warehouse.locationId else { return nil }
                    return (warehouse.id, linked)
                })
            )
            showCard = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cardPeriod() -> (from: Date, to: Date) {
        let start = WarehouseCardPeriod.day(fromDate)
        let end = WarehouseCardPeriod.day(toDate)
        return start <= end ? (start, end) : (end, start)
    }

    private var periodCaption: String {
        let period = cardPeriod()
        return "\(SupplierFormatting.compactDate(period.from)) – \(SupplierFormatting.compactDate(period.to)) · \(WarehouseCardPeriod.label(shift))"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let companyId = companyManager.currentCompany?.id else {
            errorMessage = L10n.tr("module.no_company")
            return
        }
        do {
            snapshot = try await StockListingLoader.load(
                companyId: companyId,
                companyName: companyManager.currentCompany?.denumire ?? ""
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makePDF() throws -> URL {
        guard let snapshot else { throw StockListingError.empty }
        return try StockListingPDF.write(
            companyName: snapshot.companyName,
            scope: locationTitle,
            sections: sections,
            generatedAt: snapshot.loadedAt
        )
    }

    private func exportPDF() async {
        errorMessage = nil
        do {
            let url = try makePDF()
#if targetEnvironment(macCatalyst)
            let suggested = StockListingPDF.fileName(scope: locationTitle, generatedAt: snapshot?.loadedAt ?? Date())
            if !DocumentExportSupport.saveOnMac(from: url, suggestedName: suggested) {
                errorMessage = L10n.tr("listings.stock_save_failed")
            }
#else
            exportShareItems = [url]
            showExportShare = true
#endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func printPDF() async {
        errorMessage = nil
        do {
            let url = try makePDF()
#if targetEnvironment(macCatalyst)
            try DocumentExportSupport.printPDF(url: url, jobName: L10n.tr("listings.stock_print_job"))
#else
            pdfURL = url
            showPrintSheet = true
#endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum StockListingError: LocalizedError {
    case empty
    var errorDescription: String? { L10n.tr("listings.stock_empty") }
}

enum StockListingCatalog {
    static let kinds: [ProductKind] = [
        .produsFinit, .marfa, .materiePrima, .ambalaj,
        .obiectInventar, .servicii
    ]

    static func includes(kind: ProductKind, code: String, name: String) -> Bool {
        switch kind {
        case .produsFinit:
            return finishedGoods.contains(token(code))
        case .marfa, .obiectInventar, .servicii:
            return true
        case .materiePrima:
            return !rawMaterialExcluded.contains(token(code)) && !rawMaterialExcluded.contains(token(name))
        case .ambalaj:
            return !packagingExcluded.contains(token(code))
        case .materialeConsumabile, .materialeCuratenie, .birotica, .garantie:
            return false
        }
    }

    private static let finishedGoods: Set<String> = [
        "1318", "1503", "79", "83", "84", "1462", "81"
    ]
    private static let rawMaterialExcluded: Set<String> = [
        "216400", "6421735000207", "721806", "6421735000208",
        "driver fiscalnet plus - licenta anuala"
    ]
    private static let packagingExcluded: Set<String> = [
        "223617", "211293", "209118", "6421735000145"
    ]

    private static func token(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "ro_RO"))
            .lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

struct StockListingLocation: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
}

struct StockListingGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
}

struct StockListingLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let number: Int
    let code: String
    let name: String
    let unit: String
    let quantity: Decimal
}

struct StockListingSection: Identifiable, Hashable, Sendable {
    let kind: ProductKind
    let title: String
    let lines: [StockListingLine]
    var id: String { kind.rawValue }
}

struct StockListingSnapshot: Sendable {
    let companyName: String
    let loadedAt: Date
    let locations: [StockListingLocation]
    let groups: [StockListingGroup]
    let warehouses: [StockListingWarehouse]
    let products: [StockListingProduct]

    var stamp: String {
        StockListingPDF.stamp(loadedAt)
    }

    func sections(locationId: UUID?, kinds: Set<ProductKind>, groupIds: Set<UUID>) -> [StockListingSection] {
        let warehouseIds: Set<UUID>? = {
            guard let locationId else { return nil }
            return Set(warehouses.filter { $0.locationId == locationId }.map(\.id))
        }()
        let filtered = products.filter { product in
            guard StockListingCatalog.includes(kind: product.kind, code: product.code, name: product.name) else { return false }
            if !kinds.isEmpty, !kinds.contains(product.kind) { return false }
            if !groupIds.isEmpty, product.groupIds.isDisjoint(with: groupIds) { return false }
            return true
        }
        let grouped = Dictionary(grouping: filtered, by: \.kind)
        var number = 0
        return StockListingCatalog.kinds.compactMap { kind in
            guard let rows = grouped[kind], !rows.isEmpty else { return nil }
            number += 1
            let sorted = rows.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            let lines = sorted.enumerated().map { index, product in
                StockListingLine(
                    id: product.id,
                    number: index + 1,
                    code: product.code,
                    name: product.name,
                    unit: product.unit,
                    quantity: product.quantity(in: warehouseIds)
                )
            }
            return StockListingSection(
                kind: kind,
                title: "\(number). \(kind.label)",
                lines: lines
            )
        }
    }
}

struct StockListingWarehouse: Hashable, Sendable {
    let id: UUID
    let locationId: UUID?
}

struct StockListingProduct: Identifiable, Hashable, Sendable {
    let id: UUID
    let code: String
    let name: String
    let unit: String
    let kind: ProductKind
    let groupIds: Set<UUID>
    let quantityByWarehouse: [UUID: Decimal]

    func quantity(in warehouseIds: Set<UUID>?) -> Decimal {
        if let warehouseIds {
            return warehouseIds.reduce(Decimal.zero) { partial, id in
                partial + (quantityByWarehouse[id] ?? 0)
            }
        }
        return quantityByWarehouse.values.reduce(Decimal.zero, +)
    }
}

enum StockListingLoader {
    private static let client = SupabaseManager.client

    private struct ProductRow: Decodable {
        let id: UUID
        let cod: String?
        let denumire: String
        let unitateMasura: String
        let tip: ProductKind

        enum CodingKeys: String, CodingKey {
            case id, cod, denumire, tip
            case unitateMasura = "unitate_masura"
        }
    }

    private struct StockRow: Decodable {
        let warehouseId: UUID
        let productId: UUID
        @SupabaseDecimal var cantitate: Decimal

        enum CodingKeys: String, CodingKey {
            case warehouseId = "warehouse_id"
            case productId = "product_id"
            case cantitate
        }
    }

    private struct GroupRow: Decodable {
        let id: UUID
        let name: String
        let kind: String
    }

    private struct MemberRow: Decodable {
        let groupId: UUID
        let productId: UUID

        enum CodingKeys: String, CodingKey {
            case groupId = "group_id"
            case productId = "product_id"
        }
    }

    static func load(companyId: UUID, companyName: String) async throws -> StockListingSnapshot {
        async let productRows = pages { from, to in
            let rows: [ProductRow] = try await client
                .from("products")
                .select("id,cod,denumire,unitate_masura,tip")
                .eq("company_id", value: companyId.uuidString)
                .eq("is_active", value: true)
                .neq("tip", value: ProductKind.garantie.rawValue)
                .order("denumire", ascending: true)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
            return rows
        }
        async let stockRows = pages { from, to in
            let rows: [StockRow] = try await client
                .from("warehouse_product_stocks")
                .select("warehouse_id,product_id,cantitate")
                .eq("company_id", value: companyId.uuidString)
                .order("warehouse_id", ascending: true)
                .order("product_id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
            return rows
        }
        async let groupRows = pages { from, to in
            let rows: [GroupRow] = try await client
                .from("cm_product_groups")
                .select("id,name,kind")
                .eq("company_id", value: companyId.uuidString)
                .order("sort_order", ascending: true)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
            return rows
        }
        async let memberRows = pages { from, to in
            let rows: [MemberRow] = try await client
                .from("cm_product_group_members")
                .select("group_id,product_id")
                .eq("company_id", value: companyId.uuidString)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
            return rows
        }
        async let warehouses = WarehouseService.fetchWarehouses(companyId: companyId)
        async let locations = WorkLocationService.fetchWorkLocations(companyId: companyId)

        let products = try await productRows
        let stocks = try await stockRows
        let groups = try await groupRows
        let members = try await memberRows
        let warehouseRows = try await warehouses
        let locationRows = try await locations

        var qty: [UUID: [UUID: Decimal]] = [:]
        for row in stocks {
            qty[row.productId, default: [:]][row.warehouseId, default: 0] += row.cantitate
        }
        let customGroups = groups.filter { $0.kind == "custom" }
        let customIds = Set(customGroups.map(\.id))
        var membership: [UUID: Set<UUID>] = [:]
        for row in members where customIds.contains(row.groupId) {
            membership[row.productId, default: []].insert(row.groupId)
        }
        let listingProducts = products.compactMap { row -> StockListingProduct? in
            let code = row.cod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard StockListingCatalog.includes(kind: row.tip, code: code, name: row.denumire) else { return nil }
            return StockListingProduct(
                id: row.id,
                code: code,
                name: row.denumire,
                unit: row.unitateMasura,
                kind: row.tip,
                groupIds: membership[row.id] ?? [],
                quantityByWarehouse: qty[row.id] ?? [:]
            )
        }
        let listingLocations = locationRows
            .filter(\.isActive)
            .sorted { $0.denumire.localizedCaseInsensitiveCompare($1.denumire) == .orderedAscending }
            .map { StockListingLocation(id: $0.id, name: $0.denumire) }
        return StockListingSnapshot(
            companyName: companyName,
            loadedAt: Date(),
            locations: listingLocations,
            groups: customGroups.map { StockListingGroup(id: $0.id, name: $0.name) },
            warehouses: warehouseRows.filter(\.isActive).map {
                StockListingWarehouse(id: $0.id, locationId: $0.workLocationId)
            },
            products: listingProducts
        )
    }

    private static func pages<T>(_ fetch: (_ from: Int, _ to: Int) async throws -> [T]) async throws -> [T] {
        try await SupabasePaging.fetchAll(fetch)
    }
}

enum StockListingPDF {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 36
    private static let fractions: [CGFloat] = [0.06, 0.14, 0.40, 0.08, 0.16, 0.16]

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.timeZone = TimeZone(identifier: "Europe/Bucharest")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    static func fileName(scope: String, generatedAt: Date) -> String {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "Europe/Bucharest")
        day.dateFormat = "yyyy-MM-dd"
        let place = plain(scope)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "Listare-stoc-\(place)-\(day.string(from: generatedAt)).pdf"
    }

    static func write(
        companyName: String,
        scope: String,
        sections: [StockListingSection],
        generatedAt: Date
    ) throws -> URL {
        let data = make(
            companyName: companyName,
            scope: scope,
            sections: sections,
            generatedAt: generatedAt
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(scope: scope, generatedAt: generatedAt))
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func make(
        companyName: String,
        scope: String,
        sections: [StockListingSection],
        generatedAt: Date
    ) -> Data {
        let total = max(render(
            companyName: companyName,
            scope: scope,
            sections: sections,
            generatedAt: generatedAt,
            totalPages: nil
        ).pageCount, 1)
        return render(
            companyName: companyName,
            scope: scope,
            sections: sections,
            generatedAt: generatedAt,
            totalPages: total
        ).data
    }

    private struct RenderResult {
        let data: Data
        let pageCount: Int
    }

    private static func render(
        companyName: String,
        scope: String,
        sections: [StockListingSection],
        generatedAt: Date,
        totalPages: Int?
    ) -> RenderResult {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 14)
        let headFont = UIFont.boldSystemFont(ofSize: 9)
        let bodyFont = UIFont.systemFont(ofSize: 9)
        let contentWidth = pageRect.width - margin * 2
        let headers = ["Nr", "Cod", "Denumire", "UM", "Stoc scriptic", "Stoc faptic"]
        let bottom = pageRect.height - margin - 18
        var pageCount = 0
        var currentPage = 0
        let data = renderer.pdfData { context in
            func beginPage() {
                if currentPage > 0, let totalPages {
                    drawFooter(page: currentPage, total: totalPages, pageWidth: pageRect.width, pageHeight: pageRect.height)
                }
                context.beginPage()
                currentPage += 1
                pageCount = currentPage
            }
            func headerBlock() -> CGFloat {
                var y = margin
                y = draw(plain(companyName), at: y, width: contentWidth, font: titleFont)
                y = draw("Listare stocuri", at: y + 2, width: contentWidth, font: titleFont)
                y = draw(plain(scope) + "  ·  " + stamp(generatedAt), at: y + 2, width: contentWidth, font: bodyFont)
                y += 8
                y = drawRow(headers, at: y, contentWidth: contentWidth, font: headFont, bold: true)
                return y
            }

            beginPage()
            var y = headerBlock()
            for section in sections {
                if y > bottom - 36 {
                    beginPage()
                    y = headerBlock()
                }
                y = draw(plain(section.title), at: y + 4, width: contentWidth, font: headFont)
                for line in section.lines {
                    if y > bottom - 16 {
                        beginPage()
                        y = headerBlock()
                        y = draw(plain(section.title), at: y + 2, width: contentWidth, font: headFont)
                    }
                    let values = [
                        "\(line.number)",
                        plain(line.code),
                        plain(line.name),
                        plain(line.unit),
                        plain(SupplierFormatting.stockQuantityString(line.quantity)),
                        ""
                    ]
                    y = drawRow(values, at: y, contentWidth: contentWidth, font: bodyFont, bold: false)
                }
            }
            if let totalPages {
                drawFooter(page: currentPage, total: totalPages, pageWidth: pageRect.width, pageHeight: pageRect.height)
            }
        }
        return RenderResult(data: data, pageCount: pageCount)
    }

    private static func drawFooter(page: Int, total: Int, pageWidth: CGFloat, pageHeight: CGFloat) {
        let font = UIFont.systemFont(ofSize: 8)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = "Pagina \(page) / \(total)  ·  Document generat cu ERP Mobile by DateConta"
        text.draw(in: CGRect(x: margin, y: pageHeight - margin - 8, width: pageWidth - margin * 2, height: 12), withAttributes: [
            .font: font,
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraph
        ])
    }

    @discardableResult
    private static func draw(_ text: String, at y: CGFloat, width: CGFloat, font: UIFont) -> CGFloat {
        text.draw(in: CGRect(x: margin, y: y, width: width, height: font.lineHeight + 4), withAttributes: [
            .font: font,
            .foregroundColor: UIColor.black
        ])
        return y + font.lineHeight + 2
    }

    private static func drawRow(_ values: [String], at y: CGFloat, contentWidth: CGFloat, font: UIFont, bold: Bool) -> CGFloat {
        var x = margin
        let height = font.lineHeight + 6
        for (index, value) in values.enumerated() {
            let width = contentWidth * fractions[index]
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            paragraph.alignment = (index == 0 || index >= 4) ? .right : .left
            value.draw(in: CGRect(x: x, y: y, width: width - 4, height: height), withAttributes: [
                .font: bold ? UIFont.boldSystemFont(ofSize: font.pointSize) : font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ])
            x += width
        }
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y + height))
        line.addLine(to: CGPoint(x: margin + contentWidth, y: y + height))
        UIColor.lightGray.setStroke()
        line.lineWidth = 0.4
        line.stroke()
        return y + height
    }

    nonisolated static func plain(_ text: String) -> String {
        let folded = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "ro_RO"))
        let map: [Character: Character] = [
            "ă": "a", "â": "a", "î": "i", "ș": "s", "ț": "t", "ş": "s", "ţ": "t",
            "Ă": "A", "Â": "A", "Î": "I", "Ș": "S", "Ț": "T", "Ş": "S", "Ţ": "T"
        ]
        return String(folded.map { map[$0] ?? $0 })
    }
}
