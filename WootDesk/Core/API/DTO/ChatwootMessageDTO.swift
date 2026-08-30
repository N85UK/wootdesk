import Foundation

/// Data Transfer Object for message previews within conversations.
public struct ChatwootMessageDTO: Codable, Sendable {
    public let id: Int?
    public let content: String?
    public let messageType: Int?
    public let createdAt: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
    }

    public init(id: Int? = nil, content: String? = nil, messageType: Int? = nil, createdAt: Double? = nil) {
        self.id = id
        self.content = content
        self.messageType = messageType
        self.createdAt = createdAt
    }
}
