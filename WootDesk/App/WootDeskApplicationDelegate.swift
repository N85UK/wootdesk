import UserNotifications

#if os(iOS)
import UIKit

@MainActor
final class WootDeskApplicationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private weak var notificationState: PushNotificationState?
    private let routeBuffer = PushNotificationRouteBuffer()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func configureNotifications(using state: PushNotificationState) async {
        notificationState = state
        routeBuffer.attach(to: state)
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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let route = PushNotificationRoute(userInfo: userInfo) else {
            AppLogger.app.error("A remote notification with invalid routing metadata was ignored.")
            return
        }
        await MainActor.run { [weak self] in
            self?.routeBuffer.receive(route)
        }
    }
}
#elseif os(macOS)
import AppKit

@MainActor
final class WootDeskApplicationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private weak var notificationState: PushNotificationState?
    private let routeBuffer = PushNotificationRouteBuffer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func configureNotifications(using state: PushNotificationState) async {
        notificationState = state
        routeBuffer.attach(to: state)
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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let route = PushNotificationRoute(userInfo: userInfo) else {
            AppLogger.app.error("A remote notification with invalid routing metadata was ignored.")
            return
        }
        await MainActor.run { [weak self] in
            self?.routeBuffer.receive(route)
        }
    }
}
#endif
