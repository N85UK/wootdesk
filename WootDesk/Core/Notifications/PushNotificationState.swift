import Foundation
import Observation

public enum RemoteNotificationRegistrationStatus: Equatable, Sendable {
    case idle
    case registering
    case registeredWithApple
    case failed
}

public enum PushGatewayDeliveryStatus: Equatable, Sendable {
    case notConfigured
    case awaitingAppleRegistration
    case enrolling
    case enrolled(host: String)
    case failed
}

/// Owns notification permission and APNs registration state for the current app process.
///
/// Apple device tokens are deliberately retained only in memory. They are not logged or
/// persisted. The authenticated push gateway receives the token only after deliberate
/// user configuration and never receives a Chatwoot access token.
@Observable
@MainActor
public final class PushNotificationState {
    public private(set) var authorisationStatus: NotificationAuthorisationStatus = .unknown
    public private(set) var registrationStatus: RemoteNotificationRegistrationStatus = .idle
    public private(set) var isWorking = false
    public private(set) var errorMessage: String?
    public private(set) var gatewayStatus: PushGatewayDeliveryStatus = .notConfigured
    public private(set) var gatewaySummary: PushGatewayConfigurationSummary?
    public private(set) var isGatewayWorking = false
    public private(set) var gatewayErrorMessage: String?
    public private(set) var pendingRoute: PushNotificationRoute?

    @ObservationIgnored private let permissionClient: NotificationPermissionClient
    @ObservationIgnored private let gatewayManager: PushGatewayRegistrationManaging
    @ObservationIgnored private let gatewayEnvironment: PushGatewayEnvironment
    @ObservationIgnored private var registrationAction: (@MainActor @Sendable () -> Void)?
    @ObservationIgnored private var currentDeviceToken: Data?
    /// True when this device is enrolled but the profile has no Chatwoot agent
    /// identity, which means the gateway cannot route an assigned conversation
    /// to it and will silently exclude it.
    public private(set) var isEnrolledWithoutAgentIdentity = false

    @ObservationIgnored private var savedProfiles: [ServerProfile] = []
    @ObservationIgnored private var activeProfile: ServerProfile?
    @ObservationIgnored private var isConfigured = false

    public init(
        permissionClient: NotificationPermissionClient = SystemNotificationPermissionClient(),
        gatewayManager: PushGatewayRegistrationManaging = DisabledPushGatewayRegistrationManager(),
        gatewayEnvironment: PushGatewayEnvironment = .current
    ) {
        self.permissionClient = permissionClient
        self.gatewayManager = gatewayManager
        self.gatewayEnvironment = gatewayEnvironment
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
    }

    public func refreshAuthorisationStatus() async {
        authorisationStatus = await permissionClient.authorisationStatus()
        if isConfigured,
           authorisationStatus.allowsNotifications,
           registrationStatus != .registering,
           registrationStatus != .registeredWithApple {
            beginRemoteRegistration()
        }
    }

    public func updateProfileContext(
        profiles: [ServerProfile],
        activeProfile: ServerProfile?
    ) async {
        savedProfiles = profiles
        self.activeProfile = activeProfile
        gatewayErrorMessage = nil

        guard let activeProfile else {
            gatewaySummary = nil
            gatewayStatus = .notConfigured
            return
        }

        do {
            gatewaySummary = try await gatewayManager.summary(for: activeProfile.id)
            updateGatewayStatusFromCurrentState()
            if currentDeviceToken != nil {
                await refreshActiveRegistration()
            }
        } catch {
            AppLogger.app.error("Saved push gateway settings could not be restored.")
            gatewaySummary = nil
            gatewayStatus = .failed
            gatewayErrorMessage = Self.userMessage(for: error)
        }
    }

    public func requestAuthorisation() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            _ = try await permissionClient.requestAuthorisation()
            await refreshAuthorisationStatus()
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

        Task {
            await refreshAllConfiguredRegistrations()
        }
    }

    public func didFailToRegisterForRemoteNotifications() {
        currentDeviceToken = nil
        registrationStatus = .failed
        errorMessage = "Apple Push Notification registration failed. Check the app signing capability and try again."
        AppLogger.app.error("Apple Push Notification registration failed.")
    }

    public func configureGateway(baseURL: String, apiToken: String) async {
        guard !isGatewayWorking else { return }
        guard let activeProfile else {
            gatewayErrorMessage = PushGatewayRegistrationError.noActiveProfile.errorDescription
            return
        }
        guard let currentDeviceToken else {
            gatewayStatus = .awaitingAppleRegistration
            gatewayErrorMessage = PushGatewayRegistrationError.missingDeviceToken.errorDescription
            return
        }

        isGatewayWorking = true
        gatewayStatus = .enrolling
        gatewayErrorMessage = nil
        defer { isGatewayWorking = false }

        do {
            let summary = try await gatewayManager.configure(
                baseURL: baseURL,
                apiToken: apiToken,
                profile: activeProfile,
                deviceToken: currentDeviceToken,
                environment: gatewayEnvironment
            )
            gatewaySummary = summary
            gatewayStatus = .enrolled(host: summary.displayHost)
        } catch {
            AppLogger.app.error("Push gateway device enrolment failed.")
            gatewayStatus = .failed
            gatewayErrorMessage = Self.userMessage(for: error)
        }
    }

    public func removeGatewayRegistration() async {
        guard !isGatewayWorking else { return }
        guard let activeProfile else {
            gatewayErrorMessage = PushGatewayRegistrationError.noActiveProfile.errorDescription
            return
        }

        isGatewayWorking = true
        gatewayErrorMessage = nil
        defer { isGatewayWorking = false }

        do {
            try await gatewayManager.removeRegistration(for: activeProfile.id)
            gatewaySummary = nil
            gatewayStatus = .notConfigured
        } catch {
            AppLogger.app.error("Push gateway device removal failed.")
            gatewayStatus = .failed
            gatewayErrorMessage = Self.userMessage(for: error)
        }
    }

    public func receiveRemoteNotification(route: PushNotificationRoute) {
        pendingRoute = route
    }

    public func clearPendingRoute() {
        pendingRoute = nil
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

    private func refreshActiveRegistration() async {
        guard let activeProfile, let currentDeviceToken, !isGatewayWorking else { return }

        isGatewayWorking = true
        if gatewaySummary != nil {
            gatewayStatus = .enrolling
        }
        defer { isGatewayWorking = false }

        do {
            gatewaySummary = try await gatewayManager.refreshRegistration(
                profile: activeProfile,
                deviceToken: currentDeviceToken,
                environment: gatewayEnvironment
            )
            updateGatewayStatusFromCurrentState()
        } catch {
            AppLogger.app.error("The active push gateway registration could not be refreshed.")
            gatewayStatus = .failed
            gatewayErrorMessage = Self.userMessage(for: error)
        }
    }

    private func refreshAllConfiguredRegistrations() async {
        guard let currentDeviceToken, !savedProfiles.isEmpty, !isGatewayWorking else { return }

        isGatewayWorking = true
        if gatewaySummary != nil {
            gatewayStatus = .enrolling
        }
        defer { isGatewayWorking = false }

        var activeSummary = gatewaySummary
        var activeFailure: Error?
        for profile in savedProfiles {
            do {
                let summary = try await gatewayManager.refreshRegistration(
                    profile: profile,
                    deviceToken: currentDeviceToken,
                    environment: gatewayEnvironment
                )
                if profile.id == activeProfile?.id {
                    activeSummary = summary
                }
            } catch {
                AppLogger.app.error("A push gateway registration could not be refreshed after Apple issued a device token.")
                if profile.id == activeProfile?.id {
                    activeFailure = error
                }
            }
        }

        gatewaySummary = activeSummary
        if let activeFailure {
            gatewayStatus = .failed
            gatewayErrorMessage = Self.userMessage(for: activeFailure)
        } else {
            gatewayErrorMessage = nil
            updateGatewayStatusFromCurrentState()
        }
    }

    private func updateGatewayStatusFromCurrentState() {
        // An enrolment carrying no agent identity is accepted by the gateway
        // but excluded from every assigned conversation, so the agent receives
        // nothing and nothing on screen says why. Surface it.
        isEnrolledWithoutAgentIdentity =
            gatewaySummary != nil && activeProfile?.agentID == nil

        guard let gatewaySummary else {
            gatewayStatus = .notConfigured
            return
        }
        if currentDeviceToken == nil {
            gatewayStatus = .awaitingAppleRegistration
        } else {
            gatewayStatus = .enrolled(host: gatewaySummary.displayHost)
        }
    }

    private static func userMessage(for error: Error) -> String {
        if let localisedError = error as? LocalizedError,
           let description = localisedError.errorDescription {
            return description
        }
        return "WootDesk could not complete the push gateway operation. Please try again."
    }
}
