import Foundation

/// The agent presence choice stored by Chatwoot for one account membership.
public enum AgentAvailability: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case online
    case busy
    case offline

    public var id: Self { self }

    /// Maps both the current Chatwoot source value and the `available` spelling
    /// used by parts of the public API documentation.
    public init?(chatwootValue: String?) {
        switch chatwootValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "online", "available":
            self = .online
        case "busy":
            self = .busy
        case "offline":
            self = .offline
        default:
            return nil
        }
    }

    /// The value accepted by the current Chatwoot profile availability endpoint.
    public var chatwootValue: String { rawValue }

    public var displayName: String {
        switch self {
        case .online:
            return String(localized: "Online", comment: "Agent availability")
        case .busy:
            return String(localized: "Busy", comment: "Agent availability")
        case .offline:
            return String(localized: "Offline", comment: "Agent availability")
        }
    }
}
