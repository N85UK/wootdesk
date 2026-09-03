import Foundation

/// A deterministic offline store for tests and previews.
///
/// It keeps the same per-profile filing as the file-backed store so that
/// profile removal and cross-profile isolation are exercised identically.
public actor InMemoryOfflineStore: OfflineStore {
    private var records: [ConversationScope: ConversationOfflineRecord]

    public nonisolated var isPersisting: Bool { true }

    public init(records: [ConversationScope: ConversationOfflineRecord] = [:]) {
        self.records = records
    }

    public func loadRecord(for scope: ConversationScope) async throws -> ConversationOfflineRecord {
        records[scope] ?? ConversationOfflineRecord()
    }

    public func saveDraft(_ draft: ConversationDraft) async throws {
        guard !draft.isEmpty else {
            try await deleteDraft(for: draft.scope)
            return
        }
        mutate(draft.scope) { $0.draft = draft }
    }

    public func deleteDraft(for scope: ConversationScope) async throws {
        mutate(scope) { $0.draft = nil }
    }

    public func saveCachedMessages(_ cached: CachedConversationMessages) async throws {
        mutate(cached.scope) { $0.cachedMessages = cached }
    }

    public func recordUncertainSend(_ send: UncertainSend) async throws {
        mutate(send.scope) { $0.uncertainSends.append(send) }
    }

    public func clearUncertainSends(for scope: ConversationScope) async throws {
        mutate(scope) { $0.uncertainSends = [] }
    }

    public func removeAllData(forProfile profileID: UUID) async throws {
        records = records.filter { $0.key.profileID != profileID }
    }

    /// The number of conversations currently holding any record, used by tests
    /// to assert that removal actually emptied the store.
    public func recordCount() -> Int {
        records.count
    }

    private func mutate(
        _ scope: ConversationScope,
        _ change: (inout ConversationOfflineRecord) -> Void
    ) {
        var record = records[scope] ?? ConversationOfflineRecord()
        change(&record)
        if record.isEmpty {
            records.removeValue(forKey: scope)
        } else {
            records[scope] = record
        }
    }
}
