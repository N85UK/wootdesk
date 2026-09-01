import Foundation
import SwiftUI

/// Opens the conversation a notification identifies.
///
/// The coordinator owns the whole sequence: clearing the previous profile's
/// screen data, activating the notified profile, removing filters that would
/// hide the conversation, and then displaying either the identified
/// conversation or an explanation of why it cannot be opened. It never
/// substitutes a different conversation.
@Observable
@MainActor
public final class ConversationRouteCoordinator {
    /// Whether a notification is currently being opened.
    ///
    /// A second activation of the same notification while one is in progress is
    /// ignored, so one notification produces one navigation result.
    public private(set) var isOpening = false
    /// The reason the identified conversation could not be opened.
    public private(set) var errorMessage: String?

    public init() {}

    public func dismissError() {
        errorMessage = nil
    }

    /// Opens the conversation identified by a notification route.
    ///
    /// - Returns: `true` when the identified conversation is displayed.
    @discardableResult
    public func open(
        route: PushNotificationRoute,
        appModel: AppModel,
        listState: ConversationListState,
        detailState: ConversationDetailState,
        triageState: ConversationTriageState,
        using client: ChatwootAPIProtocol
    ) async -> Bool {
        guard !isOpening else { return false }
        isOpening = true
        errorMessage = nil
        defer { isOpening = false }

        // Screen data from the previous profile is removed before any data from
        // the notified profile is requested.
        ConversationWorkspaceReset.clearProfileData(
            list: listState,
            detail: detailState,
            triage: triageState
        )

        guard await appModel.activateNotificationRoute(route),
              let profile = appModel.activeProfile,
              let token = appModel.activeToken else {
            errorMessage = appModel.lastError
                ?? "The notification belongs to a server profile that is no longer available."
            return false
        }

        // A search term or status filter must not hide the conversation the
        // agent has been sent to.
        listState.clearFiltersForRouting()
        await listState.loadConversations(profile: profile, token: token, using: client)

        if let listed = listState.conversations.first(where: { $0.id == route.conversationID }) {
            listState.adoptRoutedConversation(listed)
            return true
        }

        // The conversation is outside the loaded page, so it is requested
        // directly rather than reported as missing.
        do {
            let conversation = try await client.fetchConversation(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: route.conversationID
            )
            guard conversation.id == route.conversationID else {
                errorMessage = Self.unavailableMessage(
                    conversationID: route.conversationID,
                    reason: "The server returned a different conversation."
                )
                return false
            }
            listState.adoptRoutedConversation(conversation)
            // The list load may have failed while the direct read succeeded. The
            // conversation is shown, so the page error is no longer relevant.
            listState.errorMessage = nil
            return true
        } catch {
            listState.selectedConversationID = nil
            errorMessage = Self.unavailableMessage(
                conversationID: route.conversationID,
                reason: Self.message(for: error)
            )
            return false
        }
    }

    private static func unavailableMessage(conversationID: Int, reason: String) -> String {
        "WootDesk could not open conversation #\(conversationID) from that notification. \(reason)"
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .notFound:
                return "It may have been deleted, or your access to it may have been removed."
            default:
                return apiError.errorDescription ?? apiError.localizedDescription
            }
        }
        if let localised = error as? LocalizedError, let description = localised.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
