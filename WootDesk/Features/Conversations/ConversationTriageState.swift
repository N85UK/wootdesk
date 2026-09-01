import Foundation
import SwiftUI

/// The triage change an agent has asked WootDesk to submit.
///
/// The value identifies which control is awaiting confirmation so that the
/// interface can show a pending state on that control alone.
public enum ConversationTriageAction: Hashable, Sendable {
    case status(ConversationStatus)
    case priority(ConversationPriority?)
    case assignment(ConversationAssignmentTarget)
    case label(title: String, isAdding: Bool)

    /// A short description used in accessibility announcements and errors.
    public var actionDescription: String {
        switch self {
        case .status(let status):
            return String(
                localized: "set the status to \(status.displayName)",
                comment: "Names a triage action inside a failure message"
            )
        case .priority(let priority):
            guard let priority else {
                return String(
                    localized: "clear the priority",
                    comment: "Names a triage action inside a failure message"
                )
            }
            return String(
                localized: "set the priority to \(priority.displayName)",
                comment: "Names a triage action inside a failure message"
            )
        case .assignment(let target):
            switch target {
            case .agent:
                return String(
                    localized: "change the assigned agent",
                    comment: "Names a triage action inside a failure message"
                )
            case .team:
                return String(
                    localized: "change the assigned team",
                    comment: "Names a triage action inside a failure message"
                )
            case .unassignAgent:
                return String(
                    localized: "remove the assigned agent",
                    comment: "Names a triage action inside a failure message"
                )
            case .unassignTeam:
                return String(
                    localized: "remove the assigned team",
                    comment: "Names a triage action inside a failure message"
                )
            }
        case .label(let title, let isAdding):
            if isAdding {
                return String(
                    localized: "add the label \(title)",
                    comment: "Names a triage action inside a failure message"
                )
            }
            return String(
                localized: "remove the label \(title)",
                comment: "Names a triage action inside a failure message"
            )
        }
    }
}

/// Main-actor state for the triage of one selected conversation.
///
/// Every change is confirmed by reading the resulting conversation back from
/// the Chatwoot server. WootDesk never displays a triage value it has only
/// requested, and a rejected change leaves the last confirmed state on screen.
@Observable
@MainActor
public final class ConversationTriageState {
    /// The last conversation state confirmed by the server.
    public private(set) var conversation: Conversation?
    /// The change currently awaiting confirmation, if any.
    public private(set) var pendingAction: ConversationTriageAction?
    /// The reason the most recent change was not applied.
    public private(set) var errorMessage: String?
    /// The agents and teams the account offers for assignment.
    public private(set) var assignmentOptions = ConversationAssignmentOptions()
    /// The label set defined for the account.
    public private(set) var accountLabels: [AccountLabel] = []
    public private(set) var isLoadingOptions = false
    /// The reason the assignment targets or account labels could not be read.
    public private(set) var optionsErrorMessage: String?

    private var loadedContext: TriageContext?
    private var loadedOptionsContext: OptionsContext?

    public init() {}

    /// Whether a triage change is currently awaiting server confirmation.
    ///
    /// Triage changes are serialised. Each one re-reads the whole conversation
    /// to confirm the result, so two overlapping changes could otherwise report
    /// interleaved confirmed states.
    public var isSubmitting: Bool { pendingAction != nil }

    /// The label titles the account defines that are not on this conversation.
    public var availableLabelsToAdd: [String] {
        let applied = Set((conversation?.labels ?? []).map { $0.lowercased() })
        return accountLabels
            .map(\.title)
            .filter { !applied.contains($0.lowercased()) }
    }

    /// Adopts the selected conversation, discarding state that belonged to a
    /// different profile, account or conversation.
    ///
    /// Once a conversation is adopted, this state holds the authoritative
    /// server-confirmed value for it. A repeat call for the same conversation
    /// therefore keeps the confirmed state rather than replacing it with a copy
    /// the caller may have read before the most recent change.
    public func adopt(_ conversation: Conversation?, profile: ServerProfile?) {
        guard let conversation, let profile else {
            clear()
            return
        }

        let context = TriageContext(
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            conversationID: conversation.id
        )
        guard loadedContext != context else { return }

        clear()
        loadedContext = context
        self.conversation = conversation
    }

    /// Removes all conversation-specific triage state.
    ///
    /// Account-level assignment targets and labels are cleared as well, because
    /// they belong to one server profile and must never be shown under another.
    public func clear() {
        loadedContext = nil
        loadedOptionsContext = nil
        conversation = nil
        pendingAction = nil
        errorMessage = nil
        assignmentOptions = ConversationAssignmentOptions()
        accountLabels = []
        isLoadingOptions = false
        optionsErrorMessage = nil
    }

    // MARK: - Assignment Targets and Labels

    /// Loads the account's assignment targets and label set once per profile
    /// and account.
    public func loadOptions(
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol,
        forceReload: Bool = false
    ) async {
        let context = OptionsContext(
            profileID: profile.id,
            accountID: profile.selectedAccountID
        )
        if !forceReload, loadedOptionsContext == context, optionsErrorMessage == nil { return }
        guard !isLoadingOptions else { return }

        isLoadingOptions = true
        optionsErrorMessage = nil
        defer { isLoadingOptions = false }

        do {
            let options = try await client.fetchAssignmentOptions(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID
            )
            let labels = try await client.fetchAccountLabels(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID
            )
            guard !Task.isCancelled else { return }
            assignmentOptions = options
            accountLabels = labels
            loadedOptionsContext = context
            optionsErrorMessage = nil
        } catch {
            if Self.isCancellation(error) { return }
            assignmentOptions = ConversationAssignmentOptions()
            accountLabels = []
            loadedOptionsContext = nil
            optionsErrorMessage = Self.message(for: error)
        }
    }

    // MARK: - Triage Changes

    /// Applies a conversation status. Snoozing additionally requires a future
    /// return time.
    public func setStatus(
        _ status: ConversationStatus,
        snoozedUntil: Date? = nil,
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        if status == .snoozed, snoozedUntil.map({ $0.timeIntervalSinceNow <= 0 }) ?? true {
            errorMessage = APIError.invalidSnoozeTime.errorDescription
            return
        }

        await submit(.status(status), profile: profile) { conversation in
            try await client.updateConversationStatus(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: conversation.id,
                status: status,
                snoozedUntil: status == .snoozed ? snoozedUntil : nil
            )
        }
    }

    /// Applies a conversation priority, or clears it when `priority` is `nil`.
    public func setPriority(
        _ priority: ConversationPriority?,
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        await submit(.priority(priority), profile: profile) { conversation in
            try await client.updateConversationPriority(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: conversation.id,
                priority: priority
            )
        }
    }

    /// Assigns the conversation to an agent or team, or clears an assignment.
    public func assign(
        to target: ConversationAssignmentTarget,
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        await submit(.assignment(target), profile: profile) { conversation in
            try await client.assignConversation(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: conversation.id,
                target: target
            )
        }
    }

    /// Adds a label, preserving every label the server holds at the time of the
    /// change.
    public func addLabel(
        _ title: String,
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        await changeLabels(title: title, isAdding: true, profile: profile, token: token, using: client)
    }

    /// Removes a label, preserving every other label the server holds at the
    /// time of the change.
    public func removeLabel(
        _ title: String,
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        await changeLabels(title: title, isAdding: false, profile: profile, token: token, using: client)
    }

    /// Clears the message describing the most recent rejected change.
    public func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    /// Chatwoot replaces the whole label set on write, so the current server set
    /// is read immediately before the change and the agent's intent is applied
    /// on top of it. A label added on the server after the conversation was
    /// displayed therefore survives the change.
    private func changeLabels(
        title: String,
        isAdding: Bool,
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = String(
                localized: "Choose a label before applying it.",
                comment: "Shown when a label change is attempted with no label chosen"
            )
            return
        }

        guard let current = conversation, pendingAction == nil else { return }

        pendingAction = .label(title: trimmedTitle, isAdding: isAdding)
        errorMessage = nil
        let context = loadedContext
        defer {
            if loadedContext == context {
                pendingAction = nil
            }
        }

        do {
            let latest = try await client.fetchConversationLabels(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: current.id
            )
            let intended = Self.merged(latest: latest, title: trimmedTitle, isAdding: isAdding)
            let confirmed = try await client.updateConversationLabels(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: current.id,
                labels: intended
            )
            guard loadedContext == context, !Task.isCancelled else { return }
            conversation = current.applying(labels: confirmed)
            errorMessage = nil
        } catch {
            guard loadedContext == context else { return }
            if Self.isCancellation(error) { return }
            errorMessage = Self.failureMessage(
                for: error,
                action: .label(title: trimmedTitle, isAdding: isAdding)
            )
        }
    }

    /// Runs one triage change, keeping the confirmed conversation on screen if
    /// the server rejects it.
    private func submit(
        _ action: ConversationTriageAction,
        profile: ServerProfile,
        perform: (Conversation) async throws -> Conversation
    ) async {
        guard let current = conversation, pendingAction == nil else { return }

        pendingAction = action
        errorMessage = nil
        let context = loadedContext
        defer {
            if loadedContext == context {
                pendingAction = nil
            }
        }

        do {
            let confirmed = try await perform(current)
            guard loadedContext == context, !Task.isCancelled else { return }
            guard confirmed.id == current.id else {
                errorMessage = String(
                    localized: "The Chatwoot server confirmed a different conversation, so no change was applied.",
                    comment: "Shown when a triage confirmation names an unexpected conversation"
                )
                return
            }
            conversation = confirmed
            errorMessage = nil
        } catch {
            guard loadedContext == context else { return }
            if Self.isCancellation(error) { return }
            errorMessage = Self.failureMessage(for: error, action: action)
        }
    }

    /// Applies the agent's intent to the label set the server currently holds.
    ///
    /// Comparison ignores case so that a label is not duplicated, while the
    /// server's own spelling is preserved.
    nonisolated static func merged(latest: [String], title: String, isAdding: Bool) -> [String] {
        let comparableTitle = title.lowercased()
        var result = latest.filter { $0.lowercased() != comparableTitle }
        if isAdding {
            result.append(title)
        }
        return result
    }

    private static func failureMessage(
        for error: Error,
        action: ConversationTriageAction
    ) -> String {
        let reason = message(for: error)
        return String(
            localized: "WootDesk could not \(action.actionDescription). \(reason)",
            comment: "Combines a triage action name with the reason the server rejected it"
        )
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? apiError.localizedDescription
        }
        if let localised = error as? LocalizedError, let description = localised.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let apiError = error as? APIError, apiError == .cancelled { return true }
        return false
    }
}

private struct TriageContext: Equatable {
    let profileID: UUID
    let accountID: Int
    let conversationID: Int
}

private struct OptionsContext: Equatable {
    let profileID: UUID
    let accountID: Int
}
