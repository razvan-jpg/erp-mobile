import Foundation
import Supabase

private struct CRMTicketInsert: Encodable {
    let companyId: UUID
    let clientId: UUID
    let subject: String
    let description: String?
    let status: String
    let priority: String
    let category: String
    let openedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case subject, description, status, priority, category
        case companyId = "company_id"
        case clientId = "client_id"
        case openedBy = "opened_by"
    }
}

private struct CRMTicketUpdate: Encodable {
    let subject: String
    let description: String?
    let status: String
    let priority: String
    let category: String
    let assignedTo: UUID?
    let resolutionNotes: String?
    let resolvedAt: String?
    let closedAt: String?

    enum CodingKeys: String, CodingKey {
        case subject, description, status, priority, category
        case assignedTo = "assigned_to"
        case resolutionNotes = "resolution_notes"
        case resolvedAt = "resolved_at"
        case closedAt = "closed_at"
    }
}

private struct CRMTicketMessageInsert: Encodable {
    let companyId: UUID
    let ticketId: UUID
    let body: String
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case body
        case companyId = "company_id"
        case ticketId = "ticket_id"
        case createdBy = "created_by"
    }
}

enum CRMService {
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

    static func fetchTickets(
        status: CRMTicketStatus? = nil,
        clientId: UUID? = nil,
        openOnly: Bool = false
    ) async throws -> [CRMTicket] {
        let rows: [CRMTicket]
        if let clientId {
            rows = try await client
                .from("crm_tickets")
                .select()
                .eq("client_id", value: clientId.uuidString)
                .order("updated_at", ascending: false)
                .execute()
                .value
        } else {
            rows = try await client
                .from("crm_tickets")
                .select()
                .order("updated_at", ascending: false)
                .execute()
                .value
        }

        if openOnly {
            return rows.filter { $0.status.isOpen || $0.status == .resolved }
        }
        if let status {
            return rows.filter { $0.status == status }
        }
        return rows
    }

    static func fetchTicket(id: UUID) async throws -> CRMTicket? {
        let rows: [CRMTicket] = try await client
            .from("crm_tickets")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func createTicket(
        companyId: UUID,
        clientId: UUID,
        subject: String,
        description: String?,
        priority: CRMTicketPriority,
        category: CRMTicketCategory,
        openedBy: UUID?
    ) async throws -> CRMTicket {
        let payload = CRMTicketInsert(
            companyId: companyId,
            clientId: clientId,
            subject: subject,
            description: trimmedOptional(description),
            status: CRMTicketStatus.open.rawValue,
            priority: priority.rawValue,
            category: category.rawValue,
            openedBy: openedBy
        )
        return try await client
            .from("crm_tickets")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    static func updateTicket(_ ticket: CRMTicket) async throws {
        let payload = CRMTicketUpdate(
            subject: ticket.subject,
            description: trimmedOptional(ticket.description),
            status: ticket.status.rawValue,
            priority: ticket.priority.rawValue,
            category: ticket.category.rawValue,
            assignedTo: ticket.assignedTo,
            resolutionNotes: trimmedOptional(ticket.resolutionNotes),
            resolvedAt: dateTimeString(ticket.resolvedAt),
            closedAt: dateTimeString(ticket.closedAt)
        )
        try await client
            .from("crm_tickets")
            .update(payload)
            .eq("id", value: ticket.id.uuidString)
            .execute()
    }

    static func setTicketStatus(
        _ ticket: CRMTicket,
        to status: CRMTicketStatus,
        resolutionNotes: String? = nil
    ) async throws -> CRMTicket {
        var updated = ticket
        updated.status = status
        let now = Date()

        switch status {
        case .open:
            updated.resolvedAt = nil
            updated.closedAt = nil
        case .inProgress:
            updated.resolvedAt = nil
            updated.closedAt = nil
        case .resolved:
            updated.resolvedAt = now
            updated.closedAt = nil
            if let resolutionNotes {
                updated.resolutionNotes = trimmedOptional(resolutionNotes)
            }
        case .closed:
            if updated.resolvedAt == nil {
                updated.resolvedAt = now
            }
            updated.closedAt = now
            if let resolutionNotes {
                updated.resolutionNotes = trimmedOptional(resolutionNotes)
            }
        }

        try await updateTicket(updated)
        return updated
    }

    static func deleteTicket(id: UUID) async throws {
        try await client
            .from("crm_tickets")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    static func fetchMessages(ticketId: UUID) async throws -> [CRMTicketMessage] {
        try await client
            .from("crm_ticket_messages")
            .select()
            .eq("ticket_id", value: ticketId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func addMessage(
        companyId: UUID,
        ticketId: UUID,
        body: String,
        createdBy: UUID?
    ) async throws -> CRMTicketMessage {
        let payload = CRMTicketMessageInsert(
            companyId: companyId,
            ticketId: ticketId,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            createdBy: createdBy
        )
        return try await client
            .from("crm_ticket_messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    static func buildTicketSummary(tickets: [CRMTicket]) -> CRMTicketSummary {
        var summary = CRMTicketSummary()
        for ticket in tickets {
            switch ticket.status {
            case .open: summary.openCount += 1
            case .inProgress: summary.inProgressCount += 1
            case .resolved: summary.resolvedCount += 1
            case .closed: summary.closedCount += 1
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
