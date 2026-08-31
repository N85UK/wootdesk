import Foundation
import SwiftUI

/// Main-actor state for the active profile's account-specific agent presence.
@Observable
@MainActor
public final class AgentAvailabilityState {
    public private(set) var availability: AgentAvailability?
    public private(set) var isLoading = false
    public private(set) var isUpdating = false
    public private(set) var errorMessage: String?

    private let apiClient: ChatwootAPIProtocol
    private var loadedContext: Context?
    private var contentRevision = UUID()

    public init(apiClient: ChatwootAPIProtocol) {
        self.apiClient = apiClient
    }

    /// Loads the status reported for the selected account in the current profile.
    public func load(
        profile: ServerProfile?,
        token: String?,
        force: Bool = false
    ) async {
        guard let profile, let token, !token.isEmpty else {
            clear()
            return
        }

        let requestedContext = Context(
            profileID: profile.id,
            accountID: profile.selectedAccountID
        )
        if loadedContext != requestedContext {
            reset(for: requestedContext)
        } else if isLoading || isUpdating || (!force && availability != nil) {
            return
        }

        contentRevision = UUID()
        let requestRevision = contentRevision
        isLoading = true
        errorMessage = nil
        defer {
            if contentRevision == requestRevision {
                isLoading = false
            }
        }

        do {
            let profileResult = try await apiClient.fetchProfile(
                baseURL: profile.baseURL,
                token: token
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }
            guard let account = profileResult.accounts.first(where: { $0.id == profile.selectedAccountID }) else {
                throw AgentAvailabilityStateError.accountUnavailable
            }

            availability = account.effectiveAvailability
            if availability == nil {
                errorMessage = AgentAvailabilityStateError.statusUnavailable.errorDescription
            } else {
                errorMessage = nil
            }
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            errorMessage = Self.message(for: error)
        }
    }

    /// Changes availability only after Chatwoot confirms the account mutation.
    public func update(
        _ requestedAvailability: AgentAvailability,
        profile: ServerProfile?,
        token: String?
    ) async {
        guard let profile, let token, !token.isEmpty, !isLoading, !isUpdating else { return }

        let requestedContext = Context(
            profileID: profile.id,
            accountID: profile.selectedAccountID
        )
        if loadedContext != requestedContext {
            reset(for: requestedContext)
        }

        let requestRevision = contentRevision
        isUpdating = true
        errorMessage = nil
        defer {
            if contentRevision == requestRevision {
                isUpdating = false
            }
        }

        do {
            try await apiClient.updateAvailability(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                availability: requestedAvailability
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }
            availability = requestedAvailability
            errorMessage = nil
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            errorMessage = Self.message(for: error)
        }
    }

    /// Clears server-specific state immediately during profile switches.
    public func clear() {
        contentRevision = UUID()
        loadedContext = nil
        availability = nil
        isLoading = false
        isUpdating = false
        errorMessage = nil
    }

    private func reset(for context: Context) {
        clear()
        loadedContext = context
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? apiError.localizedDescription
        }
        if let localised = error as? LocalizedError, let description = localised.errorDescription {
            return description
        }
        return "WootDesk could not update your Chatwoot availability. Please try again."
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let apiError = error as? APIError, apiError == .cancelled { return true }
        return false
    }

    private struct Context: Equatable {
        let profileID: UUID
        let accountID: Int
    }
}

private enum AgentAvailabilityStateError: LocalizedError {
    case accountUnavailable
    case statusUnavailable

    var errorDescription: String? {
        switch self {
        case .accountUnavailable:
            return "The selected Chatwoot account was not returned by the current profile. Revalidate this server connection and try again."
        case .statusUnavailable:
            return "This Chatwoot server did not report your current availability. You can still choose a status below."
        }
    }
}
