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

    /// True while the timeline shows content restored from the device rather
    /// than content just read from the server.
    public private(set) var isShowingCachedContent = false

    /// When the shown cached content was captured, so the agent can judge how
    /// stale it is. Nil whenever the timeline is live.
    public private(set) var cachedAt: Date?

    /// Submitted messages whose server outcome could not be confirmed.
    public private(set) var uncertainSends: [UncertainSend] = []

    /// The agent's editable draft. Assigning to it schedules a protected save,
    /// so the text survives the app being closed.
    public var draft: String {
        get { draftText }
        set {
            draftText = newValue
            scheduleDraftPersistence()
        }
    }

    /// The reply or private-note choice. It is stored with the draft so the
    /// restored text returns in the mode it was written in.
    public var composerMode: ConversationComposerMode {
        get { composerModeValue }
        set {
            composerModeValue = newValue
            scheduleDraftPersistence()
        }
    }

    private var draftText = ""
    private var composerModeValue: ConversationComposerMode = .reply
    private var loadedContext: LoadContext?
    private var contentRevision = UUID()
    private var draftPersistenceTask: Task<Void, Never>?

    private let offlineStore: any OfflineStore

    /// - Parameter offlineStore: Protected local storage. The default keeps
    ///   nothing, so a caller that has not opted in creates no device copy.
    public init(offlineStore: any OfflineStore = DisabledOfflineStore()) {
        self.offlineStore = offlineStore
    }

    public var canSend: Bool {
        let hasContent = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingAttachments.isEmpty
        return hasContent && !isLoading && !isSending
    }

    /// Whether the agent must be warned before sending again, because an
    /// earlier attempt may already have reached the server.
    public var requiresRetryConfirmation: Bool {
        !uncertainSends.isEmpty
    }

    /// Whether drafts and previously loaded content are being kept on the
    /// device. Views use it to describe accurately what is retained.
    public var isOfflineStorageEnabled: Bool {
        offlineStore.isPersisting
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

        let isNewContext = loadedContext != requestedContext
        if isNewContext {
            reset(for: requestedContext)
        } else if isLoading || isLoadingOlder || isSending {
            return
        }

        contentRevision = UUID()
        let requestRevision = contentRevision
        isLoading = true
        isLoadingOlder = false
        errorMessage = nil

        // Restoring first means the agent sees their unsent draft and the last
        // known messages straight away, rather than an empty view while the
        // network request runs, or nothing at all if it fails.
        if isNewContext {
            await restoreOfflineRecord(for: requestedContext, revision: requestRevision)
            guard contentRevision == requestRevision else { return }
        }

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
            isShowingCachedContent = false
            cachedAt = nil
            await cacheCurrentMessages(for: requestedContext)
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }

            // Cached content stays on screen rather than being replaced by an
            // empty timeline, and is labelled so the agent knows it may be out
            // of date.
            if isShowingCachedContent, !messages.isEmpty {
                errorMessage = Self.cachedContentMessage(for: error, cachedAt: cachedAt)
                return
            }

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
                draftText = ""
                await deleteStoredDraft(for: expectedContext)
            }
            let submittedAttachmentIDs = Set(submittedAttachments.map(\.id))
            pendingAttachments.removeAll { submittedAttachmentIDs.contains($0.id) }
            sendErrorMessage = nil

            // The send has been confirmed, so any earlier ambiguity about this
            // conversation is settled and the warning is withdrawn.
            await clearUncertainSends(for: expectedContext)
            await cacheCurrentMessages(for: expectedContext)
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }

            if let apiError = error as? APIError, apiError.isOutcomeUncertain {
                await recordUncertainSend(
                    for: expectedContext,
                    text: submittedDraft,
                    isPrivateNote: submittedMode == .privateNote,
                    attachmentCount: submittedAttachments.count
                )
                sendErrorMessage = Self.uncertainSendMessage(for: apiError)
                return
            }

            sendErrorMessage = Self.message(for: error)
        }
    }

    /// Dismisses the uncertain-send warning once the agent has decided how to
    /// proceed, so a confirmed retry is not blocked by it a second time.
    public func acknowledgeUncertainSends() async {
        guard let loadedContext else {
            uncertainSends = []
            return
        }
        await clearUncertainSends(for: loadedContext)
    }

    /// Writes any pending draft immediately, without waiting for the debounce.
    /// Views call this when the conversation is dismissed or the app is about
    /// to be backgrounded.
    public func persistDraftNow() async {
        draftPersistenceTask?.cancel()
        draftPersistenceTask = nil
        guard let loadedContext else { return }
        await writeDraft(for: loadedContext)
    }

    /// Removes all server-specific content from memory.
    ///
    /// Anything already written to protected storage is deliberately left in
    /// place: clearing the view is not the agent discarding their work. Only
    /// sending the draft or removing the profile deletes it.
    public func clear() {
        draftPersistenceTask?.cancel()
        draftPersistenceTask = nil
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
        isShowingCachedContent = false
        cachedAt = nil
        uncertainSends = []
        draftText = ""
        composerModeValue = .reply
    }

    private func reset(for context: LoadContext) {
        clear()
        loadedContext = context
    }

    // MARK: - Protected Offline Storage

    /// Restores the draft, the last cached page and any unresolved uncertain
    /// sends for a newly selected conversation.
    private func restoreOfflineRecord(for context: LoadContext, revision: UUID) async {
        let scope = context.scope
        let record: ConversationOfflineRecord
        do {
            record = try await offlineStore.loadRecord(for: scope)
        } catch {
            AppLogger.persistence.error("The offline record for a conversation could not be read.")
            return
        }
        guard contentRevision == revision, loadedContext == context else { return }

        if let draft = record.draft, !draft.isEmpty {
            draftText = draft.text
            composerModeValue = draft.isPrivateNote ? .privateNote : .reply
        }

        if let cached = record.cachedMessages, !cached.messages.isEmpty {
            messages = Self.normalised(cached.messages)
            hasOlderMessages = cached.hasOlderMessages
            isShowingCachedContent = true
            cachedAt = cached.cachedAt
        }

        uncertainSends = record.uncertainSends
        if let latest = record.uncertainSends.last {
            sendErrorMessage = Self.unresolvedUncertainSendMessage(attemptedAt: latest.attemptedAt)
        }
    }

    private func cacheCurrentMessages(for context: LoadContext) async {
        guard offlineStore.isPersisting, !messages.isEmpty else { return }
        let cached = CachedConversationMessages(
            scope: context.scope,
            messages: messages,
            hasOlderMessages: hasOlderMessages
        )
        do {
            try await offlineStore.saveCachedMessages(cached)
        } catch {
            AppLogger.persistence.error("A conversation page could not be cached.")
        }
    }

    private func recordUncertainSend(
        for context: LoadContext,
        text: String,
        isPrivateNote: Bool,
        attachmentCount: Int
    ) async {
        let send = UncertainSend(
            scope: context.scope,
            text: text,
            isPrivateNote: isPrivateNote,
            attachmentCount: attachmentCount
        )
        uncertainSends.append(send)
        do {
            try await offlineStore.recordUncertainSend(send)
        } catch {
            AppLogger.persistence.error("An uncertain send could not be recorded.")
        }
    }

    private func clearUncertainSends(for context: LoadContext) async {
        uncertainSends = []
        do {
            try await offlineStore.clearUncertainSends(for: context.scope)
        } catch {
            AppLogger.persistence.error("The uncertain-send records could not be cleared.")
        }
    }

    /// Coalesces keystrokes into one write shortly after typing stops.
    private func scheduleDraftPersistence() {
        guard offlineStore.isPersisting, let context = loadedContext else { return }
        draftPersistenceTask?.cancel()
        draftPersistenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.writeDraft(for: context)
        }
    }

    private func writeDraft(for context: LoadContext) async {
        guard loadedContext == context else { return }
        let draft = ConversationDraft(
            scope: context.scope,
            text: draftText,
            isPrivateNote: composerModeValue == .privateNote
        )
        do {
            // An emptied draft deletes its record rather than storing blank
            // text, so nothing is left on the device once the agent clears it.
            try await offlineStore.saveDraft(draft)
        } catch {
            AppLogger.persistence.error("A conversation draft could not be saved.")
        }
    }

    private func deleteStoredDraft(for context: LoadContext) async {
        do {
            try await offlineStore.deleteDraft(for: context.scope)
        } catch {
            AppLogger.persistence.error("A sent conversation draft could not be removed.")
        }
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

    /// Explains that the timeline is showing stored content and how old it is.
    private static func cachedContentMessage(for error: Error, cachedAt: Date?) -> String {
        let reason = message(for: error)
        guard let cachedAt else {
            return String(
                localized: "\(reason) Showing saved messages, which may be out of date.",
                comment: "Shown when a refresh fails and stored messages of unknown age remain on screen"
            )
        }
        let captured = cachedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            localized: "\(reason) Showing messages saved on \(captured), which may be out of date.",
            comment: "Shown when a refresh fails and stored messages remain on screen"
        )
    }

    /// Reports a send whose result is unknown, and warns that repeating it may
    /// post the message twice.
    private static func uncertainSendMessage(for error: APIError) -> String {
        let reason = error.errorDescription ?? error.localizedDescription
        return String(
            localized: "\(reason) WootDesk could not confirm whether the message was posted. Check the conversation before sending it again, because retrying may post it twice.",
            comment: "Shown when a send fails in a way that may still have reached the server"
        )
    }

    /// Repeats the warning when the agent returns to a conversation that still
    /// has an unresolved uncertain send.
    private static func unresolvedUncertainSendMessage(attemptedAt: Date) -> String {
        let attempted = attemptedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            localized: "A message sent on \(attempted) could not be confirmed. Check the conversation before sending it again, because retrying may post it twice.",
            comment: "Shown when reopening a conversation that has an unconfirmed send"
        )
    }
}

private struct LoadContext: Equatable {
    let profileID: UUID
    let accountID: Int
    let conversationID: Int

    var scope: ConversationScope {
        ConversationScope(
            profileID: profileID,
            accountID: accountID,
            conversationID: conversationID
        )
    }
}
