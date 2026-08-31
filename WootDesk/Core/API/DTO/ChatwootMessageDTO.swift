import Foundation

/// Tolerant envelope for Chatwoot message history responses.
///
/// Current Chatwoot returns `{ "meta": ..., "payload": [...] }`. A small
/// number of self-hosted versions expose `data.payload` or the array directly,
/// so those non-secret transport differences are accepted as well.
public struct ChatwootMessageListResponseDTO: Decodable, Sendable {
    public let messages: [ChatwootMessageDTO]

    public init(messages: [ChatwootMessageDTO]) {
        self.messages = messages
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKeys.self) {
            if let dataKey = DynamicCodingKeys(stringValue: "data"),
               let payloadKey = DynamicCodingKeys(stringValue: "payload"),
               let dataContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: dataKey),
               let payload = try? dataContainer.decode([ChatwootMessageDTO].self, forKey: payloadKey) {
                messages = payload
                return
            }

            if let payloadKey = DynamicCodingKeys(stringValue: "payload"),
               let payload = try? container.decode([ChatwootMessageDTO].self, forKey: payloadKey) {
                messages = payload
                return
            }
        }

        if let payload = try? decoder.singleValueContainer().decode([ChatwootMessageDTO].self) {
            messages = payload
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "The message list response did not match a known Chatwoot response shape."
            )
        )
    }
}

/// Tolerant response for the message creation endpoint.
public struct ChatwootCreatedMessageResponseDTO: Decodable, Sendable {
    public let message: ChatwootMessageDTO

    public init(from decoder: Decoder) throws {
        if let direct = try? ChatwootMessageDTO(from: decoder), direct.id != nil {
            message = direct
            return
        }

        if let container = try? decoder.container(keyedBy: DynamicCodingKeys.self) {
            for keyName in ["payload", "data"] {
                guard let key = DynamicCodingKeys(stringValue: keyName) else { continue }
                if let wrapped = try? container.decode(ChatwootMessageDTO.self, forKey: key), wrapped.id != nil {
                    message = wrapped
                    return
                }
            }
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "The created message response did not contain a message."
            )
        )
    }
}

/// Data Transfer Object shared by conversation previews and full message history.
public struct ChatwootMessageDTO: Codable, Sendable {
    public let id: Int?
    public let content: String?
    public let processedMessageContent: String?
    public let messageType: Int?
    public let createdAt: Double?
    public let isPrivate: Bool?
    public let status: String?
    public let contentType: String?
    public let senderType: String?
    public let sender: ChatwootMessageSenderDTO?
    public let attachments: [ChatwootMessageAttachmentDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case processedMessageContent = "processed_message_content"
        case messageType = "message_type"
        case createdAt = "created_at"
        case isPrivate = "private"
        case status
        case contentType = "content_type"
        case senderType = "sender_type"
        case sender
        case attachments
    }

    public init(
        id: Int? = nil,
        content: String? = nil,
        processedMessageContent: String? = nil,
        messageType: Int? = nil,
        createdAt: Double? = nil,
        isPrivate: Bool? = nil,
        status: String? = nil,
        contentType: String? = nil,
        senderType: String? = nil,
        sender: ChatwootMessageSenderDTO? = nil,
        attachments: [ChatwootMessageAttachmentDTO]? = nil
    ) {
        self.id = id
        self.content = content
        self.processedMessageContent = processedMessageContent
        self.messageType = messageType
        self.createdAt = createdAt
        self.isPrivate = isPrivate
        self.status = status
        self.contentType = contentType
        self.senderType = senderType
        self.sender = sender
        self.attachments = attachments
    }

    public func toDomain(allowsInsecureLocalhost: Bool = false) throws -> ConversationMessage {
        guard let id else {
            throw APIError.decodingError("A message was missing its stable identifier.")
        }

        let domainAttachments = (attachments ?? []).enumerated().map { index, attachment in
            attachment.toDomain(
                messageID: id,
                position: index,
                allowsInsecureLocalhost: allowsInsecureLocalhost
            )
        }

        return ConversationMessage(
            id: id,
            content: content,
            processedContent: processedMessageContent,
            kind: ConversationMessageKind(chatwootValue: messageType),
            isPrivate: isPrivate ?? false,
            createdAt: DateParser.parse(createdAt) ?? Date(timeIntervalSince1970: 0),
            senderName: sender?.name,
            senderType: senderType ?? sender?.type,
            deliveryStatus: status,
            contentType: contentType,
            attachments: domainAttachments
        )
    }
}

public struct ChatwootMessageSenderDTO: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let type: String?

    public init(id: Int? = nil, name: String? = nil, type: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
    }
}

public struct ChatwootMessageAttachmentDTO: Codable, Sendable {
    public let id: Int?
    public let fileType: String?
    public let dataURL: String?
    public let thumbnailURL: String?
    public let fileSize: Int?
    public let width: Int?
    public let height: Int?
    public let fileExtension: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fileType = "file_type"
        case dataURL = "data_url"
        case thumbnailURL = "thumb_url"
        case fileSize = "file_size"
        case width
        case height
        case fileExtension = "extension"
    }

    public init(
        id: Int? = nil,
        fileType: String? = nil,
        dataURL: String? = nil,
        thumbnailURL: String? = nil,
        fileSize: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        fileExtension: String? = nil
    ) {
        self.id = id
        self.fileType = fileType
        self.dataURL = dataURL
        self.thumbnailURL = thumbnailURL
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.fileExtension = fileExtension
    }

    public func toDomain(
        messageID: Int,
        position: Int,
        allowsInsecureLocalhost: Bool
    ) -> ConversationAttachment {
        let stablePart = id.map(String.init) ?? "position-\(position)"
        return ConversationAttachment(
            id: "message-\(messageID)-attachment-\(stablePart)",
            serverID: id,
            fileType: ConversationAttachmentType(chatwootValue: fileType),
            dataURL: ConversationAttachment.safeRemoteURL(
                dataURL,
                allowsInsecureLocalhost: allowsInsecureLocalhost
            ),
            thumbnailURL: ConversationAttachment.safeRemoteURL(
                thumbnailURL,
                allowsInsecureLocalhost: allowsInsecureLocalhost
            ),
            fileSize: fileSize,
            width: width,
            height: height,
            fileExtension: fileExtension
        )
    }
}

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}
