import Foundation
import Supabase

private struct CRMLeadInsert: Encodable {
    let companyId: UUID
    let title: String
    let organizationName: String?
    let contactName: String?
    let email: String?
    let phone: String?
    let cui: String?
    let source: String
    let stage: String
    let pipelineType: String
    let estimatedValue: String
    let currency: String
    let probability: Int
    let expectedCloseDate: String?
    let clientId: UUID?
    let crmCompanyId: UUID?
    let crmContactId: UUID?
    let notes: String?
    let assignedTo: UUID?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case title, email, phone, cui, source, stage, currency, probability, notes
        case companyId = "company_id"
        case organizationName = "organization_name"
        case contactName = "contact_name"
        case pipelineType = "pipeline_type"
        case estimatedValue = "estimated_value"
        case expectedCloseDate = "expected_close_date"
        case clientId = "client_id"
        case crmCompanyId = "crm_company_id"
        case crmContactId = "crm_contact_id"
        case assignedTo = "assigned_to"
        case createdBy = "created_by"
    }
}

private struct CRMLeadUpdate: Encodable {
    let title: String
    let organizationName: String?
    let contactName: String?
    let email: String?
    let phone: String?
    let cui: String?
    let source: String
    let stage: String
    let pipelineType: String
    let estimatedValue: String
    let currency: String
    let probability: Int
    let expectedCloseDate: String?
    let clientId: UUID?
    let crmCompanyId: UUID?
    let crmContactId: UUID?
    let notes: String?
    let assignedTo: UUID?

    enum CodingKeys: String, CodingKey {
        case title, email, phone, cui, source, stage, currency, probability, notes
        case organizationName = "organization_name"
        case contactName = "contact_name"
        case pipelineType = "pipeline_type"
        case estimatedValue = "estimated_value"
        case expectedCloseDate = "expected_close_date"
        case clientId = "client_id"
        case crmCompanyId = "crm_company_id"
        case crmContactId = "crm_contact_id"
        case assignedTo = "assigned_to"
    }
}

private struct CRMLeadStageUpdate: Encodable {
    let stage: String
}

private struct CRMActivityInsert: Encodable {
    let companyId: UUID
    let leadId: UUID?
    let clientId: UUID?
    let activityType: String
    let subject: String
    let description: String?
    let dueAt: String?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case subject, description
        case companyId = "company_id"
        case leadId = "lead_id"
        case clientId = "client_id"
        case activityType = "activity_type"
        case dueAt = "due_at"
        case createdBy = "created_by"
    }
}

private struct CRMActivityUpdate: Encodable {
    let subject: String
    let description: String?
    let dueAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case subject, description
        case dueAt = "due_at"
        case completedAt = "completed_at"
    }
}

enum CRMLeadService {
    private static let client = SupabaseManager.client

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func dateTimeString(_ date: Date?) -> String? {
        guard let date else { return nil }
        return isoFormatter.string(from: date)
    }

    private static func dateOnlyString(_ date: Date?) -> String? {
        SupabaseDecoding.dateOnlyString(from: date)
    }

    private static func amountString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    static func fetchLeads(pipelineType: CRMPipelineType? = nil) async throws -> [CRMLead] {
        var query = client
            .from("crm_leads")
            .select()
        if let pipelineType {
            query = query.eq("pipeline_type", value: pipelineType.rawValue)
        }
        return try await query
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func fetchLead(id: UUID) async throws -> CRMLead? {
        let rows: [CRMLead] = try await client
            .from("crm_leads")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func createLead(
        companyId: UUID,
        title: String,
        pipelineType: CRMPipelineType = .deal,
        stage: CRMLeadStage = .new,
        organizationName: String? = nil,
        contactName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        cui: String? = nil,
        source: CRMLeadSource = .other,
        estimatedValue: Decimal = 0,
        currency: String = "RON",
        probability: Int = 10,
        expectedCloseDate: Date? = nil,
        clientId: UUID? = nil,
        crmCompanyId: UUID? = nil,
        crmContactId: UUID? = nil,
        notes: String? = nil,
        assignedTo: UUID? = nil,
        createdBy: UUID?
    ) async throws -> CRMLead {
        let payload = CRMLeadInsert(
            companyId: companyId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            organizationName: trimmedOptional(organizationName),
            contactName: trimmedOptional(contactName),
            email: trimmedOptional(email),
            phone: trimmedOptional(phone),
            cui: trimmedOptional(cui),
            source: source.rawValue,
            stage: stage.rawValue,
            pipelineType: pipelineType.rawValue,
            estimatedValue: amountString(estimatedValue),
            currency: currency,
            probability: min(100, max(0, probability)),
            expectedCloseDate: dateOnlyString(expectedCloseDate),
            clientId: clientId,
            crmCompanyId: crmCompanyId,
            crmContactId: crmContactId,
            notes: trimmedOptional(notes),
            assignedTo: assignedTo,
            createdBy: createdBy
        )
        return try await client
            .from("crm_leads")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    static func updateLead(_ lead: CRMLead) async throws {
        let payload = CRMLeadUpdate(
            title: lead.title.trimmingCharacters(in: .whitespacesAndNewlines),
            organizationName: trimmedOptional(lead.organizationName),
            contactName: trimmedOptional(lead.contactName),
            email: trimmedOptional(lead.email),
            phone: trimmedOptional(lead.phone),
            cui: trimmedOptional(lead.cui),
            source: lead.source.rawValue,
            stage: lead.stage.rawValue,
            pipelineType: lead.pipelineType.rawValue,
            estimatedValue: amountString(lead.estimatedValue),
            currency: lead.currency,
            probability: min(100, max(0, lead.probability)),
            expectedCloseDate: dateOnlyString(lead.expectedCloseDate),
            clientId: lead.clientId,
            crmCompanyId: lead.crmCompanyId,
            crmContactId: lead.crmContactId,
            notes: trimmedOptional(lead.notes),
            assignedTo: lead.assignedTo
        )
        try await client
            .from("crm_leads")
            .update(payload)
            .eq("id", value: lead.id.uuidString)
            .execute()
    }

    static func updateLeadStage(id: UUID, to stage: CRMLeadStage) async throws -> CRMLead {
        let payload = CRMLeadStageUpdate(stage: stage.rawValue)
        return try await client
            .from("crm_leads")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    static func deleteLead(id: UUID) async throws {
        try await client
            .from("crm_leads")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func fetchActivities(leadId: UUID? = nil, openOnly: Bool = false) async throws -> [CRMActivity] {
        let rows: [CRMActivity]
        if let leadId {
            rows = try await client
                .from("crm_activities")
                .select()
                .eq("lead_id", value: leadId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        } else {
            rows = try await client
                .from("crm_activities")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        }

        if openOnly {
            return rows.filter { !$0.isCompleted }
        }
        return rows
    }

    static func createActivity(
        companyId: UUID,
        leadId: UUID?,
        clientId: UUID?,
        activityType: CRMActivityType,
        subject: String,
        description: String? = nil,
        dueAt: Date? = nil,
        createdBy: UUID?
    ) async throws -> CRMActivity {
        let payload = CRMActivityInsert(
            companyId: companyId,
            leadId: leadId,
            clientId: clientId,
            activityType: activityType.rawValue,
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedOptional(description),
            dueAt: dateTimeString(dueAt),
            createdBy: createdBy
        )
        return try await client
            .from("crm_activities")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    static func completeActivity(_ activity: CRMActivity) async throws {
        struct Payload: Encodable {
            let completedAt: String
            enum CodingKeys: String, CodingKey {
                case completedAt = "completed_at"
            }
        }
        let payload = Payload(completedAt: dateTimeString(Date()) ?? "")
        try await client
            .from("crm_activities")
            .update(payload)
            .eq("id", value: activity.id.uuidString)
            .execute()
    }

    static func deleteActivity(id: UUID) async throws {
        try await client
            .from("crm_activities")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func convertLeadToDeal(_ lead: CRMLead) async throws -> CRMLead {
        var deal = lead
        deal.pipelineType = .deal
        if deal.stage == .new || deal.stage == .contacted {
            deal.stage = .qualified
        }
        try await updateLead(deal)
        return try await fetchLead(id: lead.id) ?? deal
    }

    static func buildDealSummary(leads: [CRMLead]) -> CRMDealSummary {
        var summary = CRMDealSummary()
        summary.totalCount = leads.count
        for lead in leads {
            switch lead.stage {
            case .won:
                summary.wonCount += 1
                summary.wonValue += lead.estimatedValue
            case .lost:
                summary.lostCount += 1
            default:
                summary.openCount += 1
                summary.pipelineValue += lead.estimatedValue
                summary.weightedPipeline += lead.weightedValue
            }
        }
        return summary
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
