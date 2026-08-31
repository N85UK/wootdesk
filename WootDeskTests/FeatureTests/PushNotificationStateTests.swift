import Foundation
import Testing
@testable import WootDesk

@Suite("Push Notification State Tests")
struct PushNotificationStateTests {
    @Test("An already authorised launch registers with APNs")
    @MainActor
    func authorisedLaunchRegistersWithApple() async {
        let permissionClient = FakeNotificationPermissionClient(status: .authorised)
        let recorder = RegistrationRecorder()
        let state = PushNotificationState(permissionClient: permissionClient)

        await state.configure {
            recorder.record()
        }

        #expect(state.authorisationStatus == .authorised)
        #expect(state.registrationStatus == .registering)
        #expect(recorder.registrationCount == 1)
    }

    @Test("Granting permission starts APNs registration")
    @MainActor
    func grantingPermissionStartsRegistration() async {
        let permissionClient = FakeNotificationPermissionClient(
            status: .notDetermined,
            statusAfterRequest: .authorised
        )
        let recorder = RegistrationRecorder()
        let state = PushNotificationState(permissionClient: permissionClient)
        await state.configure {
            recorder.record()
        }

        await state.requestAuthorisation()

        #expect(state.authorisationStatus == .authorised)
        #expect(state.registrationStatus == .registering)
        #expect(recorder.registrationCount == 1)
        #expect(await permissionClient.requestCount == 1)
    }

    @Test("Denied permission does not start APNs registration")
    @MainActor
    func deniedPermissionDoesNotRegister() async {
        let permissionClient = FakeNotificationPermissionClient(
            status: .notDetermined,
            statusAfterRequest: .denied
        )
        let recorder = RegistrationRecorder()
        let state = PushNotificationState(permissionClient: permissionClient)
        await state.configure {
            recorder.record()
        }

        await state.requestAuthorisation()

        #expect(state.authorisationStatus == .denied)
        #expect(state.registrationStatus == .idle)
        #expect(recorder.registrationCount == 0)
    }

    @Test("Returning from System Settings retries APNs registration after permission is granted")
    @MainActor
    func permissionRefreshRetriesRegistration() async {
        let permissionClient = FakeNotificationPermissionClient(status: .denied)
        let recorder = RegistrationRecorder()
        let state = PushNotificationState(permissionClient: permissionClient)
        await state.configure {
            recorder.record()
        }
        #expect(recorder.registrationCount == 0)

        await permissionClient.setStatus(.authorised)
        await state.refreshAuthorisationStatus()
        await state.refreshAuthorisationStatus()

        #expect(state.authorisationStatus == .authorised)
        #expect(state.registrationStatus == .registering)
        #expect(recorder.registrationCount == 1)
    }

    @Test("Apple registration records only in-memory token availability")
    @MainActor
    func appleRegistrationRecordsTokenAvailability() async {
        let state = PushNotificationState(
            permissionClient: FakeNotificationPermissionClient(status: .authorised)
        )

        state.didRegisterForRemoteNotifications(deviceToken: Data([0x01, 0x02, 0x03]))

        #expect(state.registrationStatus == .registeredWithApple)
        #expect(state.hasCurrentDeviceToken)
        #expect(state.errorMessage == nil)
    }

    @Test("A local verification notification requires permission")
    @MainActor
    func verificationNotificationRequiresPermission() async {
        let permissionClient = FakeNotificationPermissionClient(status: .denied)
        let state = PushNotificationState(permissionClient: permissionClient)
        await state.refreshAuthorisationStatus()

        await state.sendVerificationNotification()

        #expect(await permissionClient.verificationCount == 0)
        #expect(state.errorMessage != nil)
    }

    @Test("An authorised local verification notification is scheduled")
    @MainActor
    func authorisedVerificationNotificationIsScheduled() async {
        let permissionClient = FakeNotificationPermissionClient(status: .authorised)
        let state = PushNotificationState(permissionClient: permissionClient)
        await state.refreshAuthorisationStatus()

        await state.sendVerificationNotification()

        #expect(await permissionClient.verificationCount == 1)
        #expect(state.errorMessage == nil)
    }

    @Test("An Apple device token refreshes the saved gateway enrolment")
    @MainActor
    func appleTokenRefreshesGatewayEnrolment() async {
        let profile = notificationProfile()
        let gateway = FakePushGatewayRegistrationManager(
            summary: gatewaySummary(for: profile)
        )
        let state = PushNotificationState(
            permissionClient: FakeNotificationPermissionClient(status: .authorised),
            gatewayManager: gateway,
            gatewayEnvironment: .development
        )
        await state.updateProfileContext(profiles: [profile], activeProfile: profile)

        state.didRegisterForRemoteNotifications(deviceToken: Data([0x0a, 0x0b]))
        await waitForRefresh(on: gateway)

        #expect(await gateway.refreshCount == 1)
        #expect(await gateway.lastDeviceToken == Data([0x0a, 0x0b]))
        #expect(state.gatewayStatus == .enrolled(host: "push.example.com"))
    }

    @Test("Manual gateway enrolment requires and forwards the current Apple token")
    @MainActor
    func manuallyEnrolsGateway() async {
        let profile = notificationProfile()
        let gateway = FakePushGatewayRegistrationManager()
        let state = PushNotificationState(
            permissionClient: FakeNotificationPermissionClient(status: .authorised),
            gatewayManager: gateway,
            gatewayEnvironment: .development
        )
        await state.updateProfileContext(profiles: [profile], activeProfile: profile)
        state.didRegisterForRemoteNotifications(deviceToken: Data([0x01, 0x02]))

        await state.configureGateway(
            baseURL: "https://push.example.com",
            apiToken: String(repeating: "g", count: 43)
        )

        #expect(await gateway.configureCount == 1)
        #expect(await gateway.lastDeviceToken == Data([0x01, 0x02]))
        #expect(state.gatewaySummary?.profileID == profile.id)
        #expect(state.gatewayStatus == .enrolled(host: "push.example.com"))
        #expect(state.gatewayErrorMessage == nil)
    }

    @Test("Disabling remote notifications removes the active profile enrolment")
    @MainActor
    func removesGatewayEnrolment() async {
        let profile = notificationProfile()
        let gateway = FakePushGatewayRegistrationManager(
            summary: gatewaySummary(for: profile)
        )
        let state = PushNotificationState(
            permissionClient: FakeNotificationPermissionClient(status: .authorised),
            gatewayManager: gateway
        )
        await state.updateProfileContext(profiles: [profile], activeProfile: profile)

        await state.removeGatewayRegistration()

        #expect(await gateway.removedProfileID == profile.id)
        #expect(state.gatewaySummary == nil)
        #expect(state.gatewayStatus == .notConfigured)
    }

    private func notificationProfile() -> ServerProfile {
        ServerProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            displayName: "Invented Support",
            baseURL: URL(string: "https://chatwoot.example.com")!,
            selectedAccountID: 42,
            selectedAccountName: "Invented Account"
        )
    }

    private func gatewaySummary(
        for profile: ServerProfile
    ) -> PushGatewayConfigurationSummary {
        PushGatewayConfigurationSummary(
            baseURL: URL(string: "https://push.example.com")!,
            deviceID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            environment: .development,
            updatedAt: Date(timeIntervalSince1970: 1_788_115_200)
        )
    }

    private func waitForRefresh(
        on gateway: FakePushGatewayRegistrationManager
    ) async {
        for _ in 0..<100 {
            if await gateway.refreshCount > 0 {
                return
            }
            await Task.yield()
        }
        Issue.record("Timed out waiting for gateway token refresh")
    }
}

@MainActor
private final class RegistrationRecorder {
    private(set) var registrationCount = 0

    func record() {
        registrationCount += 1
    }
}

private actor FakeNotificationPermissionClient: NotificationPermissionClient {
    private var status: NotificationAuthorisationStatus
    private let statusAfterRequest: NotificationAuthorisationStatus
    private(set) var requestCount = 0
    private(set) var verificationCount = 0

    init(
        status: NotificationAuthorisationStatus,
        statusAfterRequest: NotificationAuthorisationStatus? = nil
    ) {
        self.status = status
        self.statusAfterRequest = statusAfterRequest ?? status
    }

    func authorisationStatus() async -> NotificationAuthorisationStatus {
        status
    }

    func requestAuthorisation() async throws -> Bool {
        requestCount += 1
        status = statusAfterRequest
        return statusAfterRequest.allowsNotifications
    }

    func scheduleVerificationNotification() async throws {
        verificationCount += 1
    }

    func setStatus(_ status: NotificationAuthorisationStatus) {
        self.status = status
    }
}

private actor FakePushGatewayRegistrationManager: PushGatewayRegistrationManaging {
    private var storedSummary: PushGatewayConfigurationSummary?
    private(set) var configureCount = 0
    private(set) var refreshCount = 0
    private(set) var removedProfileID: UUID?
    private(set) var lastDeviceToken: Data?

    init(summary: PushGatewayConfigurationSummary? = nil) {
        storedSummary = summary
    }

    func summary(for profileID: UUID) -> PushGatewayConfigurationSummary? {
        storedSummary?.profileID == profileID ? storedSummary : nil
    }

    func configure(
        baseURL: String,
        apiToken: String,
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) -> PushGatewayConfigurationSummary {
        configureCount += 1
        lastDeviceToken = deviceToken
        let summary = PushGatewayConfigurationSummary(
            baseURL: URL(string: baseURL)!,
            deviceID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            environment: environment,
            updatedAt: Date(timeIntervalSince1970: 1_788_115_200)
        )
        storedSummary = summary
        return summary
    }

    func refreshRegistration(
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) -> PushGatewayConfigurationSummary? {
        guard let storedSummary else { return nil }
        refreshCount += 1
        lastDeviceToken = deviceToken
        return PushGatewayConfigurationSummary(
            baseURL: storedSummary.baseURL,
            deviceID: storedSummary.deviceID,
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            environment: environment,
            updatedAt: storedSummary.updatedAt
        )
    }

    func removeRegistration(for profileID: UUID) {
        removedProfileID = profileID
        storedSummary = nil
    }
}
