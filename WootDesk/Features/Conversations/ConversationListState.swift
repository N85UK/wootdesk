import Foundation
import SwiftUI
import os

/// State manager for loading, paging, filtering, and displaying conversations.
@Observable
@MainActor
public final class ConversationListState {
    public var conversations: [Conversation] = []
    public var statusFilter: ConversationStatus? = .open
    public var selectedConversationID: Int?
    public var isLoading: Bool = false
    public var isLoadingNextPage: Bool = false
    public var errorMessage: String?
    public var currentPage: Int = 1
    public var hasMorePages: Bool = true
    public var searchQuery: String = ""

    private var loadedProfileID: UUID?
    private var loadedStatusFilter: ConversationStatus?
    private var contentRevision = UUID()

    public init() {}

    /// The conversation matching the current selection, if any.
    public var selectedConversation: Conversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    /// Conversations narrowed by the current search query.
    public var filteredConversations: [Conversation] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return conversations }

        let query = trimmed.lowercased()
        return conversations.filter { conversation in
            let nameMatch = conversation.contact?.name.lowercased().contains(query) ?? false
            let messageMatch = conversation.lastMessagePreview?.lowercased().contains(query) ?? false
            let inboxMatch = conversation.inboxName?.lowercased().contains(query) ?? false
            let idMatch = String(conversation.id).contains(query)
            return nameMatch || messageMatch || inboxMatch || idMatch
        }
    }

    /// Loads the first page of conversations, replacing anything already held.
    public func loadConversations(
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        let requestedStatus = statusFilter
        let contextChanged = loadedProfileID != profile.id || loadedStatusFilter != requestedStatus
        if contextChanged {
            conversations = []
            selectedConversationID = nil
            currentPage = 1
            hasMorePages = true
        }
        loadedProfileID = profile.id
        loadedStatusFilter = requestedStatus
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
            let fetched = try await fetchPage(
                1,
                profile: profile,
                token: token,
                status: requestedStatus,
                using: client
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }
            conversations = fetched
            currentPage = 1
            hasMorePages = !fetched.isEmpty
            errorMessage = nil
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            conversations = []
            hasMorePages = false
            errorMessage = Self.message(for: error)
        }
    }

    /// Appends the next page of conversations, if the previous page suggested more exist.
    public func loadNextPage(
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        guard hasMorePages,
              !isLoading,
              !isLoadingNextPage,
              loadedProfileID == profile.id,
              loadedStatusFilter == statusFilter else { return }

        let requestRevision = contentRevision
        let requestedStatus = statusFilter
        isLoadingNextPage = true
        let nextPage = currentPage + 1
        defer {
            if contentRevision == requestRevision {
                isLoadingNextPage = false
            }
        }

        do {
            let fetched = try await fetchPage(
                nextPage,
                profile: profile,
                token: token,
                status: requestedStatus,
                using: client
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }
            let knownIDs = Set(conversations.map(\.id))
            let newItems = fetched.filter { !knownIDs.contains($0.id) }

            conversations.append(contentsOf: newItems)
            currentPage = nextPage
            hasMorePages = !fetched.isEmpty && !newItems.isEmpty
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            // A failed page must not discard the pages already shown.
            hasMorePages = false
            errorMessage = Self.message(for: error)
        }
    }

    /// Reloads the first page without clearing the list first, for pull-to-refresh.
    public func refresh(
        profile: ServerProfile,
        token: String,
        using client: ChatwootAPIProtocol
    ) async {
        guard loadedProfileID == profile.id, loadedStatusFilter == statusFilter else {
            await loadConversations(profile: profile, token: token, using: client)
            return
        }

        let requestedStatus = statusFilter
        contentRevision = UUID()
        let requestRevision = contentRevision
        isLoadingNextPage = false

        do {
            let fetched = try await fetchPage(
                1,
                profile: profile,
                token: token,
                status: requestedStatus,
                using: client
            )
            guard contentRevision == requestRevision, !Task.isCancelled else { return }
            conversations = fetched
            currentPage = 1
            hasMorePages = !fetched.isEmpty
            errorMessage = nil
        } catch {
            guard contentRevision == requestRevision else { return }
            if Self.isCancellation(error) { return }
            errorMessage = Self.message(for: error)
        }
    }

    /// Replaces a listed conversation with the state a triage change confirmed.
    ///
    /// The conversation stays in the list even when the confirmed status no
    /// longer matches the active filter, so that the agent sees the result of
    /// their own action rather than the row silently disappearing.
    public func applyConfirmedConversation(_ conversation: Conversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index] = conversation
    }

    /// Adds a conversation that a notification identified but that the loaded
    /// page did not contain, then selects it.
    ///
    /// The conversation is placed at the top of the list so that the agent can
    /// see the item the notification referred to. Nothing else is removed.
    public func adoptRoutedConversation(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        selectedConversationID = conversation.id
    }

    /// Removes any search or status filter that would hide a conversation the
    /// agent has been sent to.
    public func clearFiltersForRouting() {
        searchQuery = ""
        statusFilter = nil
    }

    /// Clears all conversation data. Used when switching server profiles so that
    /// data loaded from one server is never shown under another.
    public func clear() {
        contentRevision = UUID()
        loadedProfileID = nil
        loadedStatusFilter = nil
        conversations = []
        selectedConversationID = nil
        errorMessage = nil
        isLoading = false
        isLoadingNextPage = false
        currentPage = 1
        hasMorePages = true
    }

    private func fetchPage(
        _ page: Int,
        profile: ServerProfile,
        token: String,
        status: ConversationStatus?,
        using client: ChatwootAPIProtocol
    ) async throws -> [Conversation] {
        try await client.fetchConversations(
            baseURL: profile.baseURL,
            token: token,
            accountID: profile.selectedAccountID,
            status: status,
            page: page
        )
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
