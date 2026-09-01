import Foundation
import os

/// Conversation triage operations: status, snooze, priority, assignment and labels.
///
/// Every mutation is followed by a read of the conversation so that WootDesk
/// displays the state the Chatwoot server confirms, not the state that was
/// requested. Chatwoot's triage endpoints differ in what they return between
/// supported versions, and several return an empty body on success.
extension ChatwootAPIClient {

    public func fetchConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> Conversation {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)"
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching a single Chatwoot conversation.")
        let data = try await perform(request: request)

        do {
            let envelope = try JSONDecoder().decode(ChatwootConversationResponseDTO.self, from: data)
            return envelope.conversation.toDomain(defaultAccountID: accountID)
        } catch {
            AppLogger.network.error("The Chatwoot conversation response could not be decoded.")
            throw APIError.decodingError("The server returned conversation data in an unsupported format.")
        }
    }

    public func updateConversationStatus(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        status: ConversationStatus,
        snoozedUntil: Date?
    ) async throws -> Conversation {
        let snoozeSeconds: Int?
        if status == .snoozed {
            guard let snoozedUntil, snoozedUntil.timeIntervalSinceNow > 0 else {
                throw APIError.invalidSnoozeTime
            }
            snoozeSeconds = Int(snoozedUntil.timeIntervalSince1970.rounded())
        } else {
            snoozeSeconds = nil
        }

        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)/toggle_status"
        )
        let body = try JSONEncoder().encode(
            ToggleConversationStatusRequestDTO(
                status: status.rawValue,
                snoozedUntil: snoozeSeconds
            )
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "POST", token: token, body: body)

        AppLogger.network.debug("Applying a Chatwoot conversation status change.")
        _ = try await perform(request: request)

        return try await fetchConversation(
            baseURL: baseURL,
            token: token,
            accountID: accountID,
            conversationID: conversationID
        )
    }

    public func updateConversationPriority(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        priority: ConversationPriority?
    ) async throws -> Conversation {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)/toggle_priority"
        )
        // Chatwoot clears a priority when the parameter is sent as an empty value.
        let body = try JSONEncoder().encode(
            ToggleConversationPriorityRequestDTO(priority: priority?.rawValue ?? "")
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "POST", token: token, body: body)

        AppLogger.network.debug("Applying a Chatwoot conversation priority change.")
        _ = try await perform(request: request)

        return try await fetchConversation(
            baseURL: baseURL,
            token: token,
            accountID: accountID,
            conversationID: conversationID
        )
    }

    public func assignConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        target: ConversationAssignmentTarget
    ) async throws -> Conversation {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)/assignments"
        )
        let parameter = target.requestParameter
        let body = try JSONSerialization.data(withJSONObject: [parameter.name: parameter.value])
        let request = APIRequest.makeRequest(url: endpoint, method: "POST", token: token, body: body)

        AppLogger.network.debug("Applying a Chatwoot conversation assignment.")
        _ = try await perform(request: request)

        return try await fetchConversation(
            baseURL: baseURL,
            token: token,
            accountID: accountID,
            conversationID: conversationID
        )
    }

    public func fetchConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> [String] {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)/labels"
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching the labels held for a Chatwoot conversation.")
        let data = try await perform(request: request)
        return try Self.decodeLabels(from: data)
    }

    public func updateConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        labels: [String]
    ) async throws -> [String] {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)/labels"
        )
        let body = try JSONEncoder().encode(UpdateConversationLabelsRequestDTO(labels: labels))
        let request = APIRequest.makeRequest(url: endpoint, method: "POST", token: token, body: body)

        AppLogger.network.debug("Replacing the label set held for a Chatwoot conversation.")
        let data = try await perform(request: request)

        if let confirmed = try? Self.decodeLabels(from: data) {
            return confirmed
        }

        // Some supported versions confirm the change with an empty body. Read the
        // set back rather than reporting the requested labels as confirmed.
        AppLogger.network.debug("The label update returned no payload, so the label set is being read back.")
        return try await fetchConversationLabels(
            baseURL: baseURL,
            token: token,
            accountID: accountID,
            conversationID: conversationID
        )
    }

    public func fetchAssignmentOptions(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> ConversationAssignmentOptions {
        let agents = try await fetchAssignableAgents(
            baseURL: baseURL,
            token: token,
            accountID: accountID
        )
        let teams = try await fetchAssignableTeams(
            baseURL: baseURL,
            token: token,
            accountID: accountID
        )
        return ConversationAssignmentOptions(agents: agents, teams: teams)
    }

    public func fetchAccountLabels(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> [AccountLabel] {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/labels"
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching the Chatwoot account label set.")
        let data = try await perform(request: request)

        do {
            let envelope = try JSONDecoder().decode(
                ChatwootPayloadListDTO<ChatwootLabelDTO>.self,
                from: data
            )
            return envelope.items.map { $0.toDomain() }
        } catch {
            AppLogger.network.error("The Chatwoot account label response could not be decoded.")
            throw APIError.decodingError("The server returned label data in an unsupported format.")
        }
    }

    // MARK: - Assignment Targets

    private func fetchAssignableAgents(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> [AssignableAgent] {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/agents"
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching the Chatwoot account agent list.")
        let data = try await perform(request: request)

        do {
            let envelope = try JSONDecoder().decode(
                ChatwootPayloadListDTO<ChatwootAssignedUserDTO>.self,
                from: data
            )
            return envelope.items.map { $0.toAssignableAgent() }
        } catch {
            AppLogger.network.error("The Chatwoot agent list response could not be decoded.")
            throw APIError.decodingError("The server returned agent data in an unsupported format.")
        }
    }

    /// Reads the account teams.
    ///
    /// An agent-role token is refused access to the team list on supported
    /// Chatwoot versions. That is a genuine "no teams available to you" answer
    /// rather than a failure, so it yields an empty list. Every other failure
    /// propagates.
    private func fetchAssignableTeams(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> [AssignableTeam] {
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/teams"
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching the Chatwoot account team list.")

        let data: Data
        do {
            data = try await perform(request: request)
        } catch APIError.forbidden, APIError.notFound {
            AppLogger.network.debug("The Chatwoot account does not expose teams to this agent.")
            return []
        }

        do {
            let envelope = try JSONDecoder().decode(
                ChatwootPayloadListDTO<ChatwootTeamDTO>.self,
                from: data
            )
            return envelope.items.map { $0.toDomain() }
        } catch {
            AppLogger.network.error("The Chatwoot team list response could not be decoded.")
            throw APIError.decodingError("The server returned team data in an unsupported format.")
        }
    }

    private static func decodeLabels(from data: Data) throws -> [String] {
        do {
            let envelope = try JSONDecoder().decode(
                ChatwootConversationLabelsResponseDTO.self,
                from: data
            )
            return envelope.labels
        } catch {
            AppLogger.network.error("The Chatwoot conversation label response could not be decoded.")
            throw APIError.decodingError("The server returned label data in an unsupported format.")
        }
    }
}
