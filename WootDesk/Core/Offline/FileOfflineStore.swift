import Foundation

/// Stores protected offline records as JSON beneath Application Support.
///
/// Layout:
///
/// ```
/// Application Support/WootDesk/Offline/
///   <profile-uuid>/
///     account-<id>-conversation-<id>.json
/// ```
///
/// Filing by profile directory is what makes AC5 a single directory removal,
/// and what stops one profile's records being reachable from another.
public actor FileOfflineStore: OfflineStore {
    private let rootURL: URL
    private let fileManager: FileManager

    public nonisolated var isPersisting: Bool { true }

    public init(
        customDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let customDirectoryURL {
            self.rootURL = customDirectoryURL
        } else {
            let appSupport = fileManager
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.rootURL = appSupport
                .appendingPathComponent("WootDesk", isDirectory: true)
                .appendingPathComponent("Offline", isDirectory: true)
        }
    }

    // MARK: - Reading

    public func loadRecord(for scope: ConversationScope) async throws -> ConversationOfflineRecord {
        let url = recordURL(for: scope)
        guard fileManager.fileExists(atPath: url.path) else {
            return ConversationOfflineRecord()
        }

        do {
            let data = try Data(contentsOf: url)
            return try Self.decoder.decode(ConversationOfflineRecord.self, from: data)
        } catch {
            // A cached page is rebuildable from the server and an unreadable
            // draft cannot be recovered, so a damaged record is discarded
            // rather than left on the device holding message content.
            AppLogger.persistence.error("An offline conversation record could not be read and was discarded.")
            try? fileManager.removeItem(at: url)
            return ConversationOfflineRecord()
        }
    }

    // MARK: - Writing

    public func saveDraft(_ draft: ConversationDraft) async throws {
        guard !draft.isEmpty else {
            try await deleteDraft(for: draft.scope)
            return
        }
        try await mutate(draft.scope) { record in
            record.draft = draft
        }
    }

    public func deleteDraft(for scope: ConversationScope) async throws {
        try await mutate(scope) { record in
            record.draft = nil
        }
    }

    public func saveCachedMessages(_ cached: CachedConversationMessages) async throws {
        try await mutate(cached.scope) { record in
            record.cachedMessages = cached
        }
    }

    public func recordUncertainSend(_ send: UncertainSend) async throws {
        try await mutate(send.scope) { record in
            record.uncertainSends.append(send)
        }
    }

    public func clearUncertainSends(for scope: ConversationScope) async throws {
        try await mutate(scope) { record in
            record.uncertainSends = []
        }
    }

    // MARK: - Deletion

    public func removeAllData(forProfile profileID: UUID) async throws {
        let directory = rootURL.appendingPathComponent(
            profileID.uuidString,
            isDirectory: true
        )
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
        AppLogger.persistence.debug("Removed the offline directory for a deleted profile.")
    }

    // MARK: - Private Helpers

    private func mutate(
        _ scope: ConversationScope,
        _ change: (inout ConversationOfflineRecord) -> Void
    ) async throws {
        var record = try await loadRecord(for: scope)
        change(&record)

        let url = recordURL(for: scope)
        guard !record.isEmpty else {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return
        }

        try ensureProfileDirectoryExists(for: scope)
        let data = try Self.encoder.encode(record)
        try data.write(to: url, options: Self.writingOptions)
    }

    private func recordURL(for scope: ConversationScope) -> URL {
        rootURL
            .appendingPathComponent(scope.profileDirectoryName, isDirectory: true)
            .appendingPathComponent(scope.recordFileName)
    }

    private func ensureProfileDirectoryExists(for scope: ConversationScope) throws {
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try excludeFromBackup(rootURL)
        }

        let directory = rootURL.appendingPathComponent(
            scope.profileDirectoryName,
            isDirectory: true
        )
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Keeps cached message content and unsent drafts out of device backups.
    /// A failure here is not fatal: the records are still protected at rest.
    private func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutableURL.setResourceValues(values)
        } catch {
            AppLogger.persistence.error("The offline directory could not be excluded from backup.")
        }
    }

    /// On iOS the records stay encrypted until the device has been unlocked
    /// once after boot, which matches how the Chatwoot token is held in the
    /// Keychain. macOS has no equivalent per-file class and relies on FileVault.
    private static var writingOptions: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        [.atomic]
        #endif
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
