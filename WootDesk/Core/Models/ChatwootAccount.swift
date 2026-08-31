import Foundation

/// An account within a Chatwoot instance that the authenticated user belongs to.
public struct ChatwootAccount: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let role: String?
    public let status: String?
    public let availability: AgentAvailability?
    public let availabilityStatus: AgentAvailability?
    public let autoOffline: Bool?

    public init(
        id: Int,
        name: String,
        role: String? = nil,
        status: String? = nil,
        availability: AgentAvailability? = nil,
        availabilityStatus: AgentAvailability? = nil,
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

    /// The best current presence value returned by Chatwoot.
    public var effectiveAvailability: AgentAvailability? {
        availabilityStatus ?? availability
    }
}
