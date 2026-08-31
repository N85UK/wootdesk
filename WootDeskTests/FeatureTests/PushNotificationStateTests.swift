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
}
