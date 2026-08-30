import Foundation
import Supabase

private struct WorkLocationInsert: Encodable {
    let companyId: UUID
    let denumire: String
    let country: String?
    let county: String?
    let city: String?
    let street: String?
    let streetNumber: String?
    let block: String?
    let stair: String?
    let floor: String?
    let apartment: String?
    let postalCode: String?
    let telefon: String?
    let telefonMobil: String?
    let gln: String?
    let isActive: Bool
    let isDefault: Bool
    let operatesAtHeadquarters: Bool
    let isFiscalDomicile: Bool
    let useInDeclarations: Bool

    enum CodingKeys: String, CodingKey {
        case denumire, country, county, city, street, block, stair, floor, apartment, telefon, gln
        case companyId = "company_id"
        case streetNumber = "street_number"
        case postalCode = "postal_code"
        case telefonMobil = "telefon_mobil"
        case isActive = "is_active"
        case isDefault = "is_default"
        case operatesAtHeadquarters = "operates_at_headquarters"
        case isFiscalDomicile = "is_fiscal_domicile"
        case useInDeclarations = "use_in_declarations"
    }

    init(from location: CompanyWorkLocation) {
        companyId = location.companyId
        denumire = location.denumire
        country = location.country
        county = location.county
        city = location.city
        street = location.street
        streetNumber = location.streetNumber
        block = location.block
        stair = location.stair
        floor = location.floor
        apartment = location.apartment
        postalCode = location.postalCode
        telefon = location.telefon
        telefonMobil = location.telefonMobil
        gln = location.gln
        isActive = location.isActive
        isDefault = location.isDefault
        operatesAtHeadquarters = location.operatesAtHeadquarters
        isFiscalDomicile = location.isFiscalDomicile
        useInDeclarations = location.useInDeclarations
    }
}

private struct WorkLocationUpdate: Encodable {
    let denumire: String
    let country: String?
    let county: String?
    let city: String?
    let street: String?
    let streetNumber: String?
    let block: String?
    let stair: String?
    let floor: String?
    let apartment: String?
    let postalCode: String?
    let telefon: String?
    let telefonMobil: String?
    let gln: String?
    let isActive: Bool
    let isDefault: Bool
    let operatesAtHeadquarters: Bool
    let isFiscalDomicile: Bool
    let useInDeclarations: Bool

    enum CodingKeys: String, CodingKey {
        case denumire, country, county, city, street, block, stair, floor, apartment, telefon, gln
        case streetNumber = "street_number"
        case postalCode = "postal_code"
        case telefonMobil = "telefon_mobil"
        case isActive = "is_active"
        case isDefault = "is_default"
        case operatesAtHeadquarters = "operates_at_headquarters"
        case isFiscalDomicile = "is_fiscal_domicile"
        case useInDeclarations = "use_in_declarations"
    }

    init(from location: CompanyWorkLocation) {
        denumire = location.denumire
        country = location.country
        county = location.county
        city = location.city
        street = location.street
        streetNumber = location.streetNumber
        block = location.block
        stair = location.stair
        floor = location.floor
        apartment = location.apartment
        postalCode = location.postalCode
        telefon = location.telefon
        telefonMobil = location.telefonMobil
        gln = location.gln
        isActive = location.isActive
        isDefault = location.isDefault
        operatesAtHeadquarters = location.operatesAtHeadquarters
        isFiscalDomicile = location.isFiscalDomicile
        useInDeclarations = location.useInDeclarations
    }
}

enum WorkLocationService {
    private static let client = SupabaseManager.client

    static func fetchWorkLocations(companyId: UUID) async throws -> [CompanyWorkLocation] {
        try await client
            .from("company_work_locations")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("denumire", ascending: true)
            .execute()
            .value
    }

    static func createWorkLocation(_ location: CompanyWorkLocation) async throws -> CompanyWorkLocation {
        let payload = WorkLocationInsert(from: location)
        let rows: [CompanyWorkLocation] = try await client
            .from("company_work_locations")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let created = rows.first else { throw ServiceError.invalidResponse }
        try await ensureWarehouse(for: created)
        return created
    }

    /// Creează automat un depozit de vânzare asociat punctului de lucru, dacă lipsește.
    static func ensureWarehouse(for location: CompanyWorkLocation) async throws {
        let warehouses = try await WarehouseService.fetchWarehouses(companyId: location.companyId)
        guard !warehouses.contains(where: { $0.workLocationId == location.id }) else { return }

        let cod = try await WarehouseService.suggestNextCod(companyId: location.companyId)
        let warehouse = CompanyWarehouse(
            id: UUID(),
            companyId: location.companyId,
            cod: cod,
            denumire: L10n.tr("module.nomenclatoare.warehouses.auto_name", location.denumire),
            warehouseType: .vanzare,
            workLocationId: location.id,
            partnerSupplierId: nil,
            partnerClientId: nil,
            isCustody: false,
            allowsStockReservation: false,
            isLohn: false,
            managerName: nil,
            adresa: nil,
            additionalInfo: nil,
            isActive: true,
            createdAt: nil,
            updatedAt: nil,
            workLocation: nil,
            partnerSupplier: nil,
            partnerClient: nil
        )
        _ = try await WarehouseService.createWarehouse(warehouse)
    }

    static func updateWorkLocation(_ location: CompanyWorkLocation) async throws -> CompanyWorkLocation {
        let payload = WorkLocationUpdate(from: location)
        let rows: [CompanyWorkLocation] = try await client
            .from("company_work_locations")
            .update(payload)
            .eq("id", value: location.id.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else { throw ServiceError.invalidResponse }
        return updated
    }

    static func deleteWorkLocation(id: UUID) async throws {
        try await client
            .from("company_work_locations")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
