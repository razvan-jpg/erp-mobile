import Foundation
import Supabase

enum InventoryService {
    private static let client = SupabaseManager.client

    private struct WarehouseIdParams: Encodable {
        let pWarehouseId: UUID

        enum CodingKeys: String, CodingKey {
            case pWarehouseId = "p_warehouse_id"
        }
    }

    /// Superadmin: golește stocul pe gestiune (mișcări + warehouse + product_stocks).
    static func zeroWarehouseStock(warehouseId: UUID) async throws -> Int {
        do {
            let count: Int = try await client
                .rpc("zero_warehouse_stock", params: WarehouseIdParams(pWarehouseId: warehouseId))
                .execute()
                .value
            return count
        } catch {
            let message = error.localizedDescription.uppercased()
            if message.contains("SUPERADMIN_REQUIRED") {
                throw InventoryAdminError.superadminRequired
            }
            if message.contains("WAREHOUSE_NOT_FOUND") {
                throw InventoryAdminError.warehouseNotFound
            }
            throw error
        }
    }

    private static let stockProductSelect =
        "id, denumire, cod, cod_bare, unitate_masura, tip, cantitate_minima"

    static func fetchStockRows(companyId: UUID, warehouseId: UUID? = nil) async throws -> [ProductStockRow] {
        if let warehouseId {
            return try await client
                .from("warehouse_product_stocks")
                .select("company_id, warehouse_id, product_id, cantitate, updated_at, product:products(\(stockProductSelect))")
                .eq("company_id", value: companyId.uuidString)
                .eq("warehouse_id", value: warehouseId.uuidString)
                .order("updated_at", ascending: false)
                .execute()
                .value
        }
        return try await client
            .from("product_stocks")
            .select("company_id, product_id, cantitate, updated_at, product:products(\(stockProductSelect))")
            .eq("company_id", value: companyId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    /// Necesar de comandat: doar articole cu stoc minim completat pe fișă;
    /// apar dacă stocul curent < minim (inclusiv stoc negativ sau lipsă = 0).
    static func fetchReorderNeededRows(
        companyId: UUID,
        warehouseId: UUID? = nil,
        warehouses: [CompanyWarehouse] = []
    ) async throws -> [StockReorderRow] {
        struct MinProductRow: Decodable, Sendable {
            let id: UUID
            let denumire: String
            let cod: String?
            let unitateMasura: String
            let tip: ProductKind
            @SupabaseDecimal var cantitateMinima: Decimal
            @SupabaseDecimal var cantitateOptima: Decimal

            enum CodingKeys: String, CodingKey {
                case id, denumire, cod, tip
                case unitateMasura = "unitate_masura"
                case cantitateMinima = "cantitate_minima"
                case cantitateOptima = "cantitate_optima"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(UUID.self, forKey: .id)
                denumire = try container.decode(String.self, forKey: .denumire)
                cod = try container.decodeIfPresent(String.self, forKey: .cod)
                unitateMasura = try container.decode(String.self, forKey: .unitateMasura)
                tip = try container.decode(ProductKind.self, forKey: .tip)
                _cantitateMinima = try container.decode(SupabaseDecimal.self, forKey: .cantitateMinima)
                if let optimal = try container.decodeIfPresent(SupabaseDecimal.self, forKey: .cantitateOptima) {
                    _cantitateOptima = optimal
                } else {
                    _cantitateOptima = SupabaseDecimal(wrappedValue: 0)
                }
            }
        }

        var products: [MinProductRow] = []
        var productFrom = 0
        while true {
            let page: [MinProductRow] = try await client
                .from("products")
                .select("id, denumire, cod, unitate_masura, tip, cantitate_minima, cantitate_optima")
                .eq("company_id", value: companyId.uuidString)
                .eq("is_active", value: true)
                .gt("cantitate_minima", value: 0)
                .neq("tip", value: ProductKind.produsFinit.rawValue)
                .neq("tip", value: ProductKind.birotica.rawValue)
                .order("denumire", ascending: true)
                .range(from: productFrom, to: productFrom + 999)
                .execute()
                .value
            products.append(contentsOf: page)
            if page.count < 1000 { break }
            productFrom += 1000
        }

        guard !products.isEmpty else { return [] }

        let qtyByProduct = try await fetchReorderStockPages(companyId: companyId, warehouseId: warehouseId)
        let warehouseName: String = {
            if let warehouseId {
                return warehouses.first { $0.id == warehouseId }?.denumire
                    ?? L10n.tr("inventory.field_warehouse")
            }
            return L10n.tr("inventory.warehouse_all")
        }()

        return products.compactMap { product in
            // Fără rând de stoc = 0; stoc negativ tot intră dacă e sub minim (nu filtrăm current > 0).
            let current = qtyByProduct[product.id] ?? 0
            guard current < product.cantitateMinima else { return nil }
            return StockReorderRow(
                productId: product.id,
                denumire: product.denumire,
                cod: product.cod,
                unitateMasura: product.unitateMasura,
                tip: product.tip,
                warehouseId: warehouseId,
                warehouseName: warehouseName,
                cantitateCurenta: current,
                cantitateMinima: product.cantitateMinima,
                cantitateOptima: product.cantitateOptima,
                cantitateNecesara: max(0, product.cantitateOptima - current)
            )
        }
    }

    /// Căutare pentru adăugare manuală, inclusiv birotică. Fără produs finit.
    static func searchReorderRows(
        companyId: UUID,
        warehouseId: UUID? = nil,
        warehouses: [CompanyWarehouse] = [],
        query: String
    ) async throws -> [StockReorderRow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else { return [] }
        let safe = trimmed
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ",", with: " ")
        guard !safe.isEmpty else { return [] }

        struct MinProductRow: Decodable, Sendable {
            let id: UUID
            let denumire: String
            let cod: String?
            let unitateMasura: String
            let tip: ProductKind
            @SupabaseDecimal var cantitateMinima: Decimal
            @SupabaseDecimal var cantitateOptima: Decimal

            enum CodingKeys: String, CodingKey {
                case id, denumire, cod, tip
                case unitateMasura = "unitate_masura"
                case cantitateMinima = "cantitate_minima"
                case cantitateOptima = "cantitate_optima"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(UUID.self, forKey: .id)
                denumire = try container.decode(String.self, forKey: .denumire)
                cod = try container.decodeIfPresent(String.self, forKey: .cod)
                unitateMasura = try container.decode(String.self, forKey: .unitateMasura)
                tip = try container.decode(ProductKind.self, forKey: .tip)
                _cantitateMinima = try container.decodeIfPresent(SupabaseDecimal.self, forKey: .cantitateMinima)
                    ?? SupabaseDecimal(wrappedValue: 0)
                _cantitateOptima = try container.decodeIfPresent(SupabaseDecimal.self, forKey: .cantitateOptima)
                    ?? SupabaseDecimal(wrappedValue: 0)
            }
        }

        func page(_ column: String) async throws -> [MinProductRow] {
            try await client
                .from("products")
                .select("id, denumire, cod, unitate_masura, tip, cantitate_minima, cantitate_optima")
                .eq("company_id", value: companyId.uuidString)
                .eq("is_active", value: true)
                .neq("tip", value: ProductKind.produsFinit.rawValue)
                .ilike(column, pattern: "%\(safe)%")
                .order("denumire", ascending: true)
                .limit(40)
                .execute()
                .value
        }

        var products = try await page("denumire")
        let byCode = try await page("cod")
        var seen = Set(products.map(\.id))
        for product in byCode where seen.insert(product.id).inserted {
            products.append(product)
        }
        guard !products.isEmpty else { return [] }

        let qtyByProduct = try await fetchStockQuantities(
            companyId: companyId,
            warehouseId: warehouseId,
            productIds: products.map(\.id)
        )
        let warehouseName: String = {
            if let warehouseId {
                return warehouses.first { $0.id == warehouseId }?.denumire
                    ?? L10n.tr("inventory.field_warehouse")
            }
            return L10n.tr("inventory.warehouse_all")
        }()
        return products.map { product in
            let current = qtyByProduct[product.id] ?? 0
            return StockReorderRow(
                productId: product.id,
                denumire: product.denumire,
                cod: product.cod,
                unitateMasura: product.unitateMasura,
                tip: product.tip,
                warehouseId: warehouseId,
                warehouseName: warehouseName,
                cantitateCurenta: current,
                cantitateMinima: product.cantitateMinima,
                cantitateOptima: product.cantitateOptima,
                cantitateNecesara: max(0, product.cantitateOptima - current)
            )
        }
    }

    private static func fetchReorderStockPages(companyId: UUID, warehouseId: UUID?) async throws -> [UUID: Decimal] {
        struct QtyRow: Decodable {
            let productId: UUID
            @SupabaseDecimal var cantitate: Decimal

            enum CodingKeys: String, CodingKey {
                case cantitate
                case productId = "product_id"
            }
        }

        var quantities: [UUID: Decimal] = [:]
        var from = 0
        while true {
            let page: [QtyRow]
            if let warehouseId {
                page = try await client
                    .from("warehouse_product_stocks")
                    .select("product_id, cantitate")
                    .eq("company_id", value: companyId.uuidString)
                    .eq("warehouse_id", value: warehouseId.uuidString)
                    .range(from: from, to: from + 999)
                    .execute()
                    .value
            } else {
                page = try await client
                    .from("product_stocks")
                    .select("product_id, cantitate")
                    .eq("company_id", value: companyId.uuidString)
                    .range(from: from, to: from + 999)
                    .execute()
                    .value
            }
            for row in page {
                quantities[row.productId] = row.cantitate
            }
            if page.count < 1000 { break }
            from += 1000
        }
        return quantities
    }

    private static func fetchStockQuantities(companyId: UUID, warehouseId: UUID?, productIds: [UUID]) async throws -> [UUID: Decimal] {
        struct QtyRow: Decodable {
            let productId: UUID
            @SupabaseDecimal var cantitate: Decimal

            enum CodingKeys: String, CodingKey {
                case cantitate
                case productId = "product_id"
            }
        }

        var quantities: [UUID: Decimal] = [:]
        let ids = Array(Set(productIds))
        guard !ids.isEmpty else { return quantities }
        for chunk in ids.chunked(into: 150) {
            let page: [QtyRow]
            if let warehouseId {
                page = try await client
                    .from("warehouse_product_stocks")
                    .select("product_id, cantitate")
                    .eq("company_id", value: companyId.uuidString)
                    .eq("warehouse_id", value: warehouseId.uuidString)
                    .in("product_id", values: chunk.map(\.uuidString))
                    .execute()
                    .value
            } else {
                page = try await client
                    .from("product_stocks")
                    .select("product_id, cantitate")
                    .eq("company_id", value: companyId.uuidString)
                    .in("product_id", values: chunk.map(\.uuidString))
                    .execute()
                    .value
            }
            for row in page {
                quantities[row.productId] = row.cantitate
            }
        }
        return quantities
    }

    /// Stoc pe punct de lucru (ex. Agronomie, Ploiești): sumă gestiuni active legate de locație.
    /// Folosește denumirile din `company_work_locations`, nu canalele de preț In Store / On Line.
    static func fetchLocationStocksByProduct(
        companyId: UUID,
        productIds: [UUID] = []
    ) async throws -> [UUID: [ProductLocationStock]] {
        let locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
            .filter(\.isActive)
            .sorted {
                $0.denumire.localizedCaseInsensitiveCompare($1.denumire) == .orderedAscending
            }
        guard !locations.isEmpty else { return [:] }

        let warehouses = try await WarehouseService.fetchWarehouses(companyId: companyId)
            .filter(\.isActive)
        let locationIdByWarehouseId: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: warehouses.compactMap { warehouse in
                guard let locationId = warehouse.workLocationId else { return nil }
                return (warehouse.id, locationId)
            }
        )
        guard !locationIdByWarehouseId.isEmpty else { return [:] }

        let stockRows: [WarehouseStockQuantityRow] = try await client
            .from("warehouse_product_stocks")
            .select("product_id, warehouse_id, cantitate")
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value

        var qtyByProductLoc: [UUID: [UUID: Decimal]] = [:]
        for row in stockRows {
            guard let locationId = locationIdByWarehouseId[row.warehouseId] else { continue }
            qtyByProductLoc[row.productId, default: [:]][locationId, default: 0] += row.cantitate
        }

        let ids = productIds.isEmpty ? Array(qtyByProductLoc.keys) : productIds
        var result: [UUID: [ProductLocationStock]] = [:]
        for productId in ids {
            result[productId] = locations.map { location in
                ProductLocationStock(
                    locationKey: location.id.uuidString,
                    locationName: location.denumire,
                    quantity: qtyByProductLoc[productId]?[location.id] ?? 0
                )
            }
        }
        return result
    }

    static func fetchMovements(companyId: UUID, limit: Int = 200) async throws -> [StockMovementRow] {
        try await client
            .from("stock_movements")
            .select("id, company_id, product_id, tip, cantitate, unitate_masura, sursa, referinta, data_tranzactie, created_at, product:products(denumire, cod, cod_bare)")
            .eq("company_id", value: companyId.uuidString)
            .order("data_tranzactie", ascending: false)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchProductMovements(companyId: UUID, productId: UUID) async throws -> [StockMovementDetailRow] {
        try await client
            .from("stock_movements")
            .select("""
                id, company_id, product_id, tip, cantitate, unitate_masura, sursa, referinta, data_tranzactie, created_at, invoice_id, invoice_line_id, warehouse_id, pret_unitar,
                invoice:supplier_invoices(numar_factura, data_factura),
                invoice_line:supplier_invoice_lines(pret_unitar, suma_linie, suma_tva, cota_tva)
                """)
            .eq("company_id", value: companyId.uuidString)
            .eq("product_id", value: productId.uuidString)
            .order("data_tranzactie", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func fetchProductMovements(companyId: UUID, productIds: [UUID]) async throws -> [StockMovementDetailRow] {
        let uniqueIds = Array(Set(productIds))
        guard !uniqueIds.isEmpty else { return [] }

        var all: [StockMovementDetailRow] = []
        for chunk in stride(from: 0, to: uniqueIds.count, by: 80) {
            let slice = uniqueIds[chunk..<min(chunk + 80, uniqueIds.count)]
            let rows: [StockMovementDetailRow] = try await client
                .from("stock_movements")
                .select("""
                    id, company_id, product_id, tip, cantitate, unitate_masura, sursa, referinta, data_tranzactie, created_at, invoice_id, invoice_line_id, warehouse_id, pret_unitar,
                    invoice:supplier_invoices(numar_factura, data_factura),
                    invoice_line:supplier_invoice_lines(pret_unitar, suma_linie, suma_tva, cota_tva)
                    """)
                .eq("company_id", value: companyId.uuidString)
                .in("product_id", values: slice.map(\.uuidString))
                .order("data_tranzactie", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            all.append(contentsOf: rows)
        }
        return all
    }

    /// Ultimul preț de cumpărare cu TVA, pe unitatea de stoc.
    /// Preferă recepția NIR; dacă factura este mai nouă, folosește factura și factorul de conversie.
    static func fetchLatestGrossPurchasePrices(companyId: UUID, productIds: [UUID]) async throws -> [UUID: Decimal] {
        let uniqueIds = Array(Set(productIds))
        guard !uniqueIds.isEmpty else { return [:] }

        struct FactorRow: Decodable {
            let id: UUID
            @SupabaseDecimal var factorConversie: Decimal

            enum CodingKeys: String, CodingKey {
                case id
                case factorConversie = "factor_conversie"
            }
        }

        struct NirPriceRow: Decodable {
            let productId: UUID
            @SupabaseDecimal var cantitate: Decimal
            @SupabaseDecimal var sumaLinie: Decimal
            @SupabaseDecimal var sumaTva: Decimal
            let createdAt: String?
            let nir: NirStamp

            struct NirStamp: Decodable {
                let dataNir: String
                enum CodingKeys: String, CodingKey { case dataNir = "data_nir" }
            }

            enum CodingKeys: String, CodingKey {
                case cantitate
                case productId = "product_id"
                case sumaLinie = "suma_linie"
                case sumaTva = "suma_tva"
                case createdAt = "created_at"
                case nir = "supplier_nirs"
            }
        }

        struct InvoicePriceRow: Decodable {
            let productId: UUID
            @SupabaseDecimal var cantitate: Decimal
            @SupabaseDecimal var sumaLinie: Decimal
            @SupabaseDecimal var sumaTva: Decimal
            let createdAt: String?
            let invoice: InvoiceStamp

            struct InvoiceStamp: Decodable {
                let dataFactura: String
                enum CodingKeys: String, CodingKey { case dataFactura = "data_factura" }
            }

            enum CodingKeys: String, CodingKey {
                case cantitate
                case productId = "product_id"
                case sumaLinie = "suma_linie"
                case sumaTva = "suma_tva"
                case createdAt = "created_at"
                case invoice = "supplier_invoices"
            }
        }

        var factors: [UUID: Decimal] = [:]
        var best: [UUID: (date: String, created: String, price: Decimal)] = [:]

        func keep(productId: UUID, date: String, created: String, price: Decimal) {
            let rounded = SupplierFormatting.roundAmount(price)
            guard rounded > 0 else { return }
            if let current = best[productId] {
                if date < current.date { return }
                if date == current.date, created <= current.created { return }
            }
            best[productId] = (date, created, rounded)
        }

        for chunk in stride(from: 0, to: uniqueIds.count, by: 60) {
            let slice = uniqueIds[chunk..<min(chunk + 60, uniqueIds.count)].map(\.uuidString)
            var factorFrom = 0
            while true {
                let page: [FactorRow] = try await client
                    .from("products")
                    .select("id, factor_conversie")
                    .in("id", values: slice)
                    .range(from: factorFrom, to: factorFrom + 999)
                    .execute()
                    .value
                for row in page {
                    factors[row.id] = row.factorConversie > 0 ? row.factorConversie : 1
                }
                if page.count < 1000 { break }
                factorFrom += 1000
            }

            var nirFrom = 0
            while true {
                let page: [NirPriceRow] = try await client
                    .from("supplier_nir_lines")
                    .select("product_id, cantitate, suma_linie, suma_tva, created_at, supplier_nirs!inner(data_nir)")
                    .eq("company_id", value: companyId.uuidString)
                    .in("product_id", values: slice)
                    .gt("suma_linie", value: 0)
                    .range(from: nirFrom, to: nirFrom + 999)
                    .execute()
                    .value
                for row in page where row.cantitate > 0 {
                    keep(
                        productId: row.productId,
                        date: row.nir.dataNir,
                        created: row.createdAt ?? "",
                        price: (row.sumaLinie + row.sumaTva) / row.cantitate
                    )
                }
                if page.count < 1000 { break }
                nirFrom += 1000
            }

            var invoiceFrom = 0
            while true {
                let page: [InvoicePriceRow] = try await client
                    .from("supplier_invoice_lines")
                    .select("product_id, cantitate, suma_linie, suma_tva, created_at, supplier_invoices!inner(data_factura)")
                    .eq("company_id", value: companyId.uuidString)
                    .in("product_id", values: slice)
                    .gt("suma_linie", value: 0)
                    .range(from: invoiceFrom, to: invoiceFrom + 999)
                    .execute()
                    .value
                for row in page where row.cantitate > 0 {
                    let factor = factors[row.productId] ?? 1
                    let stockQty = row.cantitate * (factor > 0 ? factor : 1)
                    guard stockQty > 0 else { continue }
                    keep(
                        productId: row.productId,
                        date: row.invoice.dataFactura,
                        created: row.createdAt ?? "",
                        price: (row.sumaLinie + row.sumaTva) / stockQty
                    )
                }
                if page.count < 1000 { break }
                invoiceFrom += 1000
            }
        }

        return best.mapValues(\.price)
    }
}

enum InventoryAdminError: LocalizedError {
    case superadminRequired
    case warehouseNotFound

    var errorDescription: String? {
        switch self {
        case .superadminRequired:
            return L10n.tr("inventory.zero_stock_error_superadmin")
        case .warehouseNotFound:
            return L10n.tr("inventory.zero_stock_error_warehouse")
        }
    }
}

