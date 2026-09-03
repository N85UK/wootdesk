import Foundation

/// The store used when protected offline storage is switched off.
///
/// It satisfies the same contract while keeping nothing: reads return an empty
/// record and writes are discarded. The rest of the app therefore needs no
/// conditional paths to work with offline storage disabled.
public struct DisabledOfflineStore: OfflineStore {
    public var isPersisting: Bool { false }

    public init() {}

    public func loadRecord(for scope: ConversationScope) async throws -> ConversationOfflineRecord {
        ConversationOfflineRecord()
    }

    public func saveDraft(_ draft: ConversationDraft) async throws {}
    public func deleteDraft(for scope: ConversationScope) async throws {}
    public func saveCachedMessages(_ cached: CachedConversationMessages) async throws {}
    public func recordUncertainSend(_ send: UncertainSend) async throws {}
    public func clearUncertainSends(for scope: ConversationScope) async throws {}
    public func removeAllData(forProfile profileID: UUID) async throws {}
}
