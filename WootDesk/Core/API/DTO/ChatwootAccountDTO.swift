import Foundation

/// Data Transfer Object for account entries returned by Chatwoot APIs.
public struct ChatwootAccountDTO: Codable, Sendable {
    public let id: Int
    public let name: String?
    public let role: String?
    public let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case status
    }

    public init(id: Int, name: String?, role: String? = nil, status: String? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.status = status
    }

    public func toDomain() -> ChatwootAccount {
        ChatwootAccount(
            id: id,
            name: name ?? "Account #\(id)",
            role: role,
            status: status
        )
    }
}
