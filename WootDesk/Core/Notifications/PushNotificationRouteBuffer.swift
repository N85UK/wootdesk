import Foundation

/// Retains a notification route until the root app state is ready during a cold launch.
@MainActor
final class PushNotificationRouteBuffer {
    private weak var notificationState: PushNotificationState?
    private var pendingRoute: PushNotificationRoute?

    func attach(to state: PushNotificationState) {
        notificationState = state
        guard let pendingRoute else { return }
        self.pendingRoute = nil
        state.receiveRemoteNotification(route: pendingRoute)
    }

    func receive(_ route: PushNotificationRoute) {
        guard let notificationState else {
            pendingRoute = route
            return
        }
        notificationState.receiveRemoteNotification(route: route)
    }
}
