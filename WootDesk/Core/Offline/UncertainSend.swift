import Foundation

/// A submitted reply or private note whose server outcome WootDesk could not
/// confirm, because the connection failed after the request left the device.
///
/// The server may or may not have created the message. WootDesk therefore
/// records the attempt rather than reporting either success or plain failure,
/// and warns the agent before a retry that could duplicate it.
public struct UncertainSend: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let scope: ConversationScope
    public let text: String
    public let isPrivateNote: Bool
    public let attachmentCount: Int
    public let attemptedAt: Date

    public init(
        id: UUID = UUID(),
        scope: ConversationScope,
        text: String,
        isPrivateNote: Bool,
        attachmentCount: Int,
        attemptedAt: Date = Date()
    ) {
        self.id = id
        self.scope = scope
        self.text = text
        self.isPrivateNote = isPrivateNote
        self.attachmentCount = attachmentCount
        self.attemptedAt = attemptedAt
    }
}
