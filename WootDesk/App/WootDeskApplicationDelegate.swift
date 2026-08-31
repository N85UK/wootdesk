import UserNotifications

#if os(iOS)
import UIKit

@MainActor
final class WootDeskApplicationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private weak var notificationState: PushNotificationState?

    func configureNotifications(using state: PushNotificationState) async {
        notificationState = state
        UNUserNotificationCenter.current().delegate = self
        await state.configure {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        notificationState?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        notificationState?.didFailToRegisterForRemoteNotifications()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}
#elseif os(macOS)
import AppKit

@MainActor
final class WootDeskApplicationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private weak var notificationState: PushNotificationState?

    func configureNotifications(using state: PushNotificationState) async {
        notificationState = state
        UNUserNotificationCenter.current().delegate = self
        await state.configure {
            NSApplication.shared.registerForRemoteNotifications()
        }
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        notificationState?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        notificationState?.didFailToRegisterForRemoteNotifications()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}
#endif
