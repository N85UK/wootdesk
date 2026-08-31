import Foundation
import Observation

public enum RemoteNotificationRegistrationStatus: Equatable, Sendable {
    case idle
    case registering
    case registeredWithApple
    case failed
}

/// Owns notification permission and APNs registration state for the current app process.
///
/// Apple device tokens are deliberately retained only in memory. They are not logged or
/// persisted. A future authenticated push provider must consume the current token and
/// forward Chatwoot events to APNs without receiving a Chatwoot access token.
@Observable
@MainActor
public final class PushNotificationState {
    public private(set) var authorisationStatus: NotificationAuthorisationStatus = .unknown
    public private(set) var registrationStatus: RemoteNotificationRegistrationStatus = .idle
    public private(set) var isWorking = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let permissionClient: NotificationPermissionClient
    @ObservationIgnored private var registrationAction: (@MainActor @Sendable () -> Void)?
    @ObservationIgnored private var currentDeviceToken: Data?
    @ObservationIgnored private var isConfigured = false

    public init(permissionClient: NotificationPermissionClient = SystemNotificationPermissionClient()) {
        self.permissionClient = permissionClient
    }

    public var hasCurrentDeviceToken: Bool {
        currentDeviceToken != nil
    }

    public func configure(
        registrationAction: @escaping @MainActor @Sendable () -> Void
    ) async {
        self.registrationAction = registrationAction
        guard !isConfigured else { return }
        isConfigured = true

        await refreshAuthorisationStatus()
        if authorisationStatus.allowsNotifications {
            beginRemoteRegistration()
        }
    }

    public func refreshAuthorisationStatus() async {
        authorisationStatus = await permissionClient.authorisationStatus()
    }

    public func requestAuthorisation() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            _ = try await permissionClient.requestAuthorisation()
            await refreshAuthorisationStatus()
            if authorisationStatus.allowsNotifications {
                beginRemoteRegistration()
            }
        } catch {
            AppLogger.app.error("Notification authorisation could not be completed.")
            errorMessage = "WootDesk could not request notification permission. Please try again."
        }
    }

    public func sendVerificationNotification() async {
        guard authorisationStatus.allowsNotifications else {
            errorMessage = "Enable notifications before sending a test notification."
            return
        }
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await permissionClient.scheduleVerificationNotification()
        } catch {
            AppLogger.app.error("The notification verification request failed.")
            errorMessage = "WootDesk could not schedule the test notification. Please try again."
        }
    }

    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        currentDeviceToken = deviceToken
        registrationStatus = .registeredWithApple
        errorMessage = nil
        AppLogger.app.info("WootDesk registered with Apple Push Notification service.")
    }

    public func didFailToRegisterForRemoteNotifications() {
        currentDeviceToken = nil
        registrationStatus = .failed
        errorMessage = "Apple Push Notification registration failed. Check the app signing capability and try again."
        AppLogger.app.error("Apple Push Notification registration failed.")
    }

    private func beginRemoteRegistration() {
        guard let registrationAction else {
            registrationStatus = .failed
            errorMessage = "Remote notification registration is not available in this app session."
            return
        }
        registrationStatus = .registering
        registrationAction()
    }
}
