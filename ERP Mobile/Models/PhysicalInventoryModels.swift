import Foundation

enum PhysicalInventoryStatus: String, Codable, CaseIterable, Sendable {
    case open
    case finalized
    case cancelled

    var label: String {
        switch self {
        case .open: return L10n.tr("inventory.physical_status_open")
        case .finalized: return L10n.tr("inventory.physical_status_finalized")
        case .cancelled: return L10n.tr("inventory.physical_status_cancelled")
        }
    }

    var isEditable: Bool { self == .open }
}

struct PhysicalInventory: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let numarInventar: String
    let dataInventar: Date
    let status: PhysicalInventoryStatus
    let observatii: String?
    let warehouseId: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    let finalizedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, observatii
        case companyId = "company_id"
        case numarInventar = "numar_inventar"
        case dataInventar = "data_inventar"
        case warehouseId = "warehouse_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case finalizedAt = "finalized_at"
    }
}

struct PhysicalInventoryProductRef: Codable, Hashable, Sendable {
    let id: UUID
    let denumire: String
    let cod: String?
    let codBare: String?
    let unitateMasura: String

    enum CodingKeys: String, CodingKey {
        case id, denumire, cod
        case codBare = "cod_bare"
        case unitateMasura = "unitate_masura"
    }
}

struct PhysicalInventoryLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let inventoryId: UUID
    let companyId: UUID
    let productId: UUID
    let stocScriptic: Decimal
    let cantitateNumarata: Decimal?
    let unitateMasura: String
    let observatii: String?
    let product: PhysicalInventoryProductRef?

    enum CodingKeys: String, CodingKey {
        case id, product, observatii
        case inventoryId = "inventory_id"
        case companyId = "company_id"
        case productId = "product_id"
        case stocScriptic = "stoc_scriptic"
        case cantitateNumarata = "cantitate_numarata"
        case unitateMasura = "unitate_masura"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inventoryId = try container.decode(UUID.self, forKey: .inventoryId)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        productId = try container.decode(UUID.self, forKey: .productId)
        stocScriptic = try container.decode(SupabaseDecimal.self, forKey: .stocScriptic).wrappedValue
        if container.contains(.cantitateNumarata) {
            if try container.decodeNil(forKey: .cantitateNumarata) {
                cantitateNumarata = nil
            } else {
                cantitateNumarata = try container.decode(SupabaseDecimal.self, forKey: .cantitateNumarata).wrappedValue
            }
        } else {
            cantitateNumarata = nil
        }
        unitateMasura = try container.decode(String.self, forKey: .unitateMasura)
        observatii = try container.decodeIfPresent(String.self, forKey: .observatii)
        product = try container.decodeIfPresent(PhysicalInventoryProductRef.self, forKey: .product)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(inventoryId, forKey: .inventoryId)
        try container.encode(companyId, forKey: .companyId)
        try container.encode(productId, forKey: .productId)
        try container.encode(SupabaseDecimal(wrappedValue: stocScriptic), forKey: .stocScriptic)
        if let cantitateNumarata {
            try container.encode(SupabaseDecimal(wrappedValue: cantitateNumarata), forKey: .cantitateNumarata)
        } else {
            try container.encodeNil(forKey: .cantitateNumarata)
        }
        try container.encode(unitateMasura, forKey: .unitateMasura)
        try container.encodeIfPresent(observatii, forKey: .observatii)
        try container.encodeIfPresent(product, forKey: .product)
    }

    var diferenta: Decimal? {
        guard let cantitateNumarata else { return nil }
        return cantitateNumarata - stocScriptic
    }

    var isCounted: Bool { cantitateNumarata != nil }

    var hasDifference: Bool {
        guard let diferenta else { return false }
        return diferenta != 0
    }

    var productName: String {
        product?.denumire ?? L10n.tr("inventory.unknown_product")
    }
}

struct PhysicalInventorySummary: Sendable {
    let totalLines: Int
    let countedLines: Int
    let differenceLines: Int
    let plusDifference: Decimal
    let minusDifference: Decimal

    static func build(from lines: [PhysicalInventoryLine]) -> PhysicalInventorySummary {
        var counted = 0
        var differences = 0
        var plus: Decimal = 0
        var minus: Decimal = 0

        for line in lines {
            guard let delta = line.diferenta else { continue }
            counted += 1
            if delta == 0 { continue }
            differences += 1
            if delta > 0 {
                plus += delta
            } else {
                minus += abs(delta)
            }
        }

        return PhysicalInventorySummary(
            totalLines: lines.count,
            countedLines: counted,
            differenceLines: differences,
            plusDifference: plus,
            minusDifference: minus
        )
    }
}

struct PhysicalInventoryContext: Identifiable, Sendable {
    let inventory: PhysicalInventory
    let access: ModuleAccessRights

    var id: UUID { inventory.id }
}

enum PhysicalInventoryLineFilter: String, CaseIterable, Identifiable {
    case all
    case uncounted
    case differences

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return L10n.tr("inventory.physical_filter_all")
        case .uncounted: return L10n.tr("inventory.physical_filter_uncounted")
        case .differences: return L10n.tr("inventory.physical_filter_differences")
        }
    }

    func matches(_ line: PhysicalInventoryLine) -> Bool {
        switch self {
        case .all: return true
        case .uncounted: return !line.isCounted
        case .differences: return line.hasDifference
        }
    }
}

enum PhysicalInventoryError: LocalizedError {
    case notFound
    case notOpen
    case noCountedLines
    case forbidden
    case invalidQuantity

    var errorDescription: String? {
        switch self {
        case .notFound: return L10n.tr("inventory.physical_error_not_found")
        case .notOpen: return L10n.tr("inventory.physical_error_not_open")
        case .noCountedLines: return L10n.tr("inventory.physical_error_no_counted_lines")
        case .forbidden: return L10n.tr("inventory.physical_error_forbidden")
        case .invalidQuantity: return L10n.tr("inventory.physical_error_invalid_quantity")
        }
    }

    static func map(_ error: Error) -> Error {
        let message = error.localizedDescription.uppercased()
        if message.contains("INVENTORY_NOT_FOUND") { return PhysicalInventoryError.notFound }
        if message.contains("INVENTORY_NOT_OPEN") { return PhysicalInventoryError.notOpen }
        if message.contains("INVENTORY_NO_COUNTED_LINES") { return PhysicalInventoryError.noCountedLines }
        if message.contains("FORBIDDEN") { return PhysicalInventoryError.forbidden }
        if message.contains("INVALID_COUNTED_QUANTITY") { return PhysicalInventoryError.invalidQuantity }
        return error
    }
}

struct InventoryDifferenceReport: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let inventoryId: UUID
    let warehouseId: UUID?
    let numar: String
    let dataOra: Date

    enum CodingKeys: String, CodingKey {
        case id, numar
        case companyId = "company_id"
        case inventoryId = "inventory_id"
        case warehouseId = "warehouse_id"
        case dataOra = "data_ora"
    }
}

struct InventoryDifferenceReportLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let reportId: UUID
    let productId: UUID
    let denumire: String
    let unitateMasura: String
    @SupabaseDecimal var stocScriptic: Decimal
    @SupabaseDecimal var cantitateFaptica: Decimal
    @SupabaseDecimal var diferenta: Decimal

    enum CodingKeys: String, CodingKey {
        case id, denumire, diferenta
        case reportId = "report_id"
        case productId = "product_id"
        case unitateMasura = "unitate_masura"
        case stocScriptic = "stoc_scriptic"
        case cantitateFaptica = "cantitate_faptica"
    }
}
