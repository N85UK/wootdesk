/// An inert notification client for previews and UI tests.
///
/// It never reaches UserNotifications or APNs.
public actor InMemoryNotificationPermissionClient: NotificationPermissionClient {
    private var status: NotificationAuthorisationStatus

    public init(status: NotificationAuthorisationStatus) {
        self.status = status
    }

    public func authorisationStatus() async -> NotificationAuthorisationStatus {
        status
    }

    public func requestAuthorisation() async throws -> Bool {
        status.allowsNotifications
    }

    public func scheduleVerificationNotification() async throws {}
}
