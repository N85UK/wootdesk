import Foundation

/// An unsent reply or private note held for one conversation in one profile.
public struct ConversationDraft: Hashable, Sendable, Codable {
    public let scope: ConversationScope
    public let text: String
    public let isPrivateNote: Bool
    public let updatedAt: Date

    public init(
        scope: ConversationScope,
        text: String,
        isPrivateNote: Bool,
        updatedAt: Date = Date()
    ) {
        self.scope = scope
        self.text = text
        self.isPrivateNote = isPrivateNote
        self.updatedAt = updatedAt
    }

    /// A draft holding only whitespace carries nothing worth restoring, so it
    /// is treated as absent rather than written to disk.
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
