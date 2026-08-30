import Testing
import Foundation
@testable import WootDesk

@Suite("Credential Store Tests")
struct CredentialStoreTests {

    @Test("InMemoryCredentialStore handles save, load, update, and delete")
    func testCredentialStoreCRUD() throws {
        let store = InMemoryCredentialStore()
        let profileID = UUID()
        let initialToken = "token_alpha_123"

        // 1. Save and Load
        try store.saveToken(initialToken, for: profileID)
        let loaded = try store.loadToken(for: profileID)
        #expect(loaded == initialToken)

        // 2. Update
        let updatedToken = "token_beta_456"
        try store.saveToken(updatedToken, for: profileID)
        let loadedUpdated = try store.loadToken(for: profileID)
        #expect(loadedUpdated == updatedToken)

        // 3. Delete
        try store.deleteToken(for: profileID)
        let loadedDeleted = try store.loadToken(for: profileID)
        #expect(loadedDeleted == nil)
    }
}
