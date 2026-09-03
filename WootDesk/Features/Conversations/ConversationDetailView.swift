import SwiftUI

/// Loads and displays the selected conversation's real Chatwoot message history.
public struct ConversationDetailView: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var appModel: AppModel
    @Bindable var state: ConversationDetailState
    @Bindable var triageState: ConversationTriageState
    public let conversation: Conversation?

    public init(
        appModel: AppModel,
        state: ConversationDetailState,
        triageState: ConversationTriageState,
        conversation: Conversation?
    ) {
        self.appModel = appModel
        self.state = state
        self.triageState = triageState
        self.conversation = conversation
    }

    public var body: some View {
        Group {
            if let conversation {
                selectedConversation(conversation)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        ConversationComposerView(state: state) {
                            Task { await sendMessage(for: conversation) }
                        }
                    }
            } else {
                noSelection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(conversation.map { $0.contact?.name ?? Self.untitledConversationName(for: $0) } ?? String(localized: "Conversation", comment: "Navigation title when no conversation is selected"))
        .toolbar {
            if let conversation {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadMessages(for: conversation) }
                    } label: {
                        // A distinct symbol from the conversation list's
                        // refresh. On iOS the two live in separate navigation
                        // bars, but macOS unifies the split view's toolbar, so
                        // an identical icon appears twice with nothing to tell
                        // the two apart.
                        Label("Refresh Messages", systemImage: "arrow.clockwise.circle")
                    }
                    .disabled(state.isLoading || state.isSending)
                    .help("Reload this conversation's messages")
                }
            }
        }
        .task(
            id: ConversationDetailLoadContext(
                profileID: appModel.activeProfile?.id,
                baseURL: appModel.activeProfile?.baseURL,
                accountID: appModel.activeProfile?.selectedAccountID,
                conversationID: conversation?.id
            )
        ) {
            triageState.adopt(conversation, profile: appModel.activeProfile)
            guard let conversation else {
                state.clear()
                return
            }
            await loadMessages(for: conversation)
        }
    }

    private func selectedConversation(_ conversation: Conversation) -> some View {
        VStack(spacing: 0) {
            conversationHeader(conversation)
            ConversationActionsView(
                state: triageState,
                profile: appModel.activeProfile,
                token: appModel.activeToken
            )
            .padding(.bottom, 8)
            Divider()
            messageContent(conversation)
        }
    }

    private func conversationHeader(_ conversation: Conversation) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.contact?.name ?? Self.untitledConversationName(for: conversation))
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("#\(conversation.id.identifierText)")
                    Text((triageState.conversation ?? conversation).status.displayName)
                    if let inboxName = conversation.inboxName {
                        Text(inboxName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if state.isLoading, !state.messages.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Refreshing messages")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    /// Marks a timeline that is showing content restored from the device, so
    /// the agent never mistakes a stored copy for the live conversation.
    private var savedCopyNotice: some View {
        Label {
            if let cachedAt = state.cachedAt {
                Text("Saved copy from \(cachedAt.formatted(date: .abbreviated, time: .shortened)). Newer messages may not appear.")
            } else {
                Text("Saved copy. Newer messages may not appear.")
            }
        } icon: {
            Image(systemName: "arrow.down.circle.dotted")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("cached-content-notice")
    }

    @ViewBuilder
    private func messageContent(_ conversation: Conversation) -> some View {
        if state.isLoading && state.messages.isEmpty {
            loadingView
        } else if let error = state.errorMessage, state.messages.isEmpty {
            errorView(error, conversation: conversation)
        } else if state.messages.isEmpty {
            emptyView
        } else {
            timeline(conversation)
        }
    }

    private func timeline(_ conversation: Conversation) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                olderMessagesControl(conversation)

                if state.isShowingCachedContent {
                    savedCopyNotice
                }

                if let error = state.errorMessage {
                    inlineError(error, conversation: conversation)
                }

                ForEach(state.messages) { message in
                    ConversationMessageRowView(message: message)
                        .id(message.id)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.bottom)
        #if os(iOS)
        .refreshable {
            await loadMessages(for: conversation)
        }
        #endif
    }

    @ViewBuilder
    private func olderMessagesControl(_ conversation: Conversation) -> some View {
        if state.hasOlderMessages || state.isLoadingOlder {
            Button {
                Task { await loadOlderMessages(for: conversation) }
            } label: {
                if state.isLoadingOlder {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading earlier messages...")
                    }
                } else {
                    Label("Load Earlier Messages", systemImage: "arrow.up.circle")
                }
            }
            .buttonStyle(.borderless)
            .disabled(state.isLoadingOlder)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading message history...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func errorView(_ message: String, conversation: Conversation) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Unable to Load Messages")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Button("Try Again") {
                Task { await loadMessages(for: conversation) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inlineError(_ message: String, conversation: Conversation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                Task { await loadOlderMessages(for: conversation) }
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Messages Yet")
                .font(.headline)
            Text("Start the conversation with a reply, or add a private note for other agents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noSelection: some View {
        VStack(spacing: 14) {
            Image(systemName: "message.badge")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("No Conversation Selected")
                .font(.title3.bold())
            Text("Select a conversation to load its message history and reply.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(32)
    }

    /// The name shown for a conversation whose contact Chatwoot did not supply.
    static func untitledConversationName(for conversation: Conversation) -> String {
        String(
            localized: "Conversation #\(conversation.id.identifierText)",
            comment: "Title for a conversation with no contact name"
        )
    }

    private func loadMessages(for conversation: Conversation) async {
        guard let profile = appModel.activeProfile,
              let token = appModel.activeToken else {
            state.clear()
            return
        }
        await state.loadMessages(
            profile: profile,
            conversation: conversation,
            token: token,
            using: environment.apiClient
        )
    }

    private func loadOlderMessages(for conversation: Conversation) async {
        guard let profile = appModel.activeProfile,
              let token = appModel.activeToken else { return }
        await state.loadOlderMessages(
            profile: profile,
            conversation: conversation,
            token: token,
            using: environment.apiClient
        )
    }

    private func sendMessage(for conversation: Conversation) async {
        guard let profile = appModel.activeProfile,
              let token = appModel.activeToken else { return }
        await state.sendMessage(
            profile: profile,
            conversation: conversation,
            token: token,
            using: environment.apiClient
        )
    }
}

private struct ConversationDetailLoadContext: Equatable {
    let profileID: UUID?
    let baseURL: URL?
    let accountID: Int?
    let conversationID: Int?
}

@MainActor
private func previewDetail(
    messages: StubChatwootAPI.Outcome<ConversationMessagePage>,
    conversation: Conversation? = PreviewData.conversations.first
) -> some View {
    let profile = PreviewData.profile
    let environment = AppEnvironment.preview(
        profiles: [profile],
        activeProfileID: profile.id,
        tokens: [profile.id: "test"],
        apiClient: StubChatwootAPI(messagesOutcome: messages)
    )
    let appModel = AppModel(environment: environment)
    appModel.applyPreviewState(profiles: [profile], activeProfile: profile, token: "test")

    let triageState = ConversationTriageState()
    triageState.adopt(conversation, profile: profile)

    return ConversationDetailView(
        appModel: appModel,
        state: ConversationDetailState(),
        triageState: triageState,
        conversation: conversation
    )
    .environment(\.appEnvironment, environment)
    .frame(minWidth: 520, minHeight: 620)
}

#Preview("Message History: Populated") {
    previewDetail(
        messages: .success(
            ConversationMessagePage(messages: PreviewData.messages, hasOlderMessages: false)
        )
    )
}

#Preview("Message History: Loading") {
    previewDetail(messages: .pending)
}

#Preview("Message History: Empty") {
    previewDetail(messages: .success(ConversationMessagePage(messages: [], hasOlderMessages: false)))
}

#Preview("Message History: Error") {
    previewDetail(messages: .failure(.offline))
}

#Preview("Message History: No Selection") {
    previewDetail(
        messages: .success(ConversationMessagePage(messages: [], hasOlderMessages: false)),
        conversation: nil
    )
}
