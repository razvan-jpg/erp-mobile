import Foundation

struct AppModule: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let code: String
    let name: String
    let description: String?
    let sortOrder: Int
    let isActive: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, code, name, description
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}
