import Foundation

/// An agent or team currently responsible for a conversation, as confirmed by
/// the Chatwoot server.
///
/// WootDesk stores only the identifier and display name. Agent email addresses
/// and phone numbers are deliberately not carried into app state.
public struct ConversationAssignee: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// An account member a conversation can be assigned to.
public struct AssignableAgent: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let availability: AgentAvailability?

    public init(id: Int, name: String, availability: AgentAvailability? = nil) {
        self.id = id
        self.name = name
        self.availability = availability
    }
}

/// A team a conversation can be assigned to.
public struct AssignableTeam: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// The assignment targets one Chatwoot account makes available.
///
/// An account may expose agents, teams, both, or neither. An empty set is a
/// genuine result and is presented as "no assignment targets available", never
/// as a loading or error state.
public struct ConversationAssignmentOptions: Equatable, Sendable {
    public let agents: [AssignableAgent]
    public let teams: [AssignableTeam]

    public init(agents: [AssignableAgent] = [], teams: [AssignableTeam] = []) {
        self.agents = agents
        self.teams = teams
    }

    public var isEmpty: Bool { agents.isEmpty && teams.isEmpty }
}

/// The assignment change an agent asks WootDesk to submit.
public enum ConversationAssignmentTarget: Hashable, Sendable {
    case agent(id: Int)
    case team(id: Int)
    case unassignAgent
    case unassignTeam

    /// The Chatwoot assignment parameter name and value for this target.
    ///
    /// Chatwoot unassigns when the identifier does not resolve to a member of
    /// the account, so `0` is the documented way to clear an assignment.
    var requestParameter: (name: String, value: Int) {
        switch self {
        case .agent(let id): return ("assignee_id", id)
        case .team(let id): return ("team_id", id)
        case .unassignAgent: return ("assignee_id", 0)
        case .unassignTeam: return ("team_id", 0)
        }
    }
}
