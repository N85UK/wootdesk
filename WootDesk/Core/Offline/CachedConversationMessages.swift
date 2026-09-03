import Foundation

/// A page of previously loaded messages held for one conversation, with the
/// moment it was captured so the agent can judge how stale it is.
public struct CachedConversationMessages: Hashable, Sendable {
    public let scope: ConversationScope
    public let messages: [ConversationMessage]
    public let hasOlderMessages: Bool
    public let cachedAt: Date

    public init(
        scope: ConversationScope,
        messages: [ConversationMessage],
        hasOlderMessages: Bool,
        cachedAt: Date = Date()
    ) {
        self.scope = scope
        self.messages = messages
        self.hasOlderMessages = hasOlderMessages
        self.cachedAt = cachedAt
    }
}

// MARK: - Persistence Representation

/// The on-disk form of a cached page.
///
/// The cache keeps its own representation rather than conforming the domain
/// models to `Codable`. A stored file is untrusted input: it can be edited,
/// restored from a backup or written by an older build, so every value is
/// re-validated on the way back in exactly as an API response would be.
extension CachedConversationMessages: Codable {
    private enum CodingKeys: String, CodingKey {
        case scope, messages, hasOlderMessages, cachedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scope = try container.decode(ConversationScope.self, forKey: .scope)
        hasOlderMessages = try container.decode(Bool.self, forKey: .hasOlderMessages)
        cachedAt = try container.decode(Date.self, forKey: .cachedAt)
        let stored = try container.decode([StoredMessage].self, forKey: .messages)
        messages = stored.map { $0.toDomain() }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scope, forKey: .scope)
        try container.encode(hasOlderMessages, forKey: .hasOlderMessages)
        try container.encode(cachedAt, forKey: .cachedAt)
        try container.encode(messages.map(StoredMessage.init(message:)), forKey: .messages)
    }
}

private struct StoredMessage: Codable {
    let id: Int
    let content: String?
    let processedContent: String?
    let kind: Int?
    let isPrivate: Bool
    let createdAt: Date
    let senderName: String?
    let senderType: String?
    let deliveryStatus: String?
    let contentType: String?
    let attachments: [StoredAttachment]

    init(message: ConversationMessage) {
        id = message.id
        content = message.content
        processedContent = message.processedContent
        kind = message.kind.chatwootValue
        isPrivate = message.isPrivate
        createdAt = message.createdAt
        senderName = message.senderName
        senderType = message.senderType
        deliveryStatus = message.deliveryStatus
        contentType = message.contentType
        attachments = message.attachments.map(StoredAttachment.init(attachment:))
    }

    func toDomain() -> ConversationMessage {
        ConversationMessage(
            id: id,
            content: content,
            processedContent: processedContent,
            kind: ConversationMessageKind(chatwootValue: kind),
            isPrivate: isPrivate,
            createdAt: createdAt,
            senderName: senderName,
            senderType: senderType,
            deliveryStatus: deliveryStatus,
            contentType: contentType,
            attachments: attachments.map { $0.toDomain() }
        )
    }
}

private struct StoredAttachment: Codable {
    let id: String
    let serverID: Int?
    let fileType: String?
    let dataURL: String?
    let thumbnailURL: String?
    let fileSize: Int?
    let width: Int?
    let height: Int?
    let fileExtension: String?

    init(attachment: ConversationAttachment) {
        id = attachment.id
        serverID = attachment.serverID
        fileType = attachment.fileType.chatwootValue
        dataURL = attachment.dataURL?.absoluteString
        thumbnailURL = attachment.thumbnailURL?.absoluteString
        fileSize = attachment.fileSize
        width = attachment.width
        height = attachment.height
        fileExtension = attachment.fileExtension
    }

    /// Re-applies the HTTPS-only URL rule. A cache file that has been edited to
    /// carry an `http://`, `file://` or credential-bearing URL yields no URL at
    /// all, so a tampered cache cannot widen what the app is willing to open.
    func toDomain() -> ConversationAttachment {
        ConversationAttachment(
            id: id,
            serverID: serverID,
            fileType: ConversationAttachmentType(chatwootValue: fileType),
            dataURL: ConversationAttachment.safeRemoteURL(
                dataURL,
                allowsInsecureLocalhost: false
            ),
            thumbnailURL: ConversationAttachment.safeRemoteURL(
                thumbnailURL,
                allowsInsecureLocalhost: false
            ),
            fileSize: fileSize,
            width: width,
            height: height,
            fileExtension: fileExtension
        )
    }
}
