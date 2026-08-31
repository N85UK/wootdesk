import SwiftUI

/// The conversation list for the active Chatwoot server profile.
///
/// This view renders list content only. The surrounding navigation structure is
/// supplied by the platform shell: a three-column split view on macOS, and a
/// navigation stack on iOS and iPadOS.
public struct ConversationListView: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var appModel: AppModel
    @Bindable var state: ConversationListState

    public init(appModel: AppModel, state: ConversationListState) {
        self.appModel = appModel
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            filterPicker
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            content
        }
        .searchable(text: $state.searchQuery, prompt: "Search conversations or contacts")
        .navigationTitle(appModel.activeProfile?.displayName ?? "Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refreshConversations() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.isLoading)
                .help("Reload conversations from the Chatwoot server")
            }
        }
        .task(
            id: ConversationLoadContext(
                profileID: appModel.activeProfile?.id,
                baseURL: appModel.activeProfile?.baseURL,
                accountID: appModel.activeProfile?.selectedAccountID,
                status: state.statusFilter
            )
        ) {
            // Clearing first guarantees that data from a previous server profile is
            // never displayed under a newly selected one or status filter.
            state.clear()
            await loadConversations()
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.isLoading && state.conversations.isEmpty {
            loadingView
        } else if let error = state.errorMessage, state.conversations.isEmpty {
            errorView(error)
        } else if state.filteredConversations.isEmpty {
            emptyView
        } else {
            conversationList
        }
    }

    private var filterPicker: some View {
        Picker("Status Filter", selection: $state.statusFilter) {
            Text("Open").tag(ConversationStatus?.some(.open))
            Text("Pending").tag(ConversationStatus?.some(.pending))
            Text("Resolved").tag(ConversationStatus?.some(.resolved))
            Text("Snoozed").tag(ConversationStatus?.some(.snoozed))
            Text("All").tag(ConversationStatus?.none)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Filter conversations by status")
    }

    private var conversationList: some View {
        #if os(macOS)
        // The selection drives the detail column of the surrounding split view.
        List(selection: $state.selectedConversationID) {
            ForEach(state.filteredConversations) { conversation in
                ConversationRowView(conversation: conversation)
                    .tag(conversation.id)
                    .onAppear { loadMoreIfNeeded(after: conversation) }
            }
            paginationFooter
        }
        .listStyle(.inset)
        #else
        List(selection: $state.selectedConversationID) {
            ForEach(state.filteredConversations) { conversation in
                NavigationLink(value: conversation.id) {
                    ConversationRowView(conversation: conversation)
                }
                .onAppear { loadMoreIfNeeded(after: conversation) }
            }
            paginationFooter
        }
        .listStyle(.plain)
        .refreshable {
            await refreshConversations()
        }
        #endif
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if state.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Text("Loading more conversations...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Supporting Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading conversations...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Unable to Load Conversations")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task { await loadConversations() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Conversations Found")
                .font(.headline)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        if !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No conversations match your search."
        }
        return "There are no conversations matching the current status filter."
    }

    // MARK: - Actions

    private func loadConversations() async {
        guard let profile = appModel.activeProfile, let token = appModel.activeToken else { return }
        await state.loadConversations(profile: profile, token: token, using: environment.apiClient)
    }

    private func refreshConversations() async {
        guard let profile = appModel.activeProfile, let token = appModel.activeToken else { return }
        await state.refresh(profile: profile, token: token, using: environment.apiClient)
    }

    /// Requests the next page once the final loaded row becomes visible.
    private func loadMoreIfNeeded(after conversation: Conversation) {
        guard state.searchQuery.isEmpty,
              conversation.id == state.conversations.last?.id,
              state.hasMorePages,
              let profile = appModel.activeProfile,
              let token = appModel.activeToken else { return }

        Task {
            await state.loadNextPage(profile: profile, token: token, using: environment.apiClient)
        }
    }
}

private struct ConversationLoadContext: Equatable {
    let profileID: UUID?
    let baseURL: URL?
    let accountID: Int?
    let status: ConversationStatus?
}

// MARK: - Previews

/// Builds a preview harness around a stubbed API client so each preview shows the
/// genuine view state rather than an imitation of it.
@MainActor
private func previewList(
    conversations: StubChatwootAPI.Outcome<[Conversation]>
) -> some View {
    let profile = PreviewData.profile
    let environment = AppEnvironment.preview(
        profiles: [profile],
        activeProfileID: profile.id,
        tokens: [profile.id: "test"],
        apiClient: StubChatwootAPI(conversationsOutcome: conversations)
    )
    let appModel = AppModel(environment: environment)
    appModel.applyPreviewState(profiles: [profile], activeProfile: profile, token: "test")

    return ConversationListView(appModel: appModel, state: ConversationListState())
        .environment(\.appEnvironment, environment)
        .frame(minWidth: 420, minHeight: 520)
}

#Preview("Conversations: Populated") {
    previewList(conversations: .success(PreviewData.conversations))
}

#Preview("Conversations: Loading") {
    previewList(conversations: .pending)
}

#Preview("Conversations: Empty") {
    previewList(conversations: .success([]))
}

#Preview("Conversations: Error") {
    previewList(conversations: .failure(.networkError("The connection appears to be offline.")))
}
