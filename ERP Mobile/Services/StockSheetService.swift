import Foundation
import Supabase

enum StockSheetService {
    private static let client = SupabaseManager.client

    static func fetchListRows(
        companyId: UUID,
        warehouseIds: [UUID] = [],
        asOf: Date = Date()
    ) async throws -> [StockSheetListRow] {
        async let productsTask = ProductService.fetchProducts(companyId: companyId, inStockSheet: true)
        async let stocksTask = InventoryService.fetchStockRows(companyId: companyId)
        let products = try await productsTask
        let stocks = try await stocksTask
        let quantityByProduct = Dictionary(uniqueKeysWithValues: stocks.map { ($0.productId, $0.cantitate) })
        let movements = try await InventoryService.fetchProductMovements(
            companyId: companyId,
            productIds: products.map(\.id)
        )
        let movementsByProduct = Dictionary(grouping: movements, by: \.productId)
        let useLedger = !warehouseIds.isEmpty || !Calendar.current.isDateInToday(asOf)

        return products.map { product in
            let scoped = scopedMovements(movementsByProduct[product.id] ?? [], warehouseIds: warehouseIds, asOf: asOf)
            let ledger = StockSheetLedgerBuilder.build(movements: scoped)
            let quantity = useLedger ? ledger.finalQuantity : (quantityByProduct[product.id] ?? ledger.finalQuantity)
            let pretMediu = ledger.weightedAverageCost
            let valoare = (pretMediu ?? 0) * quantity
            return StockSheetListRow(
                product: product,
                cantitate: quantity,
                pretMediu: pretMediu,
                valoare: valoare
            )
        }
        .sorted {
            $0.product.denumire.localizedStandardCompare($1.product.denumire) == .orderedAscending
        }
    }

    static func fetchSnapshot(
        companyId: UUID,
        company: Company?,
        product: Product,
        locationName: String,
        warehouseIds: [UUID] = [],
        asOf: Date = Date()
    ) async throws -> StockSheetSnapshot {
        async let stocksTask = InventoryService.fetchStockRows(companyId: companyId)
        async let movementsTask = InventoryService.fetchProductMovements(
            companyId: companyId,
            productId: product.id
        )
        let stocks = try await stocksTask
        let quantity = stocks.first(where: { $0.productId == product.id })?.cantitate
        let movements = try await movementsTask
        let scoped = scopedMovements(movements, warehouseIds: warehouseIds, asOf: asOf)
        let ledger = StockSheetLedgerBuilder.build(movements: scoped)
        let useLedger = !warehouseIds.isEmpty || !Calendar.current.isDateInToday(asOf)
        let cantitate = useLedger ? ledger.finalQuantity : (quantity ?? ledger.finalQuantity)
        let pretMediu = ledger.weightedAverageCost
        return StockSheetSnapshot(
            company: company,
            product: product,
            entries: ledger.entries,
            cantitate: cantitate,
            pretMediu: pretMediu,
            valoare: (pretMediu ?? 0) * cantitate,
            generatedAt: Date(),
            locationName: locationName,
            asOf: asOf
        )
    }

    private static func scopedMovements(
        _ movements: [StockMovementDetailRow],
        warehouseIds: [UUID],
        asOf: Date
    ) -> [StockMovementDetailRow] {
        let end = Calendar.current.startOfDay(for: asOf).addingTimeInterval(86_399)
        let ids = Set(warehouseIds)
        return movements.filter { movement in
            if movement.transactionDate > end { return false }
            if ids.isEmpty { return true }
            guard let warehouseId = movement.warehouseId else { return false }
            return ids.contains(warehouseId)
        }
    }

    static func fetchInitialStockDraft(companyId: UUID) async throws -> InitialStockDraftSnapshot {
        async let productsTask = ProductService.fetchProducts(companyId: companyId, inStockSheet: true)
        async let stocksTask = InventoryService.fetchStockRows(companyId: companyId)
        let products = try await productsTask
        let stocks = try await stocksTask
        let quantityByProduct = Dictionary(uniqueKeysWithValues: stocks.map { ($0.productId, $0.cantitate) })
        let movements = try await InventoryService.fetchProductMovements(
            companyId: companyId,
            productIds: products.map(\.id)
        )
        let initialByProduct = Dictionary(
            movements
                .filter { $0.sursa == StockMovementSource.initialStock.rawValue && $0.tip == .intrare }
                .map { ($0.productId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let lines = products.map { product -> InitialStockDraftLine in
            let initial = initialByProduct[product.id]
            return InitialStockDraftLine(
                product: product,
                quantityText: initial.map { SupplierFormatting.stockQuantityString($0.cantitate) } ?? "",
                unitPriceText: initial.flatMap { movement -> String? in
                    let price = movement.unitPurchasePrice
                    return price == 0 && movement.pretUnitar == nil ? nil : SupplierFormatting.amountString(price)
                } ?? "",
                currentStock: quantityByProduct[product.id] ?? 0
            )
        }

        let transactionDate = initialByProduct.values
            .map(\.transactionDate)
            .filter { $0 != .distantPast }
            .min()

        return InitialStockDraftSnapshot(lines: lines, transactionDate: transactionDate)
    }

    static func saveInitialStock(
        companyId: UUID,
        transactionDate: Date,
        lines: [InitialStockLinePayload]
    ) async throws -> Int {
        let params = UpsertInitialStockParams(
            pCompanyId: companyId,
            pDataTranzactie: dateString(transactionDate),
            pLines: lines
        )
        let result: Int = try await client
            .rpc("upsert_initial_stock_lines", params: params)
            .execute()
            .value
        return result
    }

    static func mapInitialStockError(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("INITIAL_STOCK_FORBIDDEN") {
            return L10n.tr("stock_sheet.initial.forbidden")
        }
        if text.contains("INITIAL_STOCK_INVALID_QTY") {
            return L10n.tr("stock_sheet.initial.invalid_qty_rpc")
        }
        return text
    }

    static func fetchPosZSheets(companyId: UUID) async throws -> [ZStockSheetRow] {
        try await client
            .from("z_stock_sheets")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .neq("z_number", value: "")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchZSheets(companyId: UUID, locationId: UUID?, date: Date?) async throws -> [ZStockSheetRow] {
        let day = date.map(dateString)
        if let locationId, let day {
            return try await client
                .from("z_stock_sheets")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .eq("sheet_date", value: day)
                .eq("work_location_id", value: locationId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        if let locationId {
            return try await client
                .from("z_stock_sheets")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .eq("work_location_id", value: locationId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        if let day {
            return try await client
                .from("z_stock_sheets")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .eq("sheet_date", value: day)
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        return try await client
            .from("z_stock_sheets")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchZSheetLines(sheetId: UUID) async throws -> [ZStockSheetLine] {
        try await client
            .from("z_stock_sheet_lines")
            .select("*,products(cod)")
            .eq("sheet_id", value: sheetId.uuidString)
            .order("nr_crt", ascending: true)
            .execute()
            .value
    }

    static func fetchConsumptions(sheet: ZStockSheetRow) async throws -> [StockSheetConsumption] {
        guard let warehouseId = sheet.warehouseId else { return [] }
        let end = timestamp(sheet.createdAt)
        let previous: [SheetStamp] = try await client
            .from("z_stock_sheets")
            .select("created_at")
            .eq("work_location_id", value: sheet.workLocationId.uuidString)
            .lt("created_at", value: end)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        let newer: [SheetStamp] = try await client
            .from("z_stock_sheets")
            .select("created_at")
            .eq("work_location_id", value: sheet.workLocationId.uuidString)
            .gt("created_at", value: end)
            .limit(1)
            .execute()
            .value
        let latest = newer.isEmpty
        let start = previous.first.map { timestamp($0.createdAt) } ?? "1970-01-01T00:00:00Z"
        let moves: [SheetConsumptionMove] = try await client
            .from("stock_movements")
            .select("consumption_voucher_id")
            .eq("warehouse_id", value: warehouseId.uuidString)
            .eq("sursa", value: "consumption_voucher")
            .eq("tip", value: "iesire")
            .gt("created_at", value: start)
            .lte("created_at", value: end)
            .execute()
            .value
        let deducted = Set(moves.compactMap(\.consumptionVoucherId))
        let select = "id,numar,motiv,created_at,data_bon,shift_no,consumption_voucher_lines(aprobat,cantitate,unitate_masura,numar_linie,products(denumire))"
        let vouchers: [SheetConsumptionVoucher]
        if latest {
            vouchers = try await client
                .from("consumption_vouchers")
                .select(select)
                .eq("warehouse_id", value: warehouseId.uuidString)
                .gt("created_at", value: start)
                .order("created_at", ascending: true)
                .execute()
                .value
        } else {
            vouchers = try await client
                .from("consumption_vouchers")
                .select(select)
                .eq("warehouse_id", value: warehouseId.uuidString)
                .gt("created_at", value: start)
                .lte("created_at", value: end)
                .order("created_at", ascending: true)
                .execute()
                .value
        }
        let businessDay = displayedDay(sheet)
        let aimedRows: [SheetConsumptionVoucher] = try await client
            .from("consumption_vouchers")
            .select(select)
            .eq("warehouse_id", value: warehouseId.uuidString)
            .eq("shift_no", value: sheet.shiftNo)
            .eq("data_bon", value: businessDay)
            .execute()
            .value
        var byId = Dictionary(uniqueKeysWithValues: vouchers.map { ($0.id, $0) })
        for voucher in aimedRows {
            byId[voucher.id] = voucher
        }
        let missing = deducted.filter { byId[$0] == nil }
        if !missing.isEmpty {
            let extra: [SheetConsumptionVoucher] = try await client
                .from("consumption_vouchers")
                .select(select)
                .in("id", values: missing.map(\.uuidString))
                .execute()
                .value
            for voucher in extra {
                byId[voucher.id] = voucher
            }
        }
        let startDate = previous.first?.createdAt ?? Date(timeIntervalSince1970: 0)
        var rows: [StockSheetConsumption] = []
        for voucher in byId.values.sorted(by: { ($0.numar ?? "") < ($1.numar ?? "") }) {
            let inWindow = voucher.createdAt > startDate && voucher.createdAt <= sheet.createdAt
            let after = latest && voucher.createdAt > sheet.createdAt
            let hit = deducted.contains(voucher.id)
            let aimed = voucher.shiftNo == sheet.shiftNo && (voucher.dataBon ?? "").hasPrefix(businessDay)
            let legacy = voucher.shiftNo == nil && (inWindow || after || hit)
            guard aimed || legacy else { continue }
            let why = voucher.motiv.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            for line in voucher.lines.sorted(by: { $0.numarLinie < $1.numarLinie }) {
                if line.aprobat && !hit && !aimed { continue }
                if !line.aprobat && !inWindow && !after && !hit && !aimed { continue }
                rows.append(StockSheetConsumption(
                    approved: line.aprobat,
                    number: voucher.numar ?? "",
                    product: line.product?.denumire ?? "",
                    quantity: SupplierFormatting.stockQuantityString(line.cantitate),
                    unit: line.unitateMasura,
                    explanation: why
                ))
            }
        }
        return rows.sorted {
            if $0.approved != $1.approved { return $0.approved && !$1.approved }
            return $0.number < $1.number
        }
    }

    static func appendingGuarantee(_ lines: [ZStockSheetLine]) async throws -> [ZStockSheetLine] {
        let sold = lines.filter { $0.saleStoreQty != 0 || $0.saleOnlineQty != 0 }
        let addons = try await ProductSaleAddonService.fetchAddons(productIds: sold.map(\.productId))
        var totals: [String: (store: Decimal, online: Decimal)] = [:]
        for line in sold {
            for addon in addons[line.productId] ?? [] where addon.addon?.tip == .garantie {
                let count = addon.cantitate == 0 ? Decimal(1) : addon.cantitate
                let name = addon.addon?.denumire ?? "Garantie SGR"
                let store = line.saleStoreQty * count * (addon.addon?.pretVanzare ?? 0)
                let online = line.saleOnlineQty * count * (addon.addon?.pretVanzareOnline ?? 0)
                let current = totals[name] ?? (0, 0)
                totals[name] = (current.store + store, current.online + online)
            }
        }
        let extra = totals.compactMap { name, value -> ZStockSheetLine? in
            guard value.store != 0 || value.online != 0 else { return nil }
            return ZStockSheetLine(
                id: UUID(),
                productId: UUID(),
                category: "garantie",
                nrCrt: 1,
                denumire: name,
                unitateMasura: "",
                openingQty: 0,
                inflowQty: 0,
                transferOutQty: 0,
                recipeOutQty: 0,
                saleStoreQty: 0,
                saleOnlineQty: 0,
                priceStore: 0,
                priceOnline: 0,
                valueStore: value.store,
                valueOnline: value.online,
                profit: 0,
                closingQty: 0,
                mismatch: false,
                product: nil
            )
        }
        return lines + extra
    }

    private struct SheetStamp: Decodable {
        let createdAt: Date
        enum CodingKeys: String, CodingKey { case createdAt = "created_at" }
    }

    private struct SheetConsumptionMove: Decodable {
        let consumptionVoucherId: UUID?
        enum CodingKeys: String, CodingKey { case consumptionVoucherId = "consumption_voucher_id" }
    }

    private struct SheetConsumptionProduct: Decodable {
        let denumire: String
    }

    private struct SheetConsumptionLine: Decodable {
        let aprobat: Bool
        let cantitate: Decimal
        let unitateMasura: String
        let numarLinie: Int
        let product: SheetConsumptionProduct?

        enum CodingKeys: String, CodingKey {
            case aprobat, cantitate
            case unitateMasura = "unitate_masura"
            case numarLinie = "numar_linie"
            case product = "products"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            aprobat = try container.decode(Bool.self, forKey: .aprobat)
            cantitate = try container.decode(SupabaseDecimal.self, forKey: .cantitate).wrappedValue
            unitateMasura = try container.decodeIfPresent(String.self, forKey: .unitateMasura) ?? ""
            numarLinie = try container.decodeIfPresent(Int.self, forKey: .numarLinie) ?? 0
            product = try container.decodeIfPresent(SheetConsumptionProduct.self, forKey: .product)
        }
    }

    private struct SheetConsumptionVoucher: Decodable {
        let id: UUID
        let numar: String?
        let motiv: String
        let createdAt: Date
        let dataBon: String?
        let shiftNo: Int?
        let lines: [SheetConsumptionLine]

        enum CodingKeys: String, CodingKey {
            case id, numar, motiv
            case createdAt = "created_at"
            case dataBon = "data_bon"
            case shiftNo = "shift_no"
            case lines = "consumption_voucher_lines"
        }
    }

    private static func displayedDay(_ sheet: ZStockSheetRow) -> String {
        guard sheet.shiftNo == 2 else { return String(sheet.sheetDate.prefix(10)) }
        let parts = sheet.sheetDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return String(sheet.sheetDate.prefix(10))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        guard let date = calendar.date(from: comps),
              let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
            return String(sheet.sheetDate.prefix(10))
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: previous)
    }

    private static func timestamp(_ date: Date) -> String {
        stampFormatter.string(from: date)
    }

    private static let stampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func dateString(_ date: Date) -> String {
        SupabaseDecoding.dateOnlyString(from: date)
    }

    static func vatBands(sheetId: UUID) async throws -> PosSheetVatBands {
        let rows: [PosSheetVatBands] = try await client
            .rpc("pos_sheet_vat_bands", params: PosSheetVatParams(sheetId: sheetId))
            .execute()
            .value
        return rows.first ?? PosSheetVatBands()
    }

    static func vatBands(companyId: UUID, zNumber: Int) async throws -> PosSheetVatBands? {
        let rows: [PosSheetRef] = try await client
            .from("z_stock_sheets")
            .select("id,z_number")
            .eq("company_id", value: companyId.uuidString)
            .neq("z_number", value: "")
            .order("created_at", ascending: false)
            .limit(400)
            .execute()
            .value
        guard let sheet = rows.first(where: { Int($0.zNumber) == zNumber }) else { return nil }
        return try await vatBands(sheetId: sheet.id)
    }
}

struct PosSheetVatBands: Decodable, Sendable {
    var brut21: Decimal = 0
    var tva21: Decimal = 0
    var brut11: Decimal = 0
    var tva11: Decimal = 0
    var brut0: Decimal = 0
    var tva0: Decimal = 0

    enum CodingKeys: String, CodingKey {
        case brut21 = "brut_21"
        case tva21 = "tva_21"
        case brut11 = "brut_11"
        case tva11 = "tva_11"
        case brut0 = "brut_0"
        case tva0 = "tva_0"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        brut21 = try c.decode(SupabaseDecimal.self, forKey: .brut21).wrappedValue
        tva21 = try c.decode(SupabaseDecimal.self, forKey: .tva21).wrappedValue
        brut11 = try c.decode(SupabaseDecimal.self, forKey: .brut11).wrappedValue
        tva11 = try c.decode(SupabaseDecimal.self, forKey: .tva11).wrappedValue
        brut0 = try c.decode(SupabaseDecimal.self, forKey: .brut0).wrappedValue
        tva0 = try c.decode(SupabaseDecimal.self, forKey: .tva0).wrappedValue
    }
}

private struct PosSheetVatParams: Encodable {
    let sheetId: UUID
    enum CodingKeys: String, CodingKey { case sheetId = "p_sheet_id" }
}

private struct PosSheetRef: Decodable {
    let id: UUID
    let zNumber: String
    enum CodingKeys: String, CodingKey {
        case id
        case zNumber = "z_number"
    }
}

private struct UpsertInitialStockParams: Encodable {
    let pCompanyId: UUID
    let pDataTranzactie: String
    let pLines: [InitialStockLinePayload]

    enum CodingKeys: String, CodingKey {
        case pCompanyId = "p_company_id"
        case pDataTranzactie = "p_data_tranzactie"
        case pLines = "p_lines"
    }
}
