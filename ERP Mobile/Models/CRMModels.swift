import Foundation

enum CRMModelDecoding {
    nonisolated static func decodeDecimal<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Decimal {
        try SupabaseDecoding.decodeDecimal(from: try container.superDecoder(forKey: key).singleValueContainer())
    }
}

enum CRMTicketStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case open
    case inProgress = "in_progress"
    case resolved
    case closed

    var id: String { rawValue }

    var isOpen: Bool {
        self == .open || self == .inProgress
    }

    var isClosed: Bool {
        self == .closed
    }
}

extension CRMTicketStatus {
    @MainActor
    var label: String {
        L10n.tr("crm.ticket_status.\(rawValue)")
    }
}

enum CRMTicketPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case normal
    case high
    case urgent

    var id: String { rawValue }
}

extension CRMTicketPriority {
    @MainActor
    var label: String {
        L10n.tr("crm.ticket_priority.\(rawValue)")
    }
}

enum CRMTicketCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case billing
    case delivery
    case technical
    case contract
    case other

    var id: String { rawValue }
}

extension CRMTicketCategory {
    @MainActor
    var label: String {
        L10n.tr("crm.ticket_category.\(rawValue)")
    }
}

struct CRMTicket: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let ticketNumber: String
    let clientId: UUID
    var subject: String
    var description: String?
    var status: CRMTicketStatus
    var priority: CRMTicketPriority
    var category: CRMTicketCategory
    var assignedTo: UUID?
    var resolutionNotes: String?
    var resolvedAt: Date?
    var closedAt: Date?
    let openedBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, subject, description, status, priority, category
        case companyId = "company_id"
        case ticketNumber = "ticket_number"
        case clientId = "client_id"
        case assignedTo = "assigned_to"
        case resolutionNotes = "resolution_notes"
        case resolvedAt = "resolved_at"
        case closedAt = "closed_at"
        case openedBy = "opened_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayTitle: String {
        "\(ticketNumber) · \(subject)"
    }
}

nonisolated extension CRMTicket: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        ticketNumber = try container.decode(String.self, forKey: .ticketNumber)
        clientId = try container.decode(UUID.self, forKey: .clientId)
        subject = try container.decode(String.self, forKey: .subject)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decode(CRMTicketStatus.self, forKey: .status)
        priority = try container.decode(CRMTicketPriority.self, forKey: .priority)
        category = try container.decode(CRMTicketCategory.self, forKey: .category)
        assignedTo = try container.decodeIfPresent(UUID.self, forKey: .assignedTo)
        resolutionNotes = try container.decodeIfPresent(String.self, forKey: .resolutionNotes)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        openedBy = try container.decodeIfPresent(UUID.self, forKey: .openedBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct CRMTicketMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let ticketId: UUID
    var body: String
    let createdBy: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case companyId = "company_id"
        case ticketId = "ticket_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

nonisolated extension CRMTicketMessage: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        ticketId = try container.decode(UUID.self, forKey: .ticketId)
        body = try container.decode(String.self, forKey: .body)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct CRMTicketSummary: Sendable {
    var openCount: Int = 0
    var inProgressCount: Int = 0
    var resolvedCount: Int = 0
    var closedCount: Int = 0

    var activeCount: Int { openCount + inProgressCount }
}

// MARK: - Tranzacții / pipeline vânzări (Bitrix24-style)

enum CRMLeadStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case new
    case contacted
    case qualified
    case proposal
    case negotiation
    case won
    case lost

    var id: String { rawValue }

    static var kanbanOrder: [CRMLeadStage] {
        [.new, .contacted, .qualified, .proposal, .negotiation, .won, .lost]
    }

    var isClosed: Bool {
        self == .won || self == .lost
    }
}

extension CRMLeadStage {
    @MainActor
    var label: String {
        L10n.tr("crm.deal_stage.\(rawValue)")
    }

    var accentColorName: String {
        switch self {
        case .new: return "blue"
        case .contacted: return "cyan"
        case .qualified: return "purple"
        case .proposal: return "orange"
        case .negotiation: return "yellow"
        case .won: return "green"
        case .lost: return "red"
        }
    }
}

enum CRMLeadSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case website
    case referral
    case phone
    case email
    case event
    case social
    case other

    var id: String { rawValue }
}

extension CRMLeadSource {
    @MainActor
    var label: String {
        L10n.tr("crm.deal_source.\(rawValue)")
    }
}

enum CRMActivityType: String, Codable, CaseIterable, Identifiable, Sendable {
    case call
    case meeting
    case email
    case task
    case note

    var id: String { rawValue }
}

extension CRMActivityType {
    @MainActor
    var label: String {
        L10n.tr("crm.activity_type.\(rawValue)")
    }

    var systemImage: String {
        switch self {
        case .call: return "phone.fill"
        case .meeting: return "person.2.fill"
        case .email: return "envelope.fill"
        case .task: return "checkmark.circle.fill"
        case .note: return "note.text"
        }
    }
}

struct CRMLead: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var title: String
    var organizationName: String?
    var contactName: String?
    var email: String?
    var phone: String?
    var cui: String?
    var source: CRMLeadSource
    var stage: CRMLeadStage
    var pipelineType: CRMPipelineType
    var estimatedValue: Decimal
    var currency: String
    var probability: Int
    var expectedCloseDate: Date?
    var clientId: UUID?
    var crmCompanyId: UUID?
    var crmContactId: UUID?
    var notes: String?
    var assignedTo: UUID?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, email, phone, cui, source, stage, currency, probability, notes
        case companyId = "company_id"
        case organizationName = "organization_name"
        case contactName = "contact_name"
        case estimatedValue = "estimated_value"
        case expectedCloseDate = "expected_close_date"
        case clientId = "client_id"
        case pipelineType = "pipeline_type"
        case crmCompanyId = "crm_company_id"
        case crmContactId = "crm_contact_id"
        case assignedTo = "assigned_to"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isLead: Bool { pipelineType == .lead }
    var isDeal: Bool { pipelineType == .deal }

    var displaySubtitle: String {
        let org = organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let contact = contactName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !org.isEmpty && !contact.isEmpty { return "\(org) · \(contact)" }
        if !org.isEmpty { return org }
        if !contact.isEmpty { return contact }
        return ""
    }

    var weightedValue: Decimal {
        estimatedValue * Decimal(probability) / 100
    }
}

nonisolated extension CRMLead: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        title = try container.decode(String.self, forKey: .title)
        organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName)
        contactName = try container.decodeIfPresent(String.self, forKey: .contactName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        cui = try container.decodeIfPresent(String.self, forKey: .cui)
        source = try container.decode(CRMLeadSource.self, forKey: .source)
        stage = try container.decode(CRMLeadStage.self, forKey: .stage)
        pipelineType = try container.decodeIfPresent(CRMPipelineType.self, forKey: .pipelineType) ?? .deal
        estimatedValue = try CRMModelDecoding.decodeDecimal(from: container, forKey: .estimatedValue)
        currency = try container.decode(String.self, forKey: .currency)
        probability = try container.decode(Int.self, forKey: .probability)
        expectedCloseDate = try container.decodeIfPresent(Date.self, forKey: .expectedCloseDate)
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)
        crmCompanyId = try container.decodeIfPresent(UUID.self, forKey: .crmCompanyId)
        crmContactId = try container.decodeIfPresent(UUID.self, forKey: .crmContactId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        assignedTo = try container.decodeIfPresent(UUID.self, forKey: .assignedTo)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

enum CRMPipelineType: String, Codable, CaseIterable, Identifiable, Sendable {
    case lead
    case deal

    var id: String { rawValue }
}

extension CRMPipelineType {
    @MainActor
    var label: String {
        switch self {
        case .lead: return L10n.tr("crm.pipeline.lead")
        case .deal: return L10n.tr("crm.pipeline.deal")
        }
    }
}

enum CRMQuoteStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case sent
    case accepted
    case rejected

    var id: String { rawValue }

    var isOpen: Bool {
        self == .draft || self == .sent
    }
}

extension CRMQuoteStatus {
    @MainActor
    var label: String {
        L10n.tr("crm.quote_status.\(rawValue)")
    }
}

struct CRMCompany: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var name: String
    var cui: String?
    var email: String?
    var phone: String?
    var website: String?
    var address: String?
    var industry: String?
    var notes: String?
    var clientId: UUID?
    var assignedTo: UUID?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, cui, email, phone, website, address, industry, notes
        case companyId = "company_id"
        case clientId = "client_id"
        case assignedTo = "assigned_to"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayName: String { name }

    var isFromERP: Bool { clientId != nil }
}

nonisolated extension CRMCompany: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        name = try container.decode(String.self, forKey: .name)
        cui = try container.decodeIfPresent(String.self, forKey: .cui)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        industry = try container.decodeIfPresent(String.self, forKey: .industry)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)
        assignedTo = try container.decodeIfPresent(UUID.self, forKey: .assignedTo)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct CRMContact: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var crmCompanyId: UUID?
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String?
    var position: String?
    var notes: String?
    var clientId: UUID?
    var assignedTo: UUID?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, phone, notes
        case companyId = "company_id"
        case crmCompanyId = "crm_company_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case position
        case clientId = "client_id"
        case assignedTo = "assigned_to"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var displayName: String { fullName }

    var isFromERP: Bool { clientId != nil }
}

nonisolated extension CRMContact: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        crmCompanyId = try container.decodeIfPresent(UUID.self, forKey: .crmCompanyId)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)
        assignedTo = try container.decodeIfPresent(UUID.self, forKey: .assignedTo)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct CRMDealProduct: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let leadId: UUID
    var productId: UUID?
    var lineDescription: String
    var quantity: Decimal
    var unitPrice: Decimal
    var discountPercent: Decimal
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case leadId = "lead_id"
        case productId = "product_id"
        case lineDescription = "description"
        case quantity
        case unitPrice = "unit_price"
        case discountPercent = "discount_percent"
        case createdAt = "created_at"
    }

    var lineTotal: Decimal {
        let gross = quantity * unitPrice
        return gross - (gross * discountPercent / 100)
    }
}

nonisolated extension CRMDealProduct: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        leadId = try container.decode(UUID.self, forKey: .leadId)
        productId = try container.decodeIfPresent(UUID.self, forKey: .productId)
        lineDescription = try container.decode(String.self, forKey: .lineDescription)
        quantity = try CRMModelDecoding.decodeDecimal(from: container, forKey: .quantity)
        unitPrice = try CRMModelDecoding.decodeDecimal(from: container, forKey: .unitPrice)
        discountPercent = try CRMModelDecoding.decodeDecimal(from: container, forKey: .discountPercent)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct CRMQuote: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var leadId: UUID?
    var crmCompanyId: UUID?
    var crmContactId: UUID?
    var quoteNumber: String
    var title: String
    var status: CRMQuoteStatus
    var validUntil: Date?
    var notes: String?
    var totalAmount: Decimal
    var currency: String
    var assignedTo: UUID?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, status, notes, currency
        case companyId = "company_id"
        case leadId = "lead_id"
        case crmCompanyId = "crm_company_id"
        case crmContactId = "crm_contact_id"
        case quoteNumber = "quote_number"
        case validUntil = "valid_until"
        case totalAmount = "total_amount"
        case assignedTo = "assigned_to"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated extension CRMQuote: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        leadId = try container.decodeIfPresent(UUID.self, forKey: .leadId)
        crmCompanyId = try container.decodeIfPresent(UUID.self, forKey: .crmCompanyId)
        crmContactId = try container.decodeIfPresent(UUID.self, forKey: .crmContactId)
        quoteNumber = try container.decode(String.self, forKey: .quoteNumber)
        title = try container.decode(String.self, forKey: .title)
        status = try container.decode(CRMQuoteStatus.self, forKey: .status)
        validUntil = try container.decodeIfPresent(Date.self, forKey: .validUntil)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        totalAmount = try CRMModelDecoding.decodeDecimal(from: container, forKey: .totalAmount)
        currency = try container.decode(String.self, forKey: .currency)
        assignedTo = try container.decodeIfPresent(UUID.self, forKey: .assignedTo)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct CRMQuoteLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let quoteId: UUID
    var productId: UUID?
    var lineDescription: String
    var quantity: Decimal
    var unitPrice: Decimal
    var discountPercent: Decimal
    var sortOrder: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case companyId = "company_id"
        case quoteId = "quote_id"
        case productId = "product_id"
        case lineDescription = "description"
        case unitPrice = "unit_price"
        case discountPercent = "discount_percent"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    var lineTotal: Decimal {
        let gross = quantity * unitPrice
        return gross - (gross * discountPercent / 100)
    }
}

nonisolated extension CRMQuoteLine: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        quoteId = try container.decode(UUID.self, forKey: .quoteId)
        productId = try container.decodeIfPresent(UUID.self, forKey: .productId)
        lineDescription = try container.decode(String.self, forKey: .lineDescription)
        quantity = try CRMModelDecoding.decodeDecimal(from: container, forKey: .quantity)
        unitPrice = try CRMModelDecoding.decodeDecimal(from: container, forKey: .unitPrice)
        discountPercent = try CRMModelDecoding.decodeDecimal(from: container, forKey: .discountPercent)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct CRMFunnelStageMetric: Sendable, Identifiable {
    let stage: CRMLeadStage
    let count: Int
    let value: Decimal

    var id: String { stage.rawValue }
}

struct CRMAnalyticsSummary: Sendable {
    var dealSummary = CRMDealSummary()
    var ticketSummary = CRMTicketSummary()
    var weightedPipeline: Decimal = 0
    var winRatePercent: Int = 0
    var funnel: [CRMFunnelStageMetric] = []
    var openQuotesCount: Int = 0
    var contactsCount: Int = 0
    var companiesCount: Int = 0
    var openLeadsCount: Int = 0
}

struct CRMActivity: Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var leadId: UUID?
    var clientId: UUID?
    var activityType: CRMActivityType
    var subject: String
    var description: String?
    var dueAt: Date?
    var completedAt: Date?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, subject, description
        case companyId = "company_id"
        case leadId = "lead_id"
        case clientId = "client_id"
        case activityType = "activity_type"
        case dueAt = "due_at"
        case completedAt = "completed_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isCompleted: Bool { completedAt != nil }
}

nonisolated extension CRMActivity: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        leadId = try container.decodeIfPresent(UUID.self, forKey: .leadId)
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)
        activityType = try container.decode(CRMActivityType.self, forKey: .activityType)
        subject = try container.decode(String.self, forKey: .subject)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct CRMDealSummary: Sendable {
    var totalCount: Int = 0
    var openCount: Int = 0
    var wonCount: Int = 0
    var lostCount: Int = 0
    var pipelineValue: Decimal = 0
    var wonValue: Decimal = 0
    var weightedPipeline: Decimal = 0

    func count(for stage: CRMLeadStage, in leads: [CRMLead]) -> Int {
        leads.filter { $0.stage == stage }.count
    }

    func value(for stage: CRMLeadStage, in leads: [CRMLead]) -> Decimal {
        leads.filter { $0.stage == stage }.reduce(0) { $0 + $1.estimatedValue }
    }
}

extension Notification.Name {
    static let crmLeadsDidChange = Notification.Name("crmLeadsDidChange")
}
