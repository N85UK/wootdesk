import Foundation

/// A Chatwoot user as returned inside conversation metadata, the account agent
/// list, and assignment responses.
public struct ChatwootAssignedUserDTO: Codable, Sendable {
    public let id: Int
    public let name: String?
    public let availableName: String?
    public let availabilityStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case availableName = "available_name"
        case availabilityStatus = "availability_status"
    }

    public init(
        id: Int,
        name: String? = nil,
        availableName: String? = nil,
        availabilityStatus: String? = nil
    ) {
        self.id = id
        self.name = name
        self.availableName = availableName
        self.availabilityStatus = availabilityStatus
    }

    /// The name to display, falling back to a stable identifier rather than an
    /// invented placeholder when the server omits every name field.
    public var displayName: String {
        for candidate in [availableName, name] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
               !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Agent #\(id)"
    }

    public func toAssignee() -> ConversationAssignee {
        ConversationAssignee(id: id, name: displayName)
    }

    public func toAssignableAgent() -> AssignableAgent {
        AssignableAgent(
            id: id,
            name: displayName,
            availability: AgentAvailability(chatwootValue: availabilityStatus)
        )
    }
}

/// A Chatwoot team as returned inside conversation metadata and the account
/// team list.
public struct ChatwootTeamDTO: Codable, Sendable {
    public let id: Int
    public let name: String?

    public init(id: Int, name: String? = nil) {
        self.id = id
        self.name = name
    }

    public var displayName: String {
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        return "Team #\(id)"
    }

    public func toDomain() -> AssignableTeam {
        AssignableTeam(id: id, name: displayName)
    }
}

/// A Chatwoot account label.
public struct ChatwootLabelDTO: Codable, Sendable {
    public let id: Int
    public let title: String
    public let color: String?

    public init(id: Int, title: String, color: String? = nil) {
        self.id = id
        self.title = title
        self.color = color
    }

    public func toDomain() -> AccountLabel {
        AccountLabel(id: id, title: title, colour: color)
    }
}

/// Envelope for responses that Chatwoot wraps in `payload`, and that some
/// versions return as a bare array instead.
///
/// A body matching neither shape is a decoding failure. It is never reported as
/// an empty collection, because empty is a meaningful answer that would hide a
/// real compatibility problem.
public struct ChatwootPayloadListDTO<Element: Decodable & Sendable>: Decodable, Sendable {
    public let items: [Element]

    public init(items: [Element]) {
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: PayloadKey.self),
           let items = try? container.decode([Element].self, forKey: .payload) {
            self.items = items
            return
        }

        if let container = try? decoder.container(keyedBy: PayloadKey.self),
           let dataContainer = try? container.nestedContainer(keyedBy: PayloadKey.self, forKey: .data),
           let items = try? dataContainer.decode([Element].self, forKey: .payload) {
            self.items = items
            return
        }

        if let items = try? decoder.singleValueContainer().decode([Element].self) {
            self.items = items
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "The response did not match any known Chatwoot payload shape."
            )
        )
    }

    private enum PayloadKey: String, CodingKey {
        case payload
        case data
    }
}

/// Envelope for `GET`/`POST` `.../conversations/{id}/labels`.
///
/// Chatwoot returns label titles as strings. Older builds return label objects,
/// so both shapes decode to a title list.
public struct ChatwootConversationLabelsResponseDTO: Decodable, Sendable {
    public let labels: [String]

    public init(labels: [String]) {
        self.labels = labels
    }

    public init(from decoder: Decoder) throws {
        if let titles = try? ChatwootPayloadListDTO<String>(from: decoder) {
            self.labels = titles.items
            return
        }
        let objects = try ChatwootPayloadListDTO<ChatwootLabelDTO>(from: decoder)
        self.labels = objects.items.map(\.title)
    }
}

/// Request body for `POST .../conversations/{id}/toggle_status`.
struct ToggleConversationStatusRequestDTO: Encodable, Sendable {
    let status: String
    /// Epoch seconds at which a snoozed conversation returns to the queue.
    let snoozedUntil: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case snoozedUntil = "snoozed_until"
    }
}

/// Request body for `POST .../conversations/{id}/toggle_priority`.
struct ToggleConversationPriorityRequestDTO: Encodable, Sendable {
    let priority: String
}

/// Request body for `POST .../conversations/{id}/labels`.
///
/// Chatwoot replaces the whole label set with the supplied list, so callers
/// must send the complete intended set rather than only the change.
struct UpdateConversationLabelsRequestDTO: Encodable, Sendable {
    let labels: [String]
}

/// Envelope for `GET /api/v1/accounts/{account_id}/conversations/{id}`.
///
/// Chatwoot versions return either the conversation object directly or wrap it
/// in `payload`. A body matching neither shape is a decoding failure.
public struct ChatwootConversationResponseDTO: Decodable, Sendable {
    public let conversation: ChatwootConversationDTO

    public init(conversation: ChatwootConversationDTO) {
        self.conversation = conversation
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: PayloadKey.self),
           let wrapped = try? container.decode(ChatwootConversationDTO.self, forKey: .payload) {
            self.conversation = wrapped
            return
        }
        self.conversation = try ChatwootConversationDTO(from: decoder)
    }

    private enum PayloadKey: String, CodingKey {
        case payload
    }
}
