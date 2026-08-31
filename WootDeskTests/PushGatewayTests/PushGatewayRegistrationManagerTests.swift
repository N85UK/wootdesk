import Foundation
import Testing
@testable import WootDesk

@Suite("Push Gateway Registration Manager Tests")
struct PushGatewayRegistrationManagerTests {
    private let fixedDeviceID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

    @Test("Secure configuration store saves, updates, reads, and deletes through a fake Keychain")
    func secureConfigurationRoundTrip() async throws {
        let keychain = InMemoryCredentialStore()
        let store = KeychainPushGatewayConfigurationStore(credentialStore: keychain)
        let profile = sampleProfile()
        let first = configuration(profile: profile, apiToken: validAPIToken("a"))

        try await store.saveConfiguration(first, for: profile.id)
        #expect(try await store.loadConfiguration(for: profile.id) == first)
        #expect(try keychain.loadToken(for: profile.id) != nil)

        let updated = configuration(profile: profile, apiToken: validAPIToken("b"))
        try await store.saveConfiguration(updated, for: profile.id)
        #expect(try await store.loadConfiguration(for: profile.id) == updated)

        try await store.deleteConfiguration(for: profile.id)
        #expect(try await store.loadConfiguration(for: profile.id) == nil)
        #expect(try keychain.loadToken(for: profile.id) == nil)
    }

    @Test("Enrolment creates one stable per-profile device registration")
    func createsRegistration() async throws {
        let api = RecordingPushGatewayAPI()
        let store = InMemoryPushGatewayConfigurationStore()
        let manager = makeManager(api: api, store: store)
        let profile = sampleProfile()

        let summary = try await manager.configure(
            baseURL: " https://push.example.com/wootdesk/ ",
            apiToken: validAPIToken("a"),
            profile: profile,
            deviceToken: Data([0x01, 0x02, 0x03, 0x04]),
            environment: .development
        )

        #expect(summary.baseURL.absoluteString == "https://push.example.com/wootdesk")
        #expect(summary.profileID == profile.id)
        #expect(summary.accountID == profile.selectedAccountID)
        let events = await api.events()
        #expect(events.count == 1)
        guard case .create(let registration, let key) = events[0] else {
            Issue.record("Expected a create event")
            return
        }
        #expect(registration.deviceId == fixedDeviceID)
        #expect(registration.token == "01020304")
        #expect(registration.topic == "dev.n85.wootdesk")
        #expect(key == "fixed-idempotency-key")

        let stored = await store.loadConfiguration(for: profile.id)
        #expect(stored?.deviceID == fixedDeviceID)
        #expect(stored?.apiToken == validAPIToken("a"))
    }

    @Test("A rotated APNs token updates the existing registration")
    func refreshesRegistration() async throws {
        let profile = sampleProfile()
        let store = InMemoryPushGatewayConfigurationStore(
            configurations: [profile.id: configuration(profile: profile, apiToken: validAPIToken("a"))]
        )
        let api = RecordingPushGatewayAPI()
        let manager = makeManager(api: api, store: store)

        let summary = try await manager.refreshRegistration(
            profile: profile,
            deviceToken: Data([0xaa, 0xbb]),
            environment: .production
        )

        #expect(summary?.deviceID == fixedDeviceID)
        #expect(summary?.environment == .production)
        let events = await api.events()
        guard case .update(let registration, _) = try #require(events.first) else {
            Issue.record("Expected an update event")
            return
        }
        #expect(registration.deviceId == fixedDeviceID)
        #expect(registration.token == "aabb")
        #expect(registration.environment == .production)
    }

    @Test("Removing enrolment deletes the remote registration before local credentials")
    func removesRegistration() async throws {
        let profile = sampleProfile()
        let store = InMemoryPushGatewayConfigurationStore(
            configurations: [profile.id: configuration(profile: profile, apiToken: validAPIToken("a"))]
        )
        let api = RecordingPushGatewayAPI()
        let manager = makeManager(api: api, store: store)

        try await manager.removeRegistration(for: profile.id)

        #expect(await store.loadConfiguration(for: profile.id) == nil)
        let events = await api.events()
        guard case .delete(let deviceID, _) = try #require(events.first) else {
            Issue.record("Expected a delete event")
            return
        }
        #expect(deviceID == fixedDeviceID)
    }

    @Test("A failed remote removal keeps the local gateway configuration")
    func failedRemovalKeepsConfiguration() async throws {
        let profile = sampleProfile()
        let existing = configuration(profile: profile, apiToken: validAPIToken("a"))
        let store = InMemoryPushGatewayConfigurationStore(configurations: [profile.id: existing])
        let api = RecordingPushGatewayAPI(deleteError: PushGatewayAPIError.unavailable)
        let manager = makeManager(api: api, store: store)

        do {
            try await manager.removeRegistration(for: profile.id)
            Issue.record("Expected remote removal to fail")
        } catch let error as PushGatewayAPIError {
            #expect(error == .unavailable)
        }

        #expect(await store.loadConfiguration(for: profile.id) == existing)
    }

    @Test("An invalid device API token is rejected before a request")
    func rejectsInvalidDeviceCredential() async {
        let api = RecordingPushGatewayAPI()
        let manager = makeManager(api: api, store: InMemoryPushGatewayConfigurationStore())

        do {
            _ = try await manager.configure(
                baseURL: "https://push.example.com",
                apiToken: "not-valid",
                profile: sampleProfile(),
                deviceToken: Data([0x01]),
                environment: .development
            )
            Issue.record("Expected the gateway credential to be rejected")
        } catch let error as PushGatewayRegistrationError {
            #expect(error == .missingCredential)
        } catch {
            Issue.record("Expected PushGatewayRegistrationError")
        }

        #expect(await api.events().isEmpty)
    }

    private func makeManager(
        api: RecordingPushGatewayAPI,
        store: PushGatewayConfigurationStore
    ) -> PushGatewayRegistrationManager {
        PushGatewayRegistrationManager(
            api: api,
            store: store,
            isDebug: false,
            idempotencyKey: { "fixed-idempotency-key" },
            makeDeviceID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )
    }

    private func sampleProfile() -> ServerProfile {
        ServerProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            displayName: "Invented Support",
            baseURL: URL(string: "https://chatwoot.example.com")!,
            selectedAccountID: 42,
            selectedAccountName: "Invented Account"
        )
    }

    private func configuration(
        profile: ServerProfile,
        apiToken: String
    ) -> PushGatewayConfiguration {
        PushGatewayConfiguration(
            baseURL: URL(string: "https://push.example.com")!,
            apiToken: apiToken,
            deviceID: fixedDeviceID,
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            environment: .development,
            topic: "dev.n85.wootdesk",
            updatedAt: Date(timeIntervalSince1970: 1_788_115_200)
        )
    }

    private func validAPIToken(_ character: Character) -> String {
        String(repeating: character, count: 43)
    }
}

private actor RecordingPushGatewayAPI: PushGatewayAPIProtocol {
    enum Event: Sendable {
        case create(PushGatewayDeviceRegistrationRequest, String)
        case update(PushGatewayDeviceRegistrationRequest, String)
        case delete(UUID, String)
    }

    private var recordedEvents: [Event] = []
    private let deleteError: PushGatewayAPIError?

    init(deleteError: PushGatewayAPIError? = nil) {
        self.deleteError = deleteError
    }

    func createRegistration(
        baseURL: URL,
        apiToken: String,
        registration: PushGatewayDeviceRegistrationRequest,
        idempotencyKey: String
    ) -> PushGatewayDeviceRegistration {
        recordedEvents.append(.create(registration, idempotencyKey))
        return response(for: registration)
    }

    func updateRegistration(
        baseURL: URL,
        apiToken: String,
        registration: PushGatewayDeviceRegistrationRequest,
        idempotencyKey: String
    ) -> PushGatewayDeviceRegistration {
        recordedEvents.append(.update(registration, idempotencyKey))
        return response(for: registration)
    }

    func deleteRegistration(
        baseURL: URL,
        apiToken: String,
        deviceID: UUID,
        idempotencyKey: String
    ) throws {
        recordedEvents.append(.delete(deviceID, idempotencyKey))
        if let deleteError {
            throw deleteError
        }
    }

    func events() -> [Event] {
        recordedEvents
    }

    private func response(
        for registration: PushGatewayDeviceRegistrationRequest
    ) -> PushGatewayDeviceRegistration {
        PushGatewayDeviceRegistration(
            deviceId: registration.deviceId,
            profileId: registration.profileId,
            accountId: registration.accountId,
            environment: registration.environment,
            topic: registration.topic,
            updatedAt: "2026-08-31T12:00:00.000Z"
        )
    }
}
