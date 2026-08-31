import Foundation

/// Data Transfer Object for account entries returned by Chatwoot APIs.
public struct ChatwootAccountDTO: Codable, Sendable {
    public let id: Int
    public let name: String?
    public let role: String?
    public let status: String?
    public let availability: String?
    public let availabilityStatus: String?
    public let autoOffline: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case status
        case availability
        case availabilityStatus = "availability_status"
        case autoOffline = "auto_offline"
    }

    public init(
        id: Int,
        name: String?,
        role: String? = nil,
        status: String? = nil,
        availability: String? = nil,
        availabilityStatus: String? = nil,
        autoOffline: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.status = status
        self.availability = availability
        self.availabilityStatus = availabilityStatus
        self.autoOffline = autoOffline
    }

    public func toDomain() -> ChatwootAccount {
        ChatwootAccount(
            id: id,
            name: name ?? "Account #\(id)",
            role: role,
            status: status,
            availability: AgentAvailability(chatwootValue: availability),
            availabilityStatus: AgentAvailability(chatwootValue: availabilityStatus),
            autoOffline: autoOffline
        )
    }
}
