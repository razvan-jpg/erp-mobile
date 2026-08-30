import Foundation
import Supabase

enum CRMExtendedService {
    private static let client = SupabaseManager.client

    // MARK: - CRM Companies

    static func fetchCRMCompanies(companyId: UUID? = nil) async throws -> [CRMCompany] {
        var query = client.from("crm_companies").select()
        if let companyId {
            query = query.eq("company_id", value: companyId.uuidString)
        }
        return try await query.order("name").execute().value
    }

    /// Companii CRM pentru societatea ERP activă (inclusiv sincronizate din clienți).
    static func fetchCRMCompaniesFromERP(companyId: UUID? = nil) async throws -> [CRMCompany] {
        try await fetchCRMCompanies(companyId: companyId)
    }

    static func createCRMCompany(
        companyId: UUID,
        name: String,
        cui: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        website: String? = nil,
        address: String? = nil,
        industry: String? = nil,
        notes: String? = nil,
        clientId: UUID? = nil,
        assignedTo: UUID? = nil,
        createdBy: UUID?
    ) async throws -> CRMCompany {
        struct Payload: Encodable {
            let companyId: UUID
            let name: String
            let cui, email, phone, website, address, industry, notes: String?
            let clientId: UUID?
            let assignedTo: UUID?
            let createdBy: UUID?
            enum CodingKeys: String, CodingKey {
                case name, cui, email, phone, website, address, industry, notes
                case companyId = "company_id"
                case clientId = "client_id"
                case assignedTo = "assigned_to"
                case createdBy = "created_by"
            }
        }
        let payload = Payload(
            companyId: companyId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            cui: trimmed(cui), email: trimmed(email), phone: trimmed(phone),
            website: trimmed(website), address: trimmed(address), industry: trimmed(industry),
            notes: trimmed(notes), clientId: clientId, assignedTo: assignedTo, createdBy: createdBy
        )
        let company: CRMCompany = try await client
            .from("crm_companies")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return company
    }

    static func updateCRMCompany(_ item: CRMCompany) async throws {
        struct Payload: Encodable {
            let name: String
            let cui, email, phone, website, address, industry, notes: String?
            let clientId: UUID?
            let assignedTo: UUID?
            enum CodingKeys: String, CodingKey {
                case name, cui, email, phone, website, address, industry, notes
                case clientId = "client_id"
                case assignedTo = "assigned_to"
            }
        }
        let payload = Payload(
            name: item.name, cui: trimmed(item.cui), email: trimmed(item.email),
            phone: trimmed(item.phone), website: trimmed(item.website), address: trimmed(item.address),
            industry: trimmed(item.industry), notes: trimmed(item.notes),
            clientId: item.clientId, assignedTo: item.assignedTo
        )
        try await client.from("crm_companies").update(payload).eq("id", value: item.id.uuidString).execute()
    }

    static func deleteCRMCompany(id: UUID) async throws {
        try await client.from("crm_companies").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - CRM Contacts

    static func fetchCRMContacts(companyId: UUID? = nil, crmCompanyId: UUID? = nil) async throws -> [CRMContact] {
        var query = client.from("crm_contacts").select()
        if let companyId {
            query = query.eq("company_id", value: companyId.uuidString)
        }
        if let crmCompanyId {
            query = query.eq("crm_company_id", value: crmCompanyId.uuidString)
        }
        return try await query.order("last_name").order("first_name").execute().value
    }

    /// Contacte CRM pentru societatea ERP activă (inclusiv sincronizate din clienți).
    static func fetchCRMContactsFromERP(companyId: UUID? = nil, crmCompanyId: UUID? = nil) async throws -> [CRMContact] {
        try await fetchCRMContacts(companyId: companyId, crmCompanyId: crmCompanyId)
    }

    static func createCRMContact(
        companyId: UUID,
        firstName: String,
        lastName: String,
        crmCompanyId: UUID? = nil,
        email: String? = nil,
        phone: String? = nil,
        position: String? = nil,
        notes: String? = nil,
        clientId: UUID? = nil,
        assignedTo: UUID? = nil,
        createdBy: UUID?
    ) async throws -> CRMContact {
        struct Payload: Encodable {
            let companyId: UUID
            let firstName, lastName: String
            let crmCompanyId: UUID?
            let email, phone, position, notes: String?
            let clientId: UUID?
            let assignedTo: UUID?
            let createdBy: UUID?
            enum CodingKeys: String, CodingKey {
                case email, phone, position, notes
                case companyId = "company_id"
                case firstName = "first_name"
                case lastName = "last_name"
                case crmCompanyId = "crm_company_id"
                case clientId = "client_id"
                case assignedTo = "assigned_to"
                case createdBy = "created_by"
            }
        }
        let payload = Payload(
            companyId: companyId,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            crmCompanyId: crmCompanyId,
            email: trimmed(email), phone: trimmed(phone), position: trimmed(position), notes: trimmed(notes),
            clientId: clientId, assignedTo: assignedTo, createdBy: createdBy
        )
        let contact: CRMContact = try await client
            .from("crm_contacts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return contact
    }

    static func updateCRMContact(_ item: CRMContact) async throws {
        struct Payload: Encodable {
            let firstName, lastName: String
            let crmCompanyId: UUID?
            let email, phone, position, notes: String?
            let clientId: UUID?
            let assignedTo: UUID?
            enum CodingKeys: String, CodingKey {
                case email, phone, position, notes
                case firstName = "first_name"
                case lastName = "last_name"
                case crmCompanyId = "crm_company_id"
                case clientId = "client_id"
                case assignedTo = "assigned_to"
            }
        }
        let payload = Payload(
            firstName: item.firstName, lastName: item.lastName, crmCompanyId: item.crmCompanyId,
            email: trimmed(item.email), phone: trimmed(item.phone), position: trimmed(item.position),
            notes: trimmed(item.notes), clientId: item.clientId, assignedTo: item.assignedTo
        )
        try await client.from("crm_contacts").update(payload).eq("id", value: item.id.uuidString).execute()
    }

    static func deleteCRMContact(id: UUID) async throws {
        try await client.from("crm_contacts").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - Deal products

    static func fetchDealProducts(leadId: UUID) async throws -> [CRMDealProduct] {
        try await client
            .from("crm_deal_products")
            .select()
            .eq("lead_id", value: leadId.uuidString)
            .order("created_at")
            .execute()
            .value
    }

    static func createDealProduct(
        companyId: UUID,
        leadId: UUID,
        description: String,
        productId: UUID? = nil,
        quantity: Decimal = 1,
        unitPrice: Decimal = 0,
        discountPercent: Decimal = 0
    ) async throws -> CRMDealProduct {
        struct Payload: Encodable {
            let companyId: UUID
            let leadId: UUID
            let productId: UUID?
            let description: String
            let quantity, unitPrice, discountPercent: String
            enum CodingKeys: String, CodingKey {
                case description, quantity
                case companyId = "company_id"
                case leadId = "lead_id"
                case productId = "product_id"
                case unitPrice = "unit_price"
                case discountPercent = "discount_percent"
            }
        }
        let payload = Payload(
            companyId: companyId, leadId: leadId, productId: productId,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: decimalString(quantity), unitPrice: decimalString(unitPrice),
            discountPercent: decimalString(discountPercent)
        )
        let product: CRMDealProduct = try await client
            .from("crm_deal_products")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return product
    }

    static func deleteDealProduct(id: UUID) async throws {
        try await client.from("crm_deal_products").delete().eq("id", value: id.uuidString).execute()
    }

    static func dealProductsTotal(_ items: [CRMDealProduct]) -> Decimal {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    // MARK: - Quotes

    static func fetchQuotes(openOnly: Bool = false) async throws -> [CRMQuote] {
        let rows: [CRMQuote] = try await client
            .from("crm_quotes")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        if openOnly {
            return rows.filter(\.status.isOpen)
        }
        return rows
    }

    static func fetchQuoteLines(quoteId: UUID) async throws -> [CRMQuoteLine] {
        try await client
            .from("crm_quote_lines")
            .select()
            .eq("quote_id", value: quoteId.uuidString)
            .order("sort_order")
            .execute()
            .value
    }

    static func createQuote(
        companyId: UUID,
        title: String,
        leadId: UUID? = nil,
        crmCompanyId: UUID? = nil,
        crmContactId: UUID? = nil,
        status: CRMQuoteStatus = .draft,
        validUntil: Date? = nil,
        notes: String? = nil,
        currency: String = "RON",
        assignedTo: UUID? = nil,
        createdBy: UUID?
    ) async throws -> CRMQuote {
        struct Payload: Encodable {
            let companyId: UUID
            let leadId: UUID?
            let crmCompanyId: UUID?
            let crmContactId: UUID?
            let quoteNumber: String
            let title, status, currency: String
            let validUntil: String?
            let notes: String?
            let assignedTo: UUID?
            let createdBy: UUID?
            enum CodingKeys: String, CodingKey {
                case title, status, currency, notes
                case companyId = "company_id"
                case leadId = "lead_id"
                case crmCompanyId = "crm_company_id"
                case crmContactId = "crm_contact_id"
                case quoteNumber = "quote_number"
                case validUntil = "valid_until"
                case assignedTo = "assigned_to"
                case createdBy = "created_by"
            }
        }
        let payload = Payload(
            companyId: companyId, leadId: leadId, crmCompanyId: crmCompanyId, crmContactId: crmContactId,
            quoteNumber: "", title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status.rawValue, currency: currency,
            validUntil: dateOnlyString(validUntil), notes: trimmed(notes),
            assignedTo: assignedTo, createdBy: createdBy
        )
        let quote: CRMQuote = try await client
            .from("crm_quotes")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return quote
    }

    static func updateQuote(_ quote: CRMQuote) async throws {
        struct Payload: Encodable {
            let title, status, currency: String
            let validUntil: String?
            let notes: String?
            let totalAmount: String
            let assignedTo: UUID?
            enum CodingKeys: String, CodingKey {
                case title, status, currency, notes
                case validUntil = "valid_until"
                case totalAmount = "total_amount"
                case assignedTo = "assigned_to"
            }
        }
        let payload = Payload(
            title: quote.title, status: quote.status.rawValue, currency: quote.currency,
            validUntil: dateOnlyString(quote.validUntil), notes: trimmed(quote.notes),
            totalAmount: decimalString(quote.totalAmount), assignedTo: quote.assignedTo
        )
        try await client.from("crm_quotes").update(payload).eq("id", value: quote.id.uuidString).execute()
    }

    static func addQuoteLine(
        companyId: UUID,
        quoteId: UUID,
        description: String,
        productId: UUID? = nil,
        quantity: Decimal = 1,
        unitPrice: Decimal = 0,
        discountPercent: Decimal = 0,
        sortOrder: Int = 0
    ) async throws -> CRMQuoteLine {
        struct Payload: Encodable {
            let companyId: UUID
            let quoteId: UUID
            let productId: UUID?
            let description: String
            let quantity, unitPrice, discountPercent: String
            let sortOrder: Int
            enum CodingKeys: String, CodingKey {
                case description, quantity
                case companyId = "company_id"
                case quoteId = "quote_id"
                case productId = "product_id"
                case unitPrice = "unit_price"
                case discountPercent = "discount_percent"
                case sortOrder = "sort_order"
            }
        }
        let payload = Payload(
            companyId: companyId, quoteId: quoteId, productId: productId,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: decimalString(quantity), unitPrice: decimalString(unitPrice),
            discountPercent: decimalString(discountPercent), sortOrder: sortOrder
        )
        let line: CRMQuoteLine = try await client
            .from("crm_quote_lines")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return line
    }

    static func deleteQuoteLine(id: UUID) async throws {
        try await client.from("crm_quote_lines").delete().eq("id", value: id.uuidString).execute()
    }

    static func recalculateQuoteTotal(quoteId: UUID, companyId: UUID) async throws {
        let lines = try await fetchQuoteLines(quoteId: quoteId)
        let total = lines.reduce(Decimal(0)) { $0 + $1.lineTotal }
        struct Payload: Encodable {
            let totalAmount: String
            enum CodingKeys: String, CodingKey { case totalAmount = "total_amount" }
        }
        try await client.from("crm_quotes")
            .update(Payload(totalAmount: decimalString(total)))
            .eq("id", value: quoteId.uuidString)
            .execute()
    }

    static func deleteQuote(id: UUID) async throws {
        try await client.from("crm_quotes").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - Analytics

    static func buildAnalytics(
        leads: [CRMLead],
        tickets: [CRMTicket],
        quotes: [CRMQuote],
        contacts: [CRMContact],
        crmCompanies: [CRMCompany]
    ) -> CRMAnalyticsSummary {
        let deals = leads.filter(\.isDeal)
        var summary = CRMAnalyticsSummary()
        summary.dealSummary = CRMLeadService.buildDealSummary(leads: deals)
        summary.ticketSummary = CRMService.buildTicketSummary(tickets: tickets)
        summary.weightedPipeline = deals.filter { !$0.stage.isClosed }.reduce(0) { $0 + $1.weightedValue }
        summary.funnel = CRMLeadStage.kanbanOrder.map { stage in
            CRMFunnelStageMetric(
                stage: stage,
                count: deals.filter { $0.stage == stage }.count,
                value: deals.filter { $0.stage == stage }.reduce(0) { $0 + $1.estimatedValue }
            )
        }
        let closed = deals.filter { $0.stage.isClosed }.count
        if closed > 0 {
            summary.winRatePercent = Int((Double(summary.dealSummary.wonCount) / Double(closed)) * 100)
        }
        summary.openQuotesCount = quotes.filter(\.status.isOpen).count
        summary.contactsCount = contacts.count
        summary.companiesCount = crmCompanies.count
        summary.openLeadsCount = leads.filter { $0.isLead && !$0.stage.isClosed }.count
        return summary
    }

    // MARK: - Helpers

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func dateOnlyString(_ date: Date?) -> String? {
        SupabaseDecoding.dateOnlyString(from: date)
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

enum CRMUserDirectory {
    static func fetchAssignableUsers(companyId: UUID?, currentProfile: UserProfile?) async -> [UserProfile] {
        guard let companyId else {
            return currentProfile.map { [$0] } ?? []
        }
        if let synced = try? await fetchCompanyUsersFromERP(companyId: companyId), !synced.isEmpty {
            return synced
        }
        guard let currentProfile else { return [] }
        return [currentProfile]
    }

    private static func fetchCompanyUsersFromERP(companyId: UUID) async throws -> [UserProfile] {
        try await SupabaseManager.client
            .rpc("crm_company_assignable_users", params: ["p_company_id": companyId.uuidString])
            .execute()
            .value
    }

    static func displayName(for userId: UUID?, in users: [UserProfile]) -> String? {
        guard let userId else { return nil }
        return users.first(where: { $0.id == userId })?.fullName
    }
}
