import Foundation

/// The stable app-facing representation of a Chatwoot conversation message.
public struct ConversationMessage: Identifiable, Hashable, Sendable {
    public let id: Int
    public let content: String?
    public let processedContent: String?
    public let kind: ConversationMessageKind
    public let isPrivate: Bool
    public let createdAt: Date
    public let senderName: String?
    public let senderType: String?
    public let deliveryStatus: String?
    public let contentType: String?
    public let attachments: [ConversationAttachment]

    public init(
        id: Int,
        content: String? = nil,
        processedContent: String? = nil,
        kind: ConversationMessageKind,
        isPrivate: Bool = false,
        createdAt: Date,
        senderName: String? = nil,
        senderType: String? = nil,
        deliveryStatus: String? = nil,
        contentType: String? = nil,
        attachments: [ConversationAttachment] = []
    ) {
        self.id = id
        self.content = content
        self.processedContent = processedContent
        self.kind = kind
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.senderName = senderName
        self.senderType = senderType
        self.deliveryStatus = deliveryStatus
        self.contentType = contentType
        self.attachments = attachments
    }

    /// Plain text suitable for accessibility, selection, and safe fallback UI.
    public var displayContent: String {
        for candidate in [content, processedContent] {
            let trimmed = MessageTextFormatter.plainText(from: candidate)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if attachments.count == 1 {
            return attachments[0].displayName
        }
        if attachments.count > 1 {
            return "\(attachments.count) attachments"
        }
        return "Unsupported message content"
    }

    /// Limited inline Markdown formatting with link activation removed.
    public var safeAttributedContent: AttributedString {
        MessageTextFormatter.attributedText(from: displayContent)
    }

    public var hasTextContent: Bool {
        [content, processedContent].contains {
            !MessageTextFormatter.plainText(from: $0).isEmpty
        }
    }

    public var attachmentCount: Int {
        attachments.count
    }

    public var isOutgoing: Bool {
        if case .outgoing = kind { return true }
        return false
    }

    public var isActivity: Bool {
        if case .activity = kind { return true }
        return false
    }
}

/// Chatwoot's documented numeric message types, with a tolerant fallback for
/// versions that introduce another value.
public enum ConversationMessageKind: Hashable, Sendable {
    case incoming
    case outgoing
    case activity
    case template
    case unknown(Int?)

    public init(chatwootValue: Int?) {
        switch chatwootValue {
        case 0: self = .incoming
        case 1: self = .outgoing
        case 2: self = .activity
        case 3: self = .template
        default: self = .unknown(chatwootValue)
        }
    }
}

/// One page from Chatwoot's message history endpoint.
public struct ConversationMessagePage: Hashable, Sendable {
    public let messages: [ConversationMessage]
    public let hasOlderMessages: Bool

    public init(messages: [ConversationMessage], hasOlderMessages: Bool) {
        self.messages = messages
        self.hasOlderMessages = hasOlderMessages
    }
}
