import Foundation

enum WarehouseType: String, Codable, CaseIterable, Identifiable, Sendable {
    case enDetail = "en_detail"
    case enGros = "en_gros"
    case productie = "productie"
    case materiiPrime = "materii_prime"
    case custodie = "custodie"
    case vanzare = "vanzare"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .enDetail: return L10n.tr("module.nomenclatoare.warehouses.type_en_detail")
        case .enGros: return L10n.tr("module.nomenclatoare.warehouses.type_en_gros")
        case .productie: return L10n.tr("module.nomenclatoare.warehouses.type_productie")
        case .materiiPrime: return L10n.tr("module.nomenclatoare.warehouses.type_materii_prime")
        case .custodie: return L10n.tr("module.nomenclatoare.warehouses.type_custodie")
        case .vanzare: return L10n.tr("module.nomenclatoare.warehouses.type_vanzare")
        }
    }
}

struct CompanyWarehouse: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var cod: String
    var denumire: String
    var warehouseType: WarehouseType
    var workLocationId: UUID?
    var partnerSupplierId: UUID?
    var partnerClientId: UUID?
    var isCustody: Bool
    var allowsStockReservation: Bool
    var isLohn: Bool
    var managerName: String?
    var adresa: String?
    var additionalInfo: String?
    var isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?
    var workLocation: WarehouseWorkLocationRef?
    var partnerSupplier: WarehousePartnerRef?
    var partnerClient: WarehousePartnerRef?

    enum CodingKeys: String, CodingKey {
        case id, cod, denumire, adresa
        case companyId = "company_id"
        case warehouseType = "warehouse_type"
        case workLocationId = "work_location_id"
        case partnerSupplierId = "partner_supplier_id"
        case partnerClientId = "partner_client_id"
        case isCustody = "is_custody"
        case allowsStockReservation = "allows_stock_reservation"
        case isLohn = "is_lohn"
        case managerName = "manager_name"
        case additionalInfo = "additional_info"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case workLocation = "work_location"
        case partnerSupplier = "partner_supplier"
        case partnerClient = "partner_client"
    }

    var workLocationName: String {
        workLocation?.denumire ?? "—"
    }

    var partnerName: String {
        partnerSupplier?.denumire ?? partnerClient?.denumire ?? "—"
    }

    var displaySubtitle: String {
        [cod, warehouseType.label, workLocationName]
            .filter { !$0.isEmpty && $0 != "—" }
            .joined(separator: " · ")
    }
}

struct WarehouseWorkLocationRef: Codable, Hashable, Sendable {
    let denumire: String
}

struct WarehousePartnerRef: Codable, Hashable, Sendable {
    let denumire: String
}

enum WarehousePartnerLink: Hashable, Identifiable, Sendable {
    case none
    case supplier(UUID, name: String)
    case client(UUID, name: String)

    var id: String {
        switch self {
        case .none: return "none"
        case .supplier(let id, _): return "supplier:\(id.uuidString)"
        case .client(let id, _): return "client:\(id.uuidString)"
        }
    }

    var label: String {
        switch self {
        case .none: return L10n.tr("common.select")
        case .supplier(_, let name), .client(_, let name): return name
        }
    }

    static func from(warehouse: CompanyWarehouse) -> WarehousePartnerLink {
        if let supplierId = warehouse.partnerSupplierId {
            return .supplier(supplierId, name: warehouse.partnerSupplier?.denumire ?? "—")
        }
        if let clientId = warehouse.partnerClientId {
            return .client(clientId, name: warehouse.partnerClient?.denumire ?? "—")
        }
        return .none
    }

    static func options(from partners: [PartnerListRow]) -> [WarehousePartnerLink] {
        var result: [WarehousePartnerLink] = [.none]
        for partner in partners {
            switch partner.role {
            case .supplierOnly, .both:
                if let supplierId = partner.supplierRow?.supplier.id {
                    result.append(.supplier(supplierId, name: partner.denumire))
                }
            case .clientOnly:
                if let clientId = partner.clientRow?.client.id {
                    result.append(.client(clientId, name: partner.denumire))
                }
            }
        }
        return result
    }
}
