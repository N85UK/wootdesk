import Foundation

/// Applies the agent's offline-storage choice to a backing store.
///
/// While the preference is off, every read returns an empty record and every
/// write is discarded, so no offline copy exists on the device even though the
/// rest of the app keeps calling the same store. Switching the preference off
/// also purges whatever the backing store already holds, so turning the feature
/// off is a deletion rather than only a pause.
public actor ToggleableOfflineStore: OfflineStore {
    private let backing: any OfflineStore
    private let preference: any OfflineStoragePreferenceStore

    public nonisolated var isPersisting: Bool {
        preference.isEnabled()
    }

    public init(
        backing: any OfflineStore,
        preference: any OfflineStoragePreferenceStore
    ) {
        self.backing = backing
        self.preference = preference
    }

    public func loadRecord(for scope: ConversationScope) async throws -> ConversationOfflineRecord {
        guard preference.isEnabled() else { return ConversationOfflineRecord() }
        return try await backing.loadRecord(for: scope)
    }

    public func saveDraft(_ draft: ConversationDraft) async throws {
        guard preference.isEnabled() else { return }
        try await backing.saveDraft(draft)
    }

    public func deleteDraft(for scope: ConversationScope) async throws {
        guard preference.isEnabled() else { return }
        try await backing.deleteDraft(for: scope)
    }

    public func saveCachedMessages(_ cached: CachedConversationMessages) async throws {
        guard preference.isEnabled() else { return }
        try await backing.saveCachedMessages(cached)
    }

    public func recordUncertainSend(_ send: UncertainSend) async throws {
        guard preference.isEnabled() else { return }
        try await backing.recordUncertainSend(send)
    }

    public func clearUncertainSends(for scope: ConversationScope) async throws {
        guard preference.isEnabled() else { return }
        try await backing.clearUncertainSends(for: scope)
    }

    /// Profile removal always reaches the backing store. Records written before
    /// the agent switched offline storage off must still be deleted with the
    /// profile they belong to.
    public func removeAllData(forProfile profileID: UUID) async throws {
        try await backing.removeAllData(forProfile: profileID)
    }

    /// Applies a new preference value, purging existing records when the agent
    /// switches offline storage off.
    public func apply(enabled: Bool, knownProfileIDs: [UUID]) async throws {
        preference.setEnabled(enabled)
        guard !enabled else { return }
        for profileID in knownProfileIDs {
            try await backing.removeAllData(forProfile: profileID)
        }
    }
}
