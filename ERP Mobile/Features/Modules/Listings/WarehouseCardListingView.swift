import SwiftUI
import UIKit
import Supabase

/// Listare fișe de magazie: produse bifate, puncte de lucru, grupe, categorii și perioadă.
struct WarehouseCardListingView: View {
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var snapshot: StockListingSnapshot?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedLocationIds: Set<UUID> = []
    @State private var selectedKinds: Set<ProductKind> = []
    @State private var selectedGroupIds: Set<UUID> = []
    @State private var selectedProductIds: Set<UUID> = []
    @State private var showLocations = false
    @State private var showCategories = false
    @State private var showGroups = false
    @State private var fromDate = WarehouseCardPeriod.startOfMonth()
    @State private var toDate = Date()
    @State private var shift = 0
    @State private var showResult = false
    @State private var resultPack: WarehouseCardPack?

    private var visibleProducts: [StockListingProduct] {
        guard let snapshot else { return [] }
        return snapshot.products
            .filter { product in
                if !selectedKinds.isEmpty, !selectedKinds.contains(product.kind) { return false }
                if !selectedGroupIds.isEmpty, product.groupIds.isDisjoint(with: selectedGroupIds) { return false }
                return true
            }
            .sorted {
                let rank = StockListingCatalog.kinds.firstIndex(of: $0.kind) ?? 99
                let other = StockListingCatalog.kinds.firstIndex(of: $1.kind) ?? 99
                if rank != other { return rank < other }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            ListingsBackButton()
            filters
            productList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L10n.tr("listings.tile_warehouse_cards"))
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
        .background(
            ProgrammaticNavigationLink(isActive: $showResult) {
                if let resultPack {
                    WarehouseCardResultView(pack: resultPack)
                } else {
                    EmptyView()
                }
            }
        )
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L10n.tr("listings.card_from"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                AppDatePicker(selection: $fromDate)
                Text(L10n.tr("listings.card_to"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                AppDatePicker(selection: $toDate)
                Picker(L10n.tr("listings.shift"), selection: $shift) {
                    Text(L10n.tr("listings.shift_all")).tag(0)
                    Text(L10n.tr("listings.shift_1")).tag(1)
                    Text(L10n.tr("listings.shift_2")).tag(2)
                }
                .pickerStyle(.menu)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { showLocations = true } label: {
                        chip(locationTitle, systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showLocations) { locationPicker }
                    Button { showGroups = true } label: {
                        chip(groupTitle, systemImage: "rectangle.3.group")
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showGroups) { groupPicker }
                    Button { showCategories = true } label: {
                        chip(categoryTitle, systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showCategories) { kindPicker }
                }
            }
            HStack {
                Button(L10n.tr("listings.card_check_visible")) {
                    selectedProductIds.formUnion(visibleProducts.map(\.id))
                }
                .buttonStyle(.borderless)
                Spacer()
                Button(L10n.tr("listings.card_uncheck_visible")) {
                    let visible = Set(visibleProducts.map(\.id))
                    selectedProductIds.subtract(visible)
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
            Button(L10n.tr("listings.card_show")) {
                Task { await showCards() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedProductIds.isEmpty || isLoading)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }

    private var productList: some View {
        List(visibleProducts) { product in
            Button {
                toggleProduct(product.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedProductIds.contains(product.id) ? "checkmark.square.fill" : "square")
                        .foregroundColor(AppColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .foregroundColor(AppColors.primary)
                            .lineLimit(2)
                        Text("\(product.code) · \(product.kind.label)")
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Spacer()
                    Text(product.unit)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var locationPicker: some View {
        filterList(
            allTitle: L10n.tr("listings.stock_all_company"),
            clear: { selectedLocationIds = [] },
            rows: snapshot?.locations ?? [],
            isOn: { selectedLocationIds.isEmpty || selectedLocationIds.contains($0.id) },
            title: { $0.name },
            toggle: { toggleLocation($0.id) }
        )
    }

    private var groupPicker: some View {
        filterList(
            allTitle: L10n.tr("listings.stock_all_groups"),
            clear: { selectedGroupIds = [] },
            rows: snapshot?.groups ?? [],
            isOn: { selectedGroupIds.isEmpty || selectedGroupIds.contains($0.id) },
            title: { $0.name },
            toggle: { toggleGroup($0.id) }
        )
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(L10n.tr("listings.stock_all_categories")) { selectedKinds = [] }
                .padding()
            List(StockListingCatalog.kinds, id: \.self) { kind in
                Button { toggleKind(kind) } label: {
                    HStack {
                        Text(kind.label).foregroundColor(AppColors.primary)
                        Spacer()
                        if selectedKinds.isEmpty || selectedKinds.contains(kind) {
                            Image(systemName: "checkmark").foregroundColor(AppColors.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 280, minHeight: 360)
    }

    private func filterList<Row: Identifiable>(
        allTitle: String,
        clear: @escaping () -> Void,
        rows: [Row],
        isOn: @escaping (Row) -> Bool,
        title: @escaping (Row) -> String,
        toggle: @escaping (Row) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(allTitle, action: clear).padding()
            List(rows) { row in
                Button { toggle(row) } label: {
                    HStack {
                        Text(title(row)).foregroundColor(AppColors.primary)
                        Spacer()
                        if isOn(row) {
                            Image(systemName: "checkmark").foregroundColor(AppColors.accent)
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.separator), lineWidth: 1))
    }

    private var locationTitle: String {
        guard let snapshot else { return L10n.tr("listings.stock_all_company") }
        let names = snapshot.locations.filter { selectedLocationIds.contains($0.id) }.map(\.name)
        if names.isEmpty { return L10n.tr("listings.stock_all_company") }
        if names.count == 1 { return names[0] }
        return L10n.tr("listings.card_locations_count", names.count)
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

    private func toggleProduct(_ id: UUID) {
        if selectedProductIds.contains(id) { selectedProductIds.remove(id) }
        else { selectedProductIds.insert(id) }
    }

    private func toggleKind(_ kind: ProductKind) {
        if selectedKinds.isEmpty {
            selectedKinds = [kind]
            return
        }
        if selectedKinds.contains(kind) { selectedKinds.remove(kind) } else { selectedKinds.insert(kind) }
        if selectedKinds.count == StockListingCatalog.kinds.count { selectedKinds = [] }
    }

    private func toggleGroup(_ id: UUID) {
        let all = Set(snapshot?.groups.map(\.id) ?? [])
        if selectedGroupIds.isEmpty {
            selectedGroupIds = [id]
            return
        }
        if selectedGroupIds.contains(id) { selectedGroupIds.remove(id) } else { selectedGroupIds.insert(id) }
        if !all.isEmpty, selectedGroupIds == all { selectedGroupIds = [] }
    }

    private func toggleLocation(_ id: UUID) {
        let all = Set(snapshot?.locations.map(\.id) ?? [])
        if selectedLocationIds.isEmpty {
            selectedLocationIds = [id]
            return
        }
        if selectedLocationIds.contains(id) { selectedLocationIds.remove(id) } else { selectedLocationIds.insert(id) }
        if !all.isEmpty, selectedLocationIds == all { selectedLocationIds = [] }
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

    private func showCards() async {
        guard let snapshot, let companyId = companyManager.currentCompany?.id else { return }
        let products = snapshot.products.filter { selectedProductIds.contains($0.id) }
        guard !products.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let movementRows = WarehouseCardMovementLoader.fetch(
                companyId: companyId,
                productIds: products.map(\.id)
            )
            async let shiftWindows = WarehouseCardMovementLoader.fetchSheets(companyId: companyId)
            let movements = try await movementRows
            let windows = try await shiftWindows
            let warehouseIds: Set<UUID>? = selectedLocationIds.isEmpty
                ? nil
                : Set(snapshot.warehouses.filter { locationId in
                    guard let locationId = locationId.locationId else { return false }
                    return selectedLocationIds.contains(locationId)
                }.map(\.id))
            let scope = locationTitle
            resultPack = WarehouseCardPack(
                companyName: snapshot.companyName,
                scope: scope,
                from: fromDate,
                to: toDate,
                shift: shift,
                windows: windows,
                products: products.sorted {
                    let left = StockListingCatalog.kinds.firstIndex(of: $0.kind) ?? 99
                    let right = StockListingCatalog.kinds.firstIndex(of: $1.kind) ?? 99
                    if left != right { return left < right }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                },
                movements: movements,
                warehouseIds: warehouseIds,
                locationByWarehouse: Dictionary(uniqueKeysWithValues: snapshot.warehouses.compactMap { warehouse in
                    guard let locationId = warehouse.locationId else { return nil }
                    return (warehouse.id, locationId)
                })
            )
            showResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum WarehouseCardPeriod {
    static func startOfMonth(_ date: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? date
    }

    static func stamp(_ date: Date) -> String {
        stampFormatter.string(from: date)
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.timeZone = TimeZone(identifier: "Europe/Bucharest")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()

    static func day(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
        return calendar.startOfDay(for: date)
    }

    static func bucharestCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
        return calendar
    }

    /// Data scrisă pe foaie. La tura 2 este cu o zi în urmă față de închidere.
    static func writtenDay(sheetDate: String, shift: Int) -> Date? {
        let parts = String(sheetDate.prefix(10)).split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let dayNumber = Int(parts[2]) else { return nil }
        let calendar = bucharestCalendar()
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)) else { return nil }
        let shown = shift == 2 ? calendar.date(byAdding: .day, value: -1, to: date) ?? date : date
        return Self.day(shown)
    }

    static func label(_ shift: Int) -> String {
        switch shift {
        case 1: return L10n.tr("listings.shift_1")
        case 2: return L10n.tr("listings.shift_2")
        default: return L10n.tr("listings.shift_all")
        }
    }
}

struct WarehouseCardPack {
    let companyName: String
    let scope: String
    let from: Date
    let to: Date
    let shift: Int
    let windows: [ListingShiftWindow]
    let products: [StockListingProduct]
    let movements: [WarehouseCardMovement]
    let warehouseIds: Set<UUID>?
    let locationByWarehouse: [UUID: UUID]

    var cards: [WarehouseCardSheet] {
        let fromDay = WarehouseCardPeriod.day(from)
        let toDay = WarehouseCardPeriod.day(to)
        return products.map { product in
            let rows = movements.filter { movement in
                movement.productId == product.id && movement.matches(warehouseIds)
            }
            return WarehouseCardBuilder.sheet(
                product: product,
                movements: rows,
                from: fromDay,
                to: toDay,
                shift: shift,
                windows: windows,
                locationByWarehouse: locationByWarehouse
            )
        }
    }
}

struct WarehouseCardResultView: View {
    let pack: WarehouseCardPack

    @State private var link: WarehouseCardLink?
    @State private var errorMessage: String?
    @State private var showExportShare = false
    @State private var showPrintSheet = false
    @State private var exportShareItems: [Any] = []
    @State private var pdfURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            ListingsBackButton()
            HStack {
                Button {
                    Task { await exportPDF() }
                } label: {
                    PdfActionLabel(title: L10n.tr("account.export_pdf"), saves: true)
                }
                Button {
                    Task { await printPDF() }
                } label: {
                    Label(L10n.tr("account.print"), systemImage: "printer.fill")
                }
                Spacer()
                Text(periodTitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            GeometryReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(pack.cards) { card in
                            cardBlock(card, width: proxy.size.width - 24)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L10n.tr("listings.tile_warehouse_cards"))
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(item: $link) { item in
            WarehouseCardDocumentHost(link: item)
        }
        .sheet(isPresented: $showExportShare) {
            ActivityShareSheet(items: exportShareItems, excludedActivityTypes: nil, onFinish: { showExportShare = false })
        }
        .sheet(isPresented: $showPrintSheet) {
            if let pdfURL, let data = try? Data(contentsOf: pdfURL) {
                PrintDocumentView(pdfData: data, jobName: L10n.tr("listings.card_print_job"), onFinish: { showPrintSheet = false })
            }
        }
    }

    private var periodTitle: String {
        "\(SupplierFormatting.compactDate(pack.from)) – \(SupplierFormatting.compactDate(pack.to)) · \(WarehouseCardPeriod.label(pack.shift)) · \(pack.scope)"
    }

    private func cardBlock(_ card: WarehouseCardSheet, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.product.name)
                .font(.headline)
            Text("\(card.product.code) · \(card.product.unit) · \(card.product.kind.label)")
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            cardTable(card, width: width)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardTable(_ card: WarehouseCardSheet, width: CGFloat) -> some View {
        let widths = WarehouseCardTable.widths(for: width)
        return VStack(spacing: 0) {
            tableRow(WarehouseCardTable.headers, widths: widths, bold: true, link: nil, stock: nil)
            ForEach(card.lines) { line in
                Button {
                    if let lineLink = line.link { link = lineLink }
                } label: {
                    tableRow(line.values, widths: widths, bold: line.isBalance, link: line.link, stock: line.stock)
                }
                .buttonStyle(.plain)
                .disabled(line.link == nil)
            }
        }
        .overlay(Rectangle().stroke(Color(UIColor.separator), lineWidth: 0.5))
    }

    private func tableRow(_ values: [String], widths: [CGFloat], bold: Bool, link: WarehouseCardLink?, stock: Decimal?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(bold ? .caption.weight(.semibold) : .caption)
                    .foregroundColor(color(index: index, value: value, stock: stock))
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .frame(width: widths[index], alignment: index == 1 || index == 2 ? .leading : .trailing)
            }
            if link != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
                    .frame(width: 16)
            } else {
                Color.clear.frame(width: 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bold ? Color.secondary.opacity(0.12) : Color.clear)
    }

    private func color(index: Int, value: String, stock: Decimal?) -> Color {
        if index == 3, value.hasPrefix("+") || (!value.isEmpty && value != "—") { return .green }
        if index == 4, !value.isEmpty, value != "—" { return .red }
        if index == 6, let stock, stock < 0 { return .red }
        return AppColors.primary
    }

    private func exportPDF() async {
        do {
            let url = try WarehouseCardPDF.write(pack: pack)
#if targetEnvironment(macCatalyst)
            let name = WarehouseCardPDF.fileName(generatedAt: Date())
            if !DocumentExportSupport.saveOnMac(from: url, suggestedName: name) {
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
        do {
            let url = try WarehouseCardPDF.write(pack: pack)
#if targetEnvironment(macCatalyst)
            try DocumentExportSupport.printPDF(url: url, jobName: L10n.tr("listings.card_print_job"))
#else
            pdfURL = url
            showPrintSheet = true
#endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum WarehouseCardTable {
    static var headers: [String] {
        [
            L10n.tr("listings.card_col_date"),
            L10n.tr("listings.card_col_document"),
            L10n.tr("listings.card_col_kind"),
            L10n.tr("listings.card_col_in"),
            L10n.tr("listings.card_col_out"),
            L10n.tr("listings.card_col_price"),
            L10n.tr("listings.card_col_stock")
        ]
    }

    static func widths(for total: CGFloat) -> [CGFloat] {
        let usable = max(total - 16, 320)
        let fractions: [CGFloat] = [0.18, 0.20, 0.14, 0.12, 0.12, 0.12, 0.12]
        return fractions.map { usable * $0 }
    }
}

struct WarehouseCardSheet: Identifiable {
    let product: StockListingProduct
    let lines: [WarehouseCardLine]
    var id: UUID { product.id }
}

struct WarehouseCardLine: Identifiable {
    let id: String
    let values: [String]
    let isBalance: Bool
    let link: WarehouseCardLink?
    let stock: Decimal
    let plainValues: [String]
}

enum WarehouseCardLink: Identifiable, Hashable {
    case invoice(UUID)
    case nir(UUID)
    case transfer(UUID)
    case production(UUID)
    case consumption(UUID)
    case inventory(UUID)
    case fiscal(number: String, day: String, locationId: UUID?)

    var id: String {
        switch self {
        case .invoice(let value): return "invoice-\(value.uuidString)"
        case .nir(let value): return "nir-\(value.uuidString)"
        case .transfer(let value): return "transfer-\(value.uuidString)"
        case .production(let value): return "production-\(value.uuidString)"
        case .consumption(let value): return "consumption-\(value.uuidString)"
        case .inventory(let value): return "inventory-\(value.uuidString)"
        case .fiscal(let number, let day, let locationId):
            return "fiscal-\(number)-\(day)-\(locationId?.uuidString ?? "")"
        }
    }
}

struct ListingShiftWindow {
    let locationId: UUID
    let startsAfter: Date
    let endsAt: Date
    let writtenDay: Date
    let shift: Int

    static func make(sheets: [ListingSheetStamp]) -> [ListingShiftWindow] {
        let grouped = Dictionary(grouping: sheets, by: \.workLocationId)
        var windows: [ListingShiftWindow] = []
        for (location, rows) in grouped {
            let ordered = rows.sorted { $0.createdAt < $1.createdAt }
            var previous = Date.distantPast
            var last: ListingSheetStamp?
            for row in ordered {
                guard let written = WarehouseCardPeriod.writtenDay(sheetDate: row.sheetDate, shift: row.shiftNo) else { continue }
                windows.append(ListingShiftWindow(
                    locationId: location,
                    startsAfter: previous,
                    endsAt: row.createdAt,
                    writtenDay: written,
                    shift: row.shiftNo
                ))
                previous = row.createdAt
                last = row
            }
            guard let last, let openDay = WarehouseCardPeriod.writtenDay(sheetDate: last.sheetDate, shift: 1) else { continue }
            windows.append(ListingShiftWindow(
                locationId: location,
                startsAfter: previous,
                endsAt: .distantFuture,
                writtenDay: openDay,
                shift: last.shiftNo == 1 ? 2 : 1
            ))
        }
        return windows
    }

    static func matching(instant: Date, location: UUID, windows: [ListingShiftWindow]) -> ListingShiftWindow? {
        windows
            .filter { $0.locationId == location && instant > $0.startsAfter && instant <= $0.endsAt }
            .min { $0.endsAt < $1.endsAt }
    }

    static func listed(instant: Date, location: UUID, from: Date, to: Date, shift: Int, windows: [ListingShiftWindow]) -> Bool {
        guard let window = matching(instant: instant, location: location, windows: windows) else { return false }
        guard window.writtenDay >= from, window.writtenDay <= to else { return false }
        return shift == 0 || window.shift == shift
    }

    static func beforePeriod(instant: Date, location: UUID, from: Date, to: Date, shift: Int, windows: [ListingShiftWindow]) -> Bool {
        let starts = windows
            .filter { $0.locationId == location && $0.writtenDay >= from && $0.writtenDay <= to && (shift == 0 || $0.shift == shift) }
            .map(\.startsAfter)
        guard let start = starts.min() else { return true }
        return instant <= start
    }
}

struct ListingSheetStamp: Decodable {
    let workLocationId: UUID
    let sheetDate: String
    let shiftNo: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case workLocationId = "work_location_id"
        case sheetDate = "sheet_date"
        case shiftNo = "shift_no"
        case createdAt = "created_at"
    }
}

enum WarehouseCardBuilder {
    static func sheet(
        product: StockListingProduct,
        movements: [WarehouseCardMovement],
        from: Date,
        to: Date,
        shift: Int,
        windows: [ListingShiftWindow],
        locationByWarehouse: [UUID: UUID]
    ) -> WarehouseCardSheet {
        let sorted = movements.sorted { lhs, rhs in
            let left = lhs.createdAt ?? lhs.transactionDate
            let right = rhs.createdAt ?? rhs.transactionDate
            if left != right { return left < right }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        var stock: Decimal = 0
        var cost: Decimal = 0
        var inboundTotal: Decimal = 0
        var outboundTotal: Decimal = 0
        var lines: [WarehouseCardLine] = []
        var opened = false
        for movement in sorted {
            let instant = movement.createdAt ?? movement.transactionDate
            let location = movement.warehouseId.flatMap { locationByWarehouse[$0] }
            if let location, windows.contains(where: { $0.locationId == location }) {
                if ListingShiftWindow.listed(instant: instant, location: location, from: from, to: to, shift: shift, windows: windows) {
                    if !opened {
                        lines.append(balance(id: "open-\(product.id.uuidString)", title: L10n.tr("listings.card_opening"), stock: stock, cost: cost))
                        opened = true
                    }
                    let price = movement.tip == .iesire ? cost : movement.unitPrice
                    add(movement, inbound: &inboundTotal, outbound: &outboundTotal)
                    apply(movement, stock: &stock, cost: &cost)
                    lines.append(movementLine(movement, price: price, stock: stock, locationByWarehouse: locationByWarehouse))
                } else if ListingShiftWindow.beforePeriod(instant: instant, location: location, from: from, to: to, shift: shift, windows: windows) {
                    apply(movement, stock: &stock, cost: &cost)
                }
                continue
            }
            let day = WarehouseCardPeriod.day(movement.transactionDate)
            if day < from {
                apply(movement, stock: &stock, cost: &cost)
                continue
            }
            if day > to { continue }
            if !opened {
                lines.append(balance(id: "open-\(product.id.uuidString)", title: L10n.tr("listings.card_opening"), stock: stock, cost: cost))
                opened = true
            }
            let price = movement.tip == .iesire ? cost : movement.unitPrice
            add(movement, inbound: &inboundTotal, outbound: &outboundTotal)
            apply(movement, stock: &stock, cost: &cost)
            lines.append(movementLine(movement, price: price, stock: stock, locationByWarehouse: locationByWarehouse))
        }
        if !opened {
            lines.append(balance(id: "open-\(product.id.uuidString)", title: L10n.tr("listings.card_opening"), stock: stock, cost: cost))
        }
        lines.append(balance(id: "close-\(product.id.uuidString)", title: L10n.tr("listings.card_closing"), stock: stock, cost: cost))
        lines.append(totals(id: "total-\(product.id.uuidString)", inbound: inboundTotal, outbound: outboundTotal))
        return WarehouseCardSheet(product: product, lines: lines)
    }

    private static func add(_ movement: WarehouseCardMovement, inbound: inout Decimal, outbound: inout Decimal) {
        if movement.tip == .intrare {
            inbound += movement.cantitate
        } else {
            outbound += movement.cantitate
        }
    }

    private static func apply(_ movement: WarehouseCardMovement, stock: inout Decimal, cost: inout Decimal) {
        switch movement.tip {
        case .intrare:
            let keeps = movement.sursa == StockMovementSource.stockTransfer.rawValue && stock > 0
            if !keeps {
                let total = stock + movement.cantitate
                cost = total > 0 ? (stock * cost + movement.cantitate * movement.unitPrice) / total : movement.unitPrice
            }
            stock += movement.cantitate
        case .iesire:
            stock -= movement.cantitate
        }
    }

    private static func balance(id: String, title: String, stock: Decimal, cost: Decimal) -> WarehouseCardLine {
        let qty = SupplierFormatting.stockQuantityString(stock)
        let price = stock > 0 ? SupplierFormatting.amountString(cost) : "—"
        let values = ["", title, "", "", "", price, qty]
        return WarehouseCardLine(id: id, values: values, isBalance: true, link: nil, stock: stock, plainValues: values.map(StockListingPDF.plain))
    }

    private static func totals(id: String, inbound: Decimal, outbound: Decimal) -> WarehouseCardLine {
        let values = [
            "",
            L10n.tr("listings.card_total"),
            "",
            SupplierFormatting.stockQuantityString(inbound),
            SupplierFormatting.stockQuantityString(outbound),
            "",
            ""
        ]
        return WarehouseCardLine(id: id, values: values, isBalance: true, link: nil, stock: 0, plainValues: values.map(StockListingPDF.plain))
    }

    private static func movementLine(
        _ movement: WarehouseCardMovement,
        price: Decimal,
        stock: Decimal,
        locationByWarehouse: [UUID: UUID]
    ) -> WarehouseCardLine {
        let inbound = movement.tip == .intrare ? SupplierFormatting.stockQuantityString(movement.cantitate) : "—"
        let outbound = movement.tip == .iesire ? SupplierFormatting.stockQuantityString(movement.cantitate) : "—"
        let values = [
            WarehouseCardPeriod.stamp(movement.createdAt ?? movement.transactionDate),
            movement.documentNumber,
            movement.kindLabel,
            inbound,
            outbound,
            SupplierFormatting.amountString(price),
            SupplierFormatting.stockQuantityString(stock)
        ]
        return WarehouseCardLine(
            id: movement.id.uuidString,
            values: values,
            isBalance: false,
            link: movement.link(locationByWarehouse: locationByWarehouse),
            stock: stock,
            plainValues: values.map(StockListingPDF.plain)
        )
    }
}

struct WarehouseCardMovement: Decodable, Identifiable, Hashable {
    let id: UUID
    let productId: UUID
    let tip: StockMovementKind
    @SupabaseDecimal var cantitate: Decimal
    let sursa: String
    let referinta: String?
    let dataTranzactie: Date?
    let createdAt: Date?
    let warehouseId: UUID?
    @SupabaseOptionalDecimal var pretUnitar: Decimal?
    let invoiceId: UUID?
    let nirId: UUID?
    let transferId: UUID?
    let productionVoucherId: UUID?
    let consumptionVoucherId: UUID?
    let physicalInventoryId: UUID?
    let invoice: StockMovementInvoiceRef?
    let invoiceLine: StockMovementInvoiceLineRef?

    enum CodingKeys: String, CodingKey {
        case id, tip, cantitate, sursa, referinta, invoice
        case productId = "product_id"
        case dataTranzactie = "data_tranzactie"
        case createdAt = "created_at"
        case warehouseId = "warehouse_id"
        case pretUnitar = "pret_unitar"
        case invoiceId = "invoice_id"
        case nirId = "nir_id"
        case transferId = "transfer_id"
        case productionVoucherId = "production_voucher_id"
        case consumptionVoucherId = "consumption_voucher_id"
        case physicalInventoryId = "physical_inventory_id"
        case invoiceLine = "invoice_line"
    }

    var transactionDate: Date { dataTranzactie ?? createdAt ?? .distantPast }

    var unitPrice: Decimal {
        if let pretUnitar, pretUnitar != 0 { return pretUnitar }
        return invoiceLine?.pretUnitar ?? 0
    }

    var documentNumber: String {
        let number = invoice?.numarFactura.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !number.isEmpty { return number }
        let reference = referinta?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reference.isEmpty ? "—" : reference
    }

    var kindLabel: String {
        switch sursa {
        case "supplier_nir": return L10n.tr("listings.card_kind_nir")
        case "supplier_invoice", "supplier_invoice_backfill": return L10n.tr("listings.card_kind_invoice")
        case "supplier_invoice_delete", "supplier_invoice_storno", "supplier_invoice_storno_delete":
            return L10n.tr("listings.card_kind_invoice_void")
        case "stock_transfer": return L10n.tr("listings.card_kind_transfer")
        case "production_voucher": return L10n.tr("listings.card_kind_production")
        case "consumption_voucher": return L10n.tr("listings.card_kind_consumption")
        case "fiscal_receipt": return L10n.tr("listings.card_kind_receipt")
        case "physical_inventory": return L10n.tr("listings.card_kind_inventory")
        case "initial_stock": return L10n.tr("listings.card_kind_initial")
        default: return sursa
        }
    }

    func matches(_ warehouseIds: Set<UUID>?) -> Bool {
        guard let warehouseIds else { return true }
        guard let warehouseId else { return false }
        return warehouseIds.contains(warehouseId)
    }

    func link(locationByWarehouse: [UUID: UUID]) -> WarehouseCardLink? {
        if let productionVoucherId { return .production(productionVoucherId) }
        if let consumptionVoucherId { return .consumption(consumptionVoucherId) }
        if let transferId { return .transfer(transferId) }
        if let nirId { return .nir(nirId) }
        if let physicalInventoryId { return .inventory(physicalInventoryId) }
        if let invoiceId { return .invoice(invoiceId) }
        if sursa == StockMovementSource.fiscalReceipt.rawValue {
            let raw = (referinta ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let number = raw.hasPrefix("BF ") ? String(raw.dropFirst(3)) : raw
            guard !number.isEmpty else { return nil }
            let day = WarehouseCardPDF.isoDay(transactionDate)
            let locationId = warehouseId.flatMap { locationByWarehouse[$0] }
            return .fiscal(number: number, day: day, locationId: locationId)
        }
        return nil
    }
}

enum WarehouseCardMovementLoader {
    private static let client = SupabaseManager.client
    private static let selectList = """
        id, product_id, tip, cantitate, sursa, referinta, data_tranzactie, created_at, warehouse_id, pret_unitar, \
        invoice_id, nir_id, transfer_id, production_voucher_id, consumption_voucher_id, physical_inventory_id, \
        invoice:supplier_invoices(numar_factura, data_factura), \
        invoice_line:supplier_invoice_lines(pret_unitar, suma_linie, suma_tva, cota_tva)
        """

    static func fetchSheets(companyId: UUID) async throws -> [ListingShiftWindow] {
        let rows: [ListingSheetStamp] = try await SupabasePaging.fetchAll { from, to in
            let page: [ListingSheetStamp] = try await client
                .from("z_stock_sheets")
                .select("work_location_id, sheet_date, shift_no, created_at")
                .eq("company_id", value: companyId.uuidString)
                .order("created_at", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
            return page
        }
        return ListingShiftWindow.make(sheets: rows)
    }

    static func fetch(companyId: UUID, productIds: [UUID]) async throws -> [WarehouseCardMovement] {
        let unique = Array(Set(productIds))
        guard !unique.isEmpty else { return [] }
        return try await SupabasePaging.flatMapChunks(unique, size: 40) { slice in
            try await SupabasePaging.fetchAll { from, to in
                let rows: [WarehouseCardMovement] = try await client
                    .from("stock_movements")
                    .select(selectList)
                    .eq("company_id", value: companyId.uuidString)
                    .in("product_id", values: slice.map(\.uuidString))
                    .order("data_tranzactie", ascending: true)
                    .order("id", ascending: true)
                    .range(from: from, to: to)
                    .execute()
                    .value
                return rows
            }
        }
    }
}

enum WarehouseCardPDF {
    private static let pageSize = CGSize(width: 842, height: 595)
    private static let margin: CGFloat = 28
    private static let fractions: [CGFloat] = [0.16, 0.20, 0.14, 0.12, 0.12, 0.12, 0.14]

    static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Bucharest")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func fileName(generatedAt: Date) -> String {
        "Listare-fise-magazie-\(isoDay(generatedAt)).pdf"
    }

    static func write(pack: WarehouseCardPack) throws -> URL {
        let data = make(pack: pack)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(generatedAt: Date()))
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func make(pack: WarehouseCardPack) -> Data {
        let cards = pack.cards
        let total = max(render(pack: pack, cards: cards, totalPages: nil).pageCount, 1)
        return render(pack: pack, cards: cards, totalPages: total).data
    }

    private struct RenderResult { let data: Data; let pageCount: Int }

    private static func render(pack: WarehouseCardPack, cards: [WarehouseCardSheet], totalPages: Int?) -> RenderResult {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 13)
        let headFont = UIFont.boldSystemFont(ofSize: 8)
        let bodyFont = UIFont.systemFont(ofSize: 8)
        let contentWidth = pageRect.width - margin * 2
        let headers = ["Data", "Document", "Fel", "Intrare", "Iesire", "Pret", "Stoc"]
        let bottom = pageRect.height - margin - 16
        var pageCount = 0
        var currentPage = 0
        let period = "\(StockListingPDF.plain(SupplierFormatting.compactDate(pack.from))) - \(StockListingPDF.plain(SupplierFormatting.compactDate(pack.to))) · \(StockListingPDF.plain(WarehouseCardPeriod.label(pack.shift)))"
        let data = renderer.pdfData { context in
            func beginPage() {
                if currentPage > 0, let totalPages { footer(page: currentPage, total: totalPages, page: pageRect) }
                context.beginPage()
                currentPage += 1
                pageCount = currentPage
            }
            func header() -> CGFloat {
                var y = margin
                y = draw(StockListingPDF.plain(pack.companyName), y: y, width: contentWidth, font: titleFont)
                y = draw("Fise de magazie", y: y + 1, width: contentWidth, font: titleFont)
                y = draw(StockListingPDF.plain(pack.scope) + "  ·  " + period, y: y + 1, width: contentWidth, font: bodyFont)
                return y + 6
            }
            beginPage()
            var y = header()
            for card in cards {
                if y > bottom - 40 {
                    beginPage()
                    y = header()
                }
                let title = StockListingPDF.plain(card.product.code + "  " + card.product.name + "  " + card.product.unit)
                y = draw(title, y: y + 4, width: contentWidth, font: headFont)
                y = row(headers, y: y, width: contentWidth, font: headFont, bold: true)
                for line in card.lines {
                    if y > bottom - 12 {
                        beginPage()
                        y = header()
                        y = draw(title, y: y + 2, width: contentWidth, font: headFont)
                        y = row(headers, y: y, width: contentWidth, font: headFont, bold: true)
                    }
                    y = row(line.plainValues, y: y, width: contentWidth, font: bodyFont, bold: line.isBalance)
                }
            }
            if let totalPages { footer(page: currentPage, total: totalPages, page: pageRect) }
        }
        return RenderResult(data: data, pageCount: pageCount)
    }

    private static func footer(page: Int, total: Int, page rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = "Pagina \(page) / \(total)  ·  Document generat cu ERP Mobile by DateConta"
        text.draw(
            in: CGRect(x: margin, y: rect.height - margin - 4, width: rect.width - margin * 2, height: 12),
            withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray, .paragraphStyle: paragraph]
        )
    }

    @discardableResult
    private static func draw(_ text: String, y: CGFloat, width: CGFloat, font: UIFont) -> CGFloat {
        text.draw(in: CGRect(x: margin, y: y, width: width, height: font.lineHeight + 2), withAttributes: [
            .font: font, .foregroundColor: UIColor.black
        ])
        return y + font.lineHeight + 1
    }

    private static func row(_ values: [String], y: CGFloat, width: CGFloat, font: UIFont, bold: Bool) -> CGFloat {
        var x = margin
        let height = font.lineHeight + 4
        for (index, value) in values.enumerated() {
            let column = width * fractions[index]
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            paragraph.alignment = (index == 1 || index == 2) ? .left : .right
            value.draw(in: CGRect(x: x, y: y, width: column - 3, height: height), withAttributes: [
                .font: bold ? UIFont.boldSystemFont(ofSize: font.pointSize) : font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ])
            x += column
        }
        return y + height
    }
}
