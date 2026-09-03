import Foundation

/// Identifies the single conversation, inside one account, inside one saved
/// server profile, that owns a piece of protected offline data.
///
/// Every offline record is filed under a scope. Nothing is ever read or written
/// without one, which is what keeps a draft or a cached page from leaking
/// between profiles when an agent switches server.
public struct ConversationScope: Hashable, Sendable, Codable {
    public let profileID: UUID
    public let accountID: Int
    public let conversationID: Int

    public init(profileID: UUID, accountID: Int, conversationID: Int) {
        self.profileID = profileID
        self.accountID = accountID
        self.conversationID = conversationID
    }

    /// The directory name holding every offline record for one profile.
    ///
    /// A UUID string contains only hex digits and hyphens, so it is already
    /// safe as a path component and needs no escaping.
    public var profileDirectoryName: String {
        profileID.uuidString
    }

    /// A stable, filesystem-safe file name for this conversation's records.
    ///
    /// Account and conversation identifiers are Chatwoot integers, so the
    /// composed name cannot contain a path separator or a relative segment.
    public var recordFileName: String {
        "account-\(accountID)-conversation-\(conversationID).json"
    }
}
