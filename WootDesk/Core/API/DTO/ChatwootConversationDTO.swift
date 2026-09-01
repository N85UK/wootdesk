import Foundation

/// Envelope for `GET /api/v1/accounts/{account_id}/conversations`.
///
/// Handles tolerant decoding across different Chatwoot server versions:
/// - `{ "data": { "meta": ..., "payload": [ ... ] } }` (documented shape)
/// - `{ "payload": [ ... ] }`
/// - `[ ... ]`
///
/// A response that matches none of these shapes is a decoding failure and is
/// thrown as such. It is never reported as an empty conversation list, because
/// an empty list is a meaningful result that would hide a real transport or
/// compatibility problem from the user.
public struct ChatwootConversationListResponseDTO: Decodable, Sendable {
    public let conversations: [ChatwootConversationDTO]
    /// Total conversations reported by the server, when the `meta` block provides it.
    public let totalCount: Int?

    public init(conversations: [ChatwootConversationDTO], totalCount: Int? = nil) {
        self.conversations = conversations
        self.totalCount = totalCount
    }

    public init(from decoder: Decoder) throws {
        // Variant 1 and 2: an object carrying `data.payload` or a top-level `payload`.
        if let container = try? decoder.container(keyedBy: DynamicCodingKeys.self) {
            if let dataKey = DynamicCodingKeys(stringValue: "data"),
               let payloadKey = DynamicCodingKeys(stringValue: "payload"),
               let dataContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: dataKey),
               let payload = try? dataContainer.decode([ChatwootConversationDTO].self, forKey: payloadKey) {
                self.conversations = payload
                self.totalCount = Self.decodeTotalCount(from: dataContainer)
                return
            }

            if let payloadKey = DynamicCodingKeys(stringValue: "payload"),
               let payload = try? container.decode([ChatwootConversationDTO].self, forKey: payloadKey) {
                self.conversations = payload
                self.totalCount = Self.decodeTotalCount(from: container)
                return
            }
        }

        // Variant 3: a bare array of conversations.
        if let directArray = try? decoder.singleValueContainer().decode([ChatwootConversationDTO].self) {
            self.conversations = directArray
            self.totalCount = nil
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "The conversation list response did not match any known Chatwoot response shape."
            )
        )
    }

    /// Reads `meta.all_count` where the server supplies it, tolerating its absence.
    private static func decodeTotalCount(from container: KeyedDecodingContainer<DynamicCodingKeys>) -> Int? {
        guard let metaKey = DynamicCodingKeys(stringValue: "meta"),
              let metaContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: metaKey),
              let allCountKey = DynamicCodingKeys(stringValue: "all_count") else {
            return nil
        }
        return try? metaContainer.decode(Int.self, forKey: allCountKey)
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }
}

public struct ChatwootConversationMetaDTO: Codable, Sendable {
    public let sender: ChatwootContactDTO?
    public let channel: String?
    public let assignee: ChatwootAssignedUserDTO?
    public let team: ChatwootTeamDTO?

    enum CodingKeys: String, CodingKey {
        case sender
        case channel
        case assignee
        case team
    }

    public init(
        sender: ChatwootContactDTO? = nil,
        channel: String? = nil,
        assignee: ChatwootAssignedUserDTO? = nil,
        team: ChatwootTeamDTO? = nil
    ) {
        self.sender = sender
        self.channel = channel
        self.assignee = assignee
        self.team = team
    }
}

/// Data Transfer Object for an individual conversation in Chatwoot.
public struct ChatwootConversationDTO: Codable, Sendable {
    public let id: Int
    public let accountId: Int?
    public let inboxId: Int?
    public let status: String?
    public let priority: String?
    public let unreadCount: Int?
    public let lastActivityAt: Double?
    public let timestamp: Double?
    public let createdAt: Double?
    public let meta: ChatwootConversationMetaDTO?
    public let messages: [ChatwootMessageDTO]?
    public let lastNonActivityMessage: ChatwootMessageDTO?
    public let inboxName: String?
    public let labels: [String]?
    public let snoozedUntil: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case inboxId = "inbox_id"
        case status
        case priority
        case unreadCount = "unread_count"
        case lastActivityAt = "last_activity_at"
        case timestamp
        case createdAt = "created_at"
        case meta
        case messages
        case lastNonActivityMessage = "last_non_activity_message"
        case inboxName = "inbox_name"
        case labels
        case snoozedUntil = "snoozed_until"
    }

    public init(
        id: Int,
        accountId: Int? = nil,
        inboxId: Int? = nil,
        status: String? = nil,
        priority: String? = nil,
        unreadCount: Int? = nil,
        lastActivityAt: Double? = nil,
        timestamp: Double? = nil,
        createdAt: Double? = nil,
        meta: ChatwootConversationMetaDTO? = nil,
        messages: [ChatwootMessageDTO]? = nil,
        lastNonActivityMessage: ChatwootMessageDTO? = nil,
        inboxName: String? = nil,
        labels: [String]? = nil,
        snoozedUntil: Double? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.inboxId = inboxId
        self.status = status
        self.priority = priority
        self.unreadCount = unreadCount
        self.lastActivityAt = lastActivityAt
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.meta = meta
        self.messages = messages
        self.lastNonActivityMessage = lastNonActivityMessage
        self.inboxName = inboxName
        self.labels = labels
        self.snoozedUntil = snoozedUntil
    }

    public func toDomain(defaultAccountID: Int) -> Conversation {
        let convStatus: ConversationStatus
        switch status?.lowercased() {
        case "open": convStatus = .open
        case "resolved": convStatus = .resolved
        case "pending": convStatus = .pending
        case "snoozed": convStatus = .snoozed
        default: convStatus = .open
        }

        let convPriority: ConversationPriority?
        switch priority?.lowercased() {
        case "urgent": convPriority = .urgent
        case "high": convPriority = .high
        case "medium": convPriority = .medium
        case "low": convPriority = .low
        default: convPriority = nil
        }

        let lastActivityDate = DateParser.parse(lastActivityAt)
            ?? DateParser.parse(timestamp)
            ?? DateParser.parse(createdAt)
            ?? Date(timeIntervalSince1970: 0)
        let createdDate = DateParser.parse(createdAt) ?? lastActivityDate
        let latestMsg = lastNonActivityMessage?.content
            ?? messages?.last(where: { message in
                guard let content = message.content else { return false }
                return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })?.content

        return Conversation(
            id: id,
            accountID: accountId ?? defaultAccountID,
            inboxID: inboxId ?? 0,
            status: convStatus,
            priority: convPriority,
            contact: meta?.sender?.toDomain(),
            inboxName: inboxName,
            lastActivityAt: lastActivityDate,
            unreadCount: unreadCount ?? 0,
            lastMessagePreview: latestMsg,
            channel: meta?.channel,
            createdAt: createdDate,
            assignee: meta?.assignee?.toAssignee(),
            team: meta?.team?.toDomain(),
            labels: labels ?? [],
            snoozedUntil: DateParser.parse(snoozedUntil)
        )
    }
}
