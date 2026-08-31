import Foundation
import SwiftUI

/// The explicit outgoing message mode selected by the agent.
public enum ConversationComposerMode: String, CaseIterable, Identifiable, Sendable {
    case reply
    case privateNote

    public var id: Self { self }

    public var title: String {
        switch self {
        case .reply: "Reply"
        case .privateNote: "Private Note"
        }
    }

    public var sendButtonTitle: String {
        switch self {
        case .reply: "Send Reply"
        case .privateNote: "Add Note"
        }
    }
}

/// Main-actor state for one selected conversation's message history and draft.
@Observable
@MainActor
public final class ConversationDetailState {
    public private(set) var messages: [ConversationMessage] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingOlder = false
    public private(set) var isSending = false
    public private(set) var hasOlderMessages = false
    public private(set) var errorMessage: String?
    public private(set) var sendErrorMessage: String?
    public private(set) var pendingAttachments: [OutgoingMessageAttachment] = []
    public var draft = ""
    public var composerMode: ConversationComposerMode = .reply

    private var loadedContext: LoadContext?
    private var contentRevision = UUID()

    public init() {}

    public var canSend: Bool {
        let hasContent = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingAttachments.isEmpty
        return hasContent && !isLoading && !isSending
    }

    /// Identifies the server and conversation context that owns an asynchronous
    /// file selection. A completed import from an older context is discarded.
    public var attachmentSelectionContextID: UUID {
        contentRevision
    }

    public func addPendingAttachments(_ attachments: [OutgoingMessageAttachment]) throws {
        guard pendingAttachments.count + attachments.count <= OutgoingMessageAttachment.maximumCount else {
            throw AttachmentSelectionError.tooManyFiles
        }

        let totalBytes = (pendingAttachments + attachments).reduce(0) { partial, attachment in
            partial + attachment.data.count
        }
        guard totalBytes <= OutgoingMessageAttachment.maximumTotalBytes else {
            throw AttachmentSelectionError.totalSizeExceeded
        }

        pendingAttachments.append(contentsOf: attachments)
        sendErrorMessage = nil
    }

    @discardableResult
    public func addPendingAttachments(
        _ attachments: [OutgoingMessageAttachment],
        ifCurrent contextID: UUID
    ) throws -> Bool {
        guard contentRevision == contextID else { return false }
        try addPendingAttachments(attachments)
        return true
    }

    public func removePendingAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
        sendErrorMessage = nil
    }

    public func reportAttachmentSelectionError(_ error: Error) {
        sendErrorMessage = Self.message(for: error)
    }

    /// Loads the newest page for the selected conversation.
    public func loadMessages(
        profile: ServerProfile,
        conversation: Conversation,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        let requestedContext = LoadContext(
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            conversationID: conversation.id
        )

        if loadedContext != requestedContext {
            reset(for: requestedContext)
        } else if isLoading || isLoadingOlder || isSending {
            return
        }

        contentRevision = UUID()
        let requestRevision = contentRevision
        isLoading = true
        isLoadingOlder = false
        errorMessage = nil

        defer {
            if contentRevision == requestRevision {
                isLoading = false
            }
        }

        do {
            let page = try await client.fetchMessages(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: conversation.id,
                beforeMessageID: nil
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }
            messages = Self.normalised(page.messages)
            hasOlderMessages = page.hasOlderMessages
            errorMessage = nil
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            messages = []
            hasOlderMessages = false
            errorMessage = Self.message(for: error)
        }
    }

    /// Loads messages older than the oldest stable message ID currently shown.
    public func loadOlderMessages(
        profile: ServerProfile,
        conversation: Conversation,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        let expectedContext = LoadContext(
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            conversationID: conversation.id
        )
        guard loadedContext == expectedContext,
              hasOlderMessages,
              !isLoading,
              !isSending,
              !isLoadingOlder,
              let oldestMessageID = messages.map(\.id).min() else { return }

        let requestRevision = contentRevision
        isLoadingOlder = true
        errorMessage = nil
        defer {
            if contentRevision == requestRevision {
                isLoadingOlder = false
            }
        }

        do {
            let page = try await client.fetchMessages(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: conversation.id,
                beforeMessageID: oldestMessageID
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }

            let existingIDs = Set(messages.map(\.id))
            let olderMessages = page.messages.filter { !existingIDs.contains($0.id) }
            messages = Self.normalised(olderMessages + messages)
            hasOlderMessages = page.hasOlderMessages && !olderMessages.isEmpty
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            errorMessage = Self.message(for: error)
        }
    }

    /// Sends the current draft. The draft is cleared only after the server
    /// returns a created message and only if the user has not edited it while
    /// the request was in flight.
    public func sendMessage(
        profile: ServerProfile,
        conversation: Conversation,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        let expectedContext = LoadContext(
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            conversationID: conversation.id
        )
        guard loadedContext == expectedContext, !isLoading, !isSending else { return }

        let submittedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedAttachments = pendingAttachments
        guard !submittedDraft.isEmpty || !submittedAttachments.isEmpty else {
            sendErrorMessage = APIError.invalidMessageContent.errorDescription
            return
        }

        let requestRevision = contentRevision
        let submittedMode = composerMode
        isSending = true
        sendErrorMessage = nil
        defer {
            if contentRevision == requestRevision {
                isSending = false
            }
        }

        do {
            let created = try await client.createMessage(
                baseURL: profile.baseURL,
                token: token,
                accountID: profile.selectedAccountID,
                conversationID: conversation.id,
                content: submittedDraft,
                isPrivate: submittedMode == .privateNote,
                attachments: submittedAttachments
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }

            messages = Self.normalised(messages.filter { $0.id != created.id } + [created])
            if draft.trimmingCharacters(in: .whitespacesAndNewlines) == submittedDraft {
                draft = ""
            }
            let submittedAttachmentIDs = Set(submittedAttachments.map(\.id))
            pendingAttachments.removeAll { submittedAttachmentIDs.contains($0.id) }
            sendErrorMessage = nil
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            sendErrorMessage = Self.message(for: error)
        }
    }

    /// Removes all server-specific content and the in-memory draft.
    public func clear() {
        contentRevision = UUID()
        loadedContext = nil
        messages = []
        isLoading = false
        isLoadingOlder = false
        isSending = false
        hasOlderMessages = false
        errorMessage = nil
        sendErrorMessage = nil
        pendingAttachments = []
        draft = ""
        composerMode = .reply
    }

    private func reset(for context: LoadContext) {
        clear()
        loadedContext = context
    }

    private static func normalised(_ messages: [ConversationMessage]) -> [ConversationMessage] {
        var byID: [Int: ConversationMessage] = [:]
        for message in messages {
            byID[message.id] = message
        }
        return byID.values.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.id < $1.id
            }
            return $0.createdAt < $1.createdAt
        }
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? apiError.localizedDescription
        }
        return error.localizedDescription
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let apiError = error as? APIError, apiError == .cancelled { return true }
        return false
    }
}

private struct LoadContext: Equatable {
    let profileID: UUID
    let accountID: Int
    let conversationID: Int
}
