import Foundation
import Testing

@testable import WootDesk

/// Exercises the store that actually writes to disk.
///
/// Every other offline test uses `InMemoryOfflineStore`, so the behaviour they
/// prove is the logic, not the filing. That matters most for deletion: PRIVACY.md
/// tells users that removing a server profile removes its drafts and cached
/// messages from the device, and switching offline storage off purges what was
/// already written. Neither claim was covered against `FileOfflineStore`, so
/// nothing would have caught data surviving on disk after either action.
@Suite("File-backed offline storage")
struct FileOfflineStoreTests {
    // MARK: Helpers

    private func makeDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WootDeskOfflineTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func draft(_ scope: ConversationScope, _ text: String) -> ConversationDraft {
        ConversationDraft(scope: scope, text: text, isPrivateNote: false, updatedAt: Date())
    }

    /// Reads every remaining byte under the directory. Synchronous because
    /// `FileManager`'s enumerator cannot be iterated from an async context.
    private func allText(under url: URL) -> String {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil
        ) else { return "" }
        var text = ""
        for case let item as URL in enumerator {
            if let contents = try? String(contentsOf: item, encoding: .utf8) {
                text += contents
            }
        }
        return text
    }

    private func fileCount(under url: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return 0 }
        var count = 0
        for case let item as URL in enumerator {
            let isFile = (try? item.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile
            if isFile == true { count += 1 }
        }
        return count
    }

    // MARK: Tests

    @Test("A draft survives a new store instance reading the same directory")
    func draftSurvivesRestart() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = ConversationScope(profileID: UUID(), accountID: 1, conversationID: 77)

        let writer = FileOfflineStore(customDirectoryURL: directory)
        try await writer.saveDraft(draft(scope, "Unsent work"))

        // A separate instance stands in for the next app launch.
        let reader = FileOfflineStore(customDirectoryURL: directory)
        let record = try await reader.loadRecord(for: scope)
        #expect(record.draft?.text == "Unsent work")
        #expect(fileCount(under: directory) > 0)
    }

    @Test("Removing a profile leaves no file of its own on disk")
    func profileRemovalClearsTheDisk() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let removedID = UUID()
        let keptID = UUID()
        let store = FileOfflineStore(customDirectoryURL: directory)

        try await store.saveDraft(
            draft(ConversationScope(profileID: removedID, accountID: 1, conversationID: 77), "Removed")
        )
        try await store.saveDraft(
            draft(ConversationScope(profileID: keptID, accountID: 1, conversationID: 77), "Kept")
        )
        let before = fileCount(under: directory)
        #expect(before >= 2)

        try await store.removeAllData(forProfile: removedID)

        // The record is gone, and so is the file it was written to. Checking the
        // record alone would pass even if the bytes were still on the device.
        let removed = try await store.loadRecord(
            for: ConversationScope(profileID: removedID, accountID: 1, conversationID: 77)
        )
        #expect(removed.isEmpty)
        #expect(fileCount(under: directory) < before)

        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(!contents.contains(removedID.uuidString))

        let kept = try await store.loadRecord(
            for: ConversationScope(profileID: keptID, accountID: 1, conversationID: 77)
        )
        #expect(kept.draft?.text == "Kept")
    }

    @Test("A removed profile's text is not recoverable by reading the directory")
    func removedTextIsNotOnDisk() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let profileID = UUID()
        let store = FileOfflineStore(customDirectoryURL: directory)
        let secret = "Invented draft \(UUID().uuidString)"

        try await store.saveDraft(
            draft(ConversationScope(profileID: profileID, accountID: 1, conversationID: 77), secret)
        )
        try await store.removeAllData(forProfile: profileID)

        // Read every remaining byte rather than asking the store, because the
        // question is whether the text left the device, not whether the API hides it.
        #expect(!allText(under: directory).contains(secret))
    }

    @Test("Switching offline storage off purges what was already written")
    func disablingPurgesTheDisk() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let profileID = UUID()
        let backing = FileOfflineStore(customDirectoryURL: directory)
        let store = ToggleableOfflineStore(
            backing: backing,
            preference: InMemoryOfflineStoragePreference(enabled: true)
        )
        let scope = ConversationScope(profileID: profileID, accountID: 1, conversationID: 77)

        try await store.saveDraft(draft(scope, "Written while enabled"))
        #expect(fileCount(under: directory) > 0)

        try await store.apply(enabled: false, knownProfileIDs: [profileID])

        #expect(fileCount(under: directory) == 0)
        let record = try await store.loadRecord(for: scope)
        #expect(record.isEmpty)
    }

    @Test("With storage off, nothing new reaches the disk")
    func disabledStoreWritesNothing() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ToggleableOfflineStore(
            backing: FileOfflineStore(customDirectoryURL: directory),
            preference: InMemoryOfflineStoragePreference(enabled: false)
        )
        let scope = ConversationScope(profileID: UUID(), accountID: 1, conversationID: 77)

        try await store.saveDraft(draft(scope, "Should not be written"))

        #expect(fileCount(under: directory) == 0)
    }
}
