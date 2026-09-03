import Foundation

/// Everything WootDesk holds on the device for one conversation.
///
/// The three record kinds share one file so that a write is a single atomic
/// replacement, and so that removing a profile is a directory removal rather
/// than a search across several stores.
public struct ConversationOfflineRecord: Sendable, Codable {
    public var draft: ConversationDraft?
    public var cachedMessages: CachedConversationMessages?
    public var uncertainSends: [UncertainSend]

    public init(
        draft: ConversationDraft? = nil,
        cachedMessages: CachedConversationMessages? = nil,
        uncertainSends: [UncertainSend] = []
    ) {
        self.draft = draft
        self.cachedMessages = cachedMessages
        self.uncertainSends = uncertainSends
    }

    /// A record holding nothing is deleted rather than written, so an agent who
    /// clears a draft leaves no file behind.
    public var isEmpty: Bool {
        draft == nil && cachedMessages == nil && uncertainSends.isEmpty
    }
}

/// Protected, per-profile storage for unsent work and previously loaded content.
///
/// Offline storage is optional. When it is switched off the app injects
/// `DisabledOfflineStore`, every read returns nothing, every write is discarded
/// and no copy is created on the device.
public protocol OfflineStore: Sendable {
    /// Whether this store actually persists anything. Views use it to decide
    /// whether to offer offline affordances at all.
    var isPersisting: Bool { get }

    func loadRecord(for scope: ConversationScope) async throws -> ConversationOfflineRecord

    func saveDraft(_ draft: ConversationDraft) async throws
    func deleteDraft(for scope: ConversationScope) async throws

    func saveCachedMessages(_ cached: CachedConversationMessages) async throws

    func recordUncertainSend(_ send: UncertainSend) async throws
    func clearUncertainSends(for scope: ConversationScope) async throws

    /// Removes every draft, cached page and uncertain-send record belonging to
    /// one saved profile. Called when the agent deletes that profile.
    func removeAllData(forProfile profileID: UUID) async throws
}
