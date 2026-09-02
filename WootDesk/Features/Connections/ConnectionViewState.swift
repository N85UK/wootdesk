import Foundation
import SwiftUI
import os

/// State manager for adding and validating new Chatwoot connections.
@Observable
@MainActor
public final class ConnectionViewState {
    public var displayName: String = ""
    public var serverURLString: String = ""
    public var token: String = ""

    public var isValidating: Bool = false
    public var isSaving: Bool = false
    public var errorMessage: String?
    public var discoveredAccounts: [ChatwootAccount] = []
    public var validatedProfileName: String = ""
    public var validatedAgentID: Int?
    public var validatedURL: URL?
    public var validatedToken: String = ""
    public var isSelectingAccount: Bool = false

    public init(
        initialURL: String = "",
        initialToken: String = "",
        initialDisplayName: String = ""
    ) {
        self.serverURLString = initialURL
        self.token = initialToken
        self.displayName = initialDisplayName
    }

    /// Validates the server connection and token against `GET /api/v1/profile`.
    public func validate(
        using apiClient: ChatwootAPIProtocol,
        isDebug: Bool
    ) async -> ValidationOutcome {
        errorMessage = nil
        discoveredAccounts = []
        validatedProfileName = ""
        validatedAgentID = nil
        validatedURL = nil
        validatedToken = ""
        isSelectingAccount = false
        isValidating = true
        defer { isValidating = false }

        do {
            let normalisedURL = try APIRequest.normaliseBaseURL(serverURLString, isDebug: isDebug)
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedToken.isEmpty else {
                errorMessage = "Please enter your Chatwoot personal access token."
                return .failure("Please enter your Chatwoot personal access token.")
            }

            let (profileName, agentID, accounts) = try await apiClient.fetchProfile(
                baseURL: normalisedURL,
                token: trimmedToken
            )

            guard !accounts.isEmpty else {
                let err = "No active Chatwoot accounts found for this user."
                self.errorMessage = err
                return .failure(err)
            }

            self.validatedProfileName = profileName
            self.validatedAgentID = agentID
            self.validatedURL = normalisedURL
            self.validatedToken = trimmedToken
            self.discoveredAccounts = accounts
            self.serverURLString = normalisedURL.absoluteString

            if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                displayName = normalisedURL.host ?? profileName
            }

            if accounts.count == 1, let singleAccount = accounts.first {
                return .singleAccount(singleAccount, profileName: profileName, agentID: agentID, url: normalisedURL, token: trimmedToken)
            } else {
                self.isSelectingAccount = true
                return .multipleAccounts(accounts, profileName: profileName, agentID: agentID, url: normalisedURL, token: trimmedToken)
            }
        } catch let apiError as APIError {
            let message = apiError.errorDescription ?? "An error occurred while connecting to Chatwoot."
            self.errorMessage = message
            return .failure(message)
        } catch {
            let message = error.localizedDescription
            self.errorMessage = message
            return .failure(message)
        }
    }

    public func reset() {
        displayName = ""
        serverURLString = ""
        token = ""
        errorMessage = nil
        discoveredAccounts = []
        validatedProfileName = ""
        validatedAgentID = nil
        validatedURL = nil
        validatedToken = ""
        isSelectingAccount = false
        isValidating = false
        isSaving = false
    }

    public enum ValidationOutcome: Equatable {
        case singleAccount(ChatwootAccount, profileName: String, agentID: Int?, url: URL, token: String)
        case multipleAccounts([ChatwootAccount], profileName: String, agentID: Int?, url: URL, token: String)
        case failure(String)
    }
}
