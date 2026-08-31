import Foundation
import Testing
@testable import WootDesk

@Suite("Push Notification Route Tests")
struct PushNotificationRouteTests {
    @Test("A minimal gateway payload maps to opaque routing identifiers")
    func parsesValidRoute() throws {
        let route = try #require(
            PushNotificationRoute(
                userInfo: [
                    "profile_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                    "account_id": NSNumber(value: 42),
                    "conversation_id": 700,
                ]
            )
        )

        #expect(route.profileID == UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"))
        #expect(route.accountID == 42)
        #expect(route.conversationID == 700)
    }

    @Test("Missing, malformed, and non-positive routing values are rejected")
    func rejectsInvalidRoutes() {
        #expect(PushNotificationRoute(userInfo: [:]) == nil)
        #expect(
            PushNotificationRoute(
                userInfo: [
                    "profile_id": "not-a-uuid",
                    "account_id": 42,
                    "conversation_id": 700,
                ]
            ) == nil
        )
        #expect(
            PushNotificationRoute(
                userInfo: [
                    "profile_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                    "account_id": 0,
                    "conversation_id": -1,
                ]
            ) == nil
        )
    }

    @Test("AppModel accepts only a notification matching the saved profile account")
    @MainActor
    func accountBoundaryIsEnforced() async throws {
        let profile = ServerProfile(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            displayName: "Invented Support",
            baseURL: URL(string: "https://chatwoot.example.com")!,
            selectedAccountID: 42,
            selectedAccountName: "Invented Account"
        )
        let environment = AppEnvironment.preview(
            profiles: [profile],
            activeProfileID: profile.id,
            tokens: [profile.id: "invented-token"]
        )
        let appModel = AppModel(environment: environment)
        await appModel.initialize()

        let wrongAccount = try #require(
            PushNotificationRoute(
                userInfo: [
                    "profile_id": profile.id.uuidString,
                    "account_id": 99,
                    "conversation_id": 700,
                ]
            )
        )
        #expect(await appModel.activateNotificationRoute(wrongAccount) == false)
        #expect(appModel.activeProfile?.id == profile.id)

        let matching = try #require(
            PushNotificationRoute(
                userInfo: [
                    "profile_id": profile.id.uuidString,
                    "account_id": 42,
                    "conversation_id": 700,
                ]
            )
        )
        #expect(await appModel.activateNotificationRoute(matching))
        #expect(appModel.selectedNavigationItem == .conversations(status: nil))
    }

    @Test("A notification tap received during cold launch is delivered after state attachment")
    @MainActor
    func coldLaunchRouteIsBuffered() throws {
        let route = try #require(
            PushNotificationRoute(
                userInfo: [
                    "profile_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                    "account_id": 42,
                    "conversation_id": 700,
                ]
            )
        )
        let state = PushNotificationState(
            permissionClient: InMemoryNotificationPermissionClient(status: .notDetermined)
        )
        let buffer = PushNotificationRouteBuffer()

        buffer.receive(route)
        #expect(state.pendingRoute == nil)

        buffer.attach(to: state)
        #expect(state.pendingRoute == route)
    }
}
