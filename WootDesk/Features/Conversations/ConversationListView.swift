import SwiftUI

/// How the surrounding navigation structure expects a conversation to be opened.
public enum ConversationListPresentation: Sendable {
    /// The list drives an adjacent detail column through its selection, used by
    /// the Mac and iPad split layouts.
    case splitViewSelection
    /// The list pushes the conversation onto a navigation stack, used on iPhone.
    case navigationStack
}

/// Which control the status filter uses at the current text size.
///
/// A segmented control cannot lay out five readable labels at an accessibility
/// text size without clipping, so the filter becomes a menu instead of shrinking
/// or truncating its options.
///
/// The decision is deliberately made on text size alone, not on available
/// width. In the iPad split view the conversation column is narrow enough to
/// truncate "Resolved" to "Resolv…" at the default text size, and the obvious
/// remedy, wrapping both styles in `ViewThatFits(in: .horizontal)`, does not
/// work: a segmented `Picker` reports a greedy ideal width, so `ViewThatFits`
/// rejects it at every size and the menu wins even on a full-width iPhone
/// list where the segmented control fits comfortably. Measured on both, 1
/// September 2026. Losing the segmented control everywhere is a worse outcome
/// than two truncated characters in one column, so the truncation stands.
public enum ConversationFilterPickerLayout: Sendable {
    case segmented
    case menu

    public static func preferred(for size: DynamicTypeSize) -> Self {
        size.isAccessibilitySize ? .menu : .segmented
    }
}

/// The conversation list for the active Chatwoot server profile.
///
/// This view renders list content only. The surrounding navigation structure is
/// supplied by the platform shell: a three-column split view on macOS and iPad,
/// and a navigation stack on iPhone.
public struct ConversationListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var appModel: AppModel
    @Bindable var state: ConversationListState
    let presentation: ConversationListPresentation

    public init(
        appModel: AppModel,
        state: ConversationListState,
        presentation: ConversationListPresentation = .splitViewSelection
    ) {
        self.appModel = appModel
        self.state = state
        self.presentation = presentation
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

    @ViewBuilder
    private var filterPicker: some View {
        switch ConversationFilterPickerLayout.preferred(for: dynamicTypeSize) {
        case .segmented:
            statusPicker
                .pickerStyle(.segmented)
        case .menu:
            statusPicker
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusPicker: some View {
        Picker("Status Filter", selection: $state.statusFilter) {
            Text("Open").tag(ConversationStatus?.some(.open))
            Text("Pending").tag(ConversationStatus?.some(.pending))
            Text("Resolved").tag(ConversationStatus?.some(.resolved))
            Text("Snoozed").tag(ConversationStatus?.some(.snoozed))
            Text("All").tag(ConversationStatus?.none)
        }
        .accessibilityLabel("Filter conversations by status")
    }

    @ViewBuilder
    private var conversationList: some View {
        switch presentation {
        case .splitViewSelection:
            selectionList
        case .navigationStack:
            stackList
        }
    }

    /// The selection drives the detail column of the surrounding split view.
    private var selectionList: some View {
        List(selection: $state.selectedConversationID) {
            ForEach(state.filteredConversations) { conversation in
                ConversationRowView(conversation: conversation)
                    .tag(conversation.id)
                    .onAppear { loadMoreIfNeeded(after: conversation) }
            }
            paginationFooter
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.plain)
        .refreshable {
            await refreshConversations()
        }
        #endif
    }

    /// Each row pushes the conversation onto the surrounding navigation stack.
    private var stackList: some View {
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
        #if os(iOS)
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
