import Testing
import Foundation
@testable import WootDesk

@Suite("AppModel and Feature State Tests")
struct AppModelAndFeatureTests {

    @Test("Adding a connection saves profile and stores token")
    @MainActor
    func testAddConnectionFlow() async throws {
        let env = AppEnvironment.preview()
        let appModel = AppModel(environment: env)

        let account = ChatwootAccount(id: 1, name: "Acme Main", role: "administrator")
        let url = URL(string: "https://chatwoot.example.com")!
        let token = "test"

        try await appModel.addConnection(
            displayName: "Acme Main Support",
            baseURL: url,
            token: token,
            account: account
        )

        #expect(appModel.profiles.count == 1)
        #expect(appModel.activeProfile?.displayName == "Acme Main Support")
        #expect(appModel.activeProfile?.selectedAccountID == 1)

        // Verify token in credential store
        let profileID = appModel.activeProfile!.id
        let storedToken = try env.credentialStore.loadToken(for: profileID)
        #expect(storedToken == token)
    }

    @Test("Deleting a profile removes it and deletes its credential")
    @MainActor
    func testDeleteProfileDeletesCredential() async throws {
        let profile1 = ServerProfile(
            id: UUID(),
            displayName: "Profile 1",
            baseURL: URL(string: "https://p1.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Acc 1"
        )
        let profile2 = ServerProfile(
            id: UUID(),
            displayName: "Profile 2",
            baseURL: URL(string: "https://p2.example.com")!,
            selectedAccountID: 2,
            selectedAccountName: "Acc 2"
        )

        let env = AppEnvironment.preview(
            profiles: [profile1, profile2],
            activeProfileID: profile1.id,
            tokens: [profile1.id: "token1", profile2.id: "token2"]
        )
        let appModel = AppModel(environment: env)
        await appModel.initialize()

        #expect(appModel.profiles.count == 2)
        #expect(appModel.activeProfile?.id == profile1.id)

        // Delete profile 1
        await appModel.deleteProfile(id: profile1.id)

        #expect(appModel.profiles.count == 1)
        #expect(appModel.profiles.first?.id == profile2.id)
        #expect(appModel.activeProfile?.id == profile2.id)

        // Verify token for profile1 was deleted
        let deletedToken = try env.credentialStore.loadToken(for: profile1.id)
        #expect(deletedToken == nil)

        // Verify token for profile2 is still intact
        let remainingToken = try env.credentialStore.loadToken(for: profile2.id)
        #expect(remainingToken == "token2")
    }

    @Test("Selecting a profile whose credential is missing leaves no active profile")
    @MainActor
    func testMissingCredentialClearsActiveProfile() async {
        let profile = ServerProfile(
            displayName: "Orphaned Profile",
            baseURL: URL(string: "https://orphan.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Account 1"
        )
        // Profile metadata exists, but no token was ever stored for it.
        let env = AppEnvironment.preview(profiles: [profile], activeProfileID: profile.id)
        let appModel = AppModel(environment: env)

        await appModel.initialize()

        #expect(appModel.activeProfile == nil)
        #expect(appModel.activeToken == nil)
        #expect(appModel.lastError != nil)
    }

    @Test("Restores the previously active profile and its token on launch")
    @MainActor
    func testRestoresActiveProfileOnLaunch() async {
        let first = ServerProfile(
            displayName: "First",
            baseURL: URL(string: "https://first.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Account 1"
        )
        let second = ServerProfile(
            displayName: "Second",
            baseURL: URL(string: "https://second.example.com")!,
            selectedAccountID: 2,
            selectedAccountName: "Account 2"
        )
        let env = AppEnvironment.preview(
            profiles: [first, second],
            activeProfileID: second.id,
            tokens: [first.id: "token-1", second.id: "token-2"]
        )
        let appModel = AppModel(environment: env)

        await appModel.initialize()

        #expect(appModel.activeProfile?.id == second.id)
        #expect(appModel.activeToken == "token-2")
        #expect(appModel.isInitializing == false)
    }

    @Test("Deleting the final profile leaves the app in its first-run state")
    @MainActor
    func testDeletingLastProfileReturnsToFirstRun() async {
        let only = ServerProfile(
            displayName: "Only",
            baseURL: URL(string: "https://only.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Account 1"
        )
        let env = AppEnvironment.preview(
            profiles: [only],
            activeProfileID: only.id,
            tokens: [only.id: "token"]
        )
        let appModel = AppModel(environment: env)
        await appModel.initialize()

        await appModel.deleteProfile(id: only.id)

        #expect(appModel.profiles.isEmpty)
        #expect(appModel.activeProfile == nil)
        #expect(appModel.activeToken == nil)
        #expect(try! env.credentialStore.loadToken(for: only.id) == nil)
        #expect(try! await env.profileRepository.loadActiveProfileID() == nil)
    }

    @Test("Deleting the active profile does not activate an insecure saved profile in release policy")
    @MainActor
    func testDeleteDoesNotActivateInsecureFallbackProfile() async {
        let active = ServerProfile(
            displayName: "Secure",
            baseURL: URL(string: "https://secure.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Secure Account"
        )
        let insecure = ServerProfile(
            displayName: "Local Development",
            baseURL: URL(string: "http://localhost:3000")!,
            selectedAccountID: 2,
            selectedAccountName: "Local Account"
        )
        let repository = InMemoryServerProfileRepository(
            initialProfiles: [active, insecure],
            initialActiveProfileID: active.id
        )
        let credentials = InMemoryCredentialStore(
            initialTokens: [active.id: "secure-token", insecure.id: "local-token"]
        )
        let environment = AppEnvironment(
            apiClient: StubChatwootAPI(),
            profileRepository: repository,
            credentialStore: credentials,
            isDebug: false
        )
        let appModel = AppModel(environment: environment)
        await appModel.initialize()

        await appModel.deleteProfile(id: active.id)

        #expect(appModel.profiles.map(\.id) == [insecure.id])
        #expect(appModel.activeProfile == nil)
        #expect(appModel.activeToken == nil)
        #expect((try? credentials.loadToken(for: active.id)) == nil)
        #expect((try? credentials.loadToken(for: insecure.id)) == "local-token")
        #expect((try? await repository.loadActiveProfileID()) == nil)
    }

    @Test("Revalidating a profile updates metadata and credential without changing its identity")
    @MainActor
    func testUpdateConnectionPreservesProfileIdentity() async throws {
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = ServerProfile(
            displayName: "Original",
            baseURL: URL(string: "https://old.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Original Account",
            createdAt: originalDate,
            lastUsedAt: originalDate
        )
        let env = AppEnvironment.preview(
            profiles: [profile],
            activeProfileID: profile.id,
            tokens: [profile.id: "old-token"]
        )
        let appModel = AppModel(environment: env)
        await appModel.initialize()

        try await appModel.updateConnection(
            profileID: profile.id,
            displayName: "Updated",
            baseURL: URL(string: "https://new.example.com/support")!,
            token: "new-token",
            account: ChatwootAccount(id: 9, name: "Updated Account")
        )

        let updated = try #require(appModel.activeProfile)
        #expect(updated.id == profile.id)
        #expect(updated.createdAt == originalDate)
        #expect(updated.displayName == "Updated")
        #expect(updated.baseURL.absoluteString == "https://new.example.com/support")
        #expect(updated.selectedAccountID == 9)
        #expect(try env.credentialStore.loadToken(for: profile.id) == "new-token")
    }

    @Test("A failed profile update restores the previous credential and metadata")
    @MainActor
    func testUpdateConnectionRollsBackOnPersistenceFailure() async throws {
        let profile = ServerProfile(
            displayName: "Original",
            baseURL: URL(string: "https://original.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Original Account"
        )
        let repository = FaultInjectingProfileRepository(
            profiles: [profile],
            activeProfileID: profile.id
        )
        let credentials = FaultInjectingCredentialStore(tokens: [profile.id: "original-token"])
        let environment = AppEnvironment(
            apiClient: StubChatwootAPI(),
            profileRepository: repository,
            credentialStore: credentials,
            isDebug: true
        )
        let appModel = AppModel(environment: environment)
        await appModel.initialize()
        let restoredProfile = try #require(appModel.activeProfile)
        await repository.failNextProfileSave()

        do {
            try await appModel.updateConnection(
                profileID: profile.id,
                displayName: "Changed",
                baseURL: URL(string: "https://changed.example.com")!,
                token: "new",
                account: ChatwootAccount(id: 9, name: "Changed Account")
            )
            Issue.record("Expected profile persistence to fail")
        } catch {
            #expect(error as? AppModelError == .persistenceFailed)
        }

        #expect(appModel.activeProfile == restoredProfile)
        #expect(appModel.profiles == [restoredProfile])
        #expect(credentials.token(for: profile.id) == "original-token")
        #expect(try await repository.loadProfiles() == [restoredProfile])
    }

    @Test("Release policy rejects a saved HTTP profile before loading its credential")
    @MainActor
    func testReleasePolicyRejectsPersistedHTTPProfile() async {
        let profile = ServerProfile(
            displayName: "Local Development",
            baseURL: URL(string: "http://localhost:3000")!,
            selectedAccountID: 1,
            selectedAccountName: "Local Account"
        )
        let environment = AppEnvironment(
            apiClient: StubChatwootAPI(),
            profileRepository: InMemoryServerProfileRepository(
                initialProfiles: [profile],
                initialActiveProfileID: profile.id
            ),
            credentialStore: InMemoryCredentialStore(initialTokens: [profile.id: "local-token"]),
            isDebug: false
        )
        let appModel = AppModel(environment: environment)

        await appModel.initialize()

        #expect(appModel.profiles == [profile])
        #expect(appModel.activeProfile == nil)
        #expect(appModel.activeToken == nil)
        #expect(appModel.lastError == APIError.insecureScheme.errorDescription)
    }

    @Test("A failed profile save rolls back a newly added credential")
    @MainActor
    func testAddConnectionRollsBackOnPersistenceFailure() async {
        let repository = FaultInjectingProfileRepository()
        let credentials = FaultInjectingCredentialStore()
        let env = AppEnvironment(
            apiClient: StubChatwootAPI(),
            profileRepository: repository,
            credentialStore: credentials,
            isDebug: true
        )
        let appModel = AppModel(environment: env)
        await repository.failNextProfileSave()

        do {
            try await appModel.addConnection(
                displayName: "Sample",
                baseURL: URL(string: "https://sample.example.com")!,
                token: "test",
                account: ChatwootAccount(id: 1, name: "Sample Account")
            )
            Issue.record("Expected profile persistence to fail")
        } catch {
            #expect(error as? AppModelError == .persistenceFailed)
        }

        #expect(appModel.profiles.isEmpty)
        #expect(appModel.activeProfile == nil)
        #expect(credentials.storedCredentialCount() == 0)
        #expect((try? await repository.loadProfiles())?.isEmpty == true)
        #expect((try? await repository.loadActiveProfileID()) == nil)
    }

    @Test("A failed credential deletion restores profile metadata")
    @MainActor
    func testDeleteRollsBackWhenCredentialDeletionFails() async throws {
        let profile = ServerProfile(
            displayName: "Protected",
            baseURL: URL(string: "https://protected.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Protected Account"
        )
        let repository = FaultInjectingProfileRepository(
            profiles: [profile],
            activeProfileID: profile.id
        )
        let credentials = FaultInjectingCredentialStore(tokens: [profile.id: "retained-token"])
        let env = AppEnvironment(
            apiClient: StubChatwootAPI(),
            profileRepository: repository,
            credentialStore: credentials,
            isDebug: true
        )
        let appModel = AppModel(environment: env)
        await appModel.initialize()
        credentials.failCredentialDeletion()

        await appModel.deleteProfile(id: profile.id)

        #expect(appModel.profiles.map(\.id) == [profile.id])
        #expect(appModel.activeProfile?.id == profile.id)
        #expect(credentials.token(for: profile.id) == "retained-token")
        #expect(try await repository.loadProfiles().map(\.id) == [profile.id])
        #expect(try await repository.loadActiveProfileID() == profile.id)
        #expect(appModel.lastError != nil)
    }
}

private enum InjectedStoreError: Error {
    case expectedFailure
}

private actor FaultInjectingProfileRepository: ServerProfileRepository {
    private var profiles: [ServerProfile]
    private var activeProfileID: UUID?
    private var remainingProfileSaveFailures = 0

    init(profiles: [ServerProfile] = [], activeProfileID: UUID? = nil) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    func failNextProfileSave() {
        remainingProfileSaveFailures += 1
    }

    func loadProfiles() async throws -> [ServerProfile] {
        profiles
    }

    func saveProfiles(_ profiles: [ServerProfile]) async throws {
        if remainingProfileSaveFailures > 0 {
            remainingProfileSaveFailures -= 1
            throw InjectedStoreError.expectedFailure
        }
        self.profiles = profiles
    }

    func loadActiveProfileID() async throws -> UUID? {
        activeProfileID
    }

    func saveActiveProfileID(_ id: UUID?) async throws {
        activeProfileID = id
    }
}

private final class FaultInjectingCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [UUID: String]
    private var shouldFailDeletion = false

    init(tokens: [UUID: String] = [:]) {
        self.tokens = tokens
    }

    func saveToken(_ token: String, for profileID: UUID) throws {
        lock.withLock {
            tokens[profileID] = token
        }
    }

    func loadToken(for profileID: UUID) throws -> String? {
        lock.withLock { tokens[profileID] }
    }

    func deleteToken(for profileID: UUID) throws {
        try lock.withLock {
            if shouldFailDeletion {
                throw InjectedStoreError.expectedFailure
            }
            tokens.removeValue(forKey: profileID)
        }
    }

    func failCredentialDeletion() {
        lock.withLock {
            shouldFailDeletion = true
        }
    }

    func token(for profileID: UUID) -> String? {
        lock.withLock { tokens[profileID] }
    }

    func storedCredentialCount() -> Int {
        lock.withLock { tokens.count }
    }
}
