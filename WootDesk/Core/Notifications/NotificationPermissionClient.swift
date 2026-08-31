import Foundation
import UserNotifications

/// App-facing notification permission states, kept independent from UserNotifications types.
public enum NotificationAuthorisationStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorised
    case provisional
    case ephemeral

    public var allowsNotifications: Bool {
        switch self {
        case .authorised, .provisional, .ephemeral:
            true
        case .unknown, .notDetermined, .denied:
            false
        }
    }
}

/// Test seam for notification permission and local verification delivery.
public protocol NotificationPermissionClient: Sendable {
    func authorisationStatus() async -> NotificationAuthorisationStatus
    func requestAuthorisation() async throws -> Bool
    func scheduleVerificationNotification() async throws
}

/// Native UserNotifications implementation used by the live app.
public actor SystemNotificationPermissionClient: NotificationPermissionClient {
    public init() {}

    public func authorisationStatus() async -> NotificationAuthorisationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: Self.map(settings.authorizationStatus))
            }
        }
    }

    public func requestAuthorisation() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    public func scheduleVerificationNotification() async throws {
        let content = UNMutableNotificationContent()
        content.title = "WootDesk notifications are enabled"
        content.body = "This test contains no Chatwoot conversation data."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dev.n85.wootdesk.notification-verification",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorisationStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized:
            .authorised
        case .provisional:
            .provisional
        case .ephemeral:
            .ephemeral
        @unknown default:
            .unknown
        }
    }
}
