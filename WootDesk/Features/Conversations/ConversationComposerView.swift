import SwiftUI
import UniformTypeIdentifiers

/// A focused multiline composer for public replies and private notes.
public struct ConversationComposerView: View {
    @Bindable var state: ConversationDetailState
    public let onSend: () -> Void
    @FocusState private var isDraftFocused: Bool
    @State private var isSelectingAttachments = false
    @State private var isImportingAttachments = false
    @State private var attachmentImportTask: Task<Void, Never>?
    @State private var isConfirmingUncertainRetry = false

    /// Whether the agent is currently typing.
    ///
    /// The surrounding view uses this to give the timeline room on a phone,
    /// where the keyboard leaves almost none. Focus stays owned here; only the
    /// fact of it travels outward.
    @Binding var isComposing: Bool

    public init(
        state: ConversationDetailState,
        isComposing: Binding<Bool>,
        onSend: @escaping () -> Void
    ) {
        self.state = state
        self._isComposing = isComposing
        self.onSend = onSend
    }

    /// Warns before a retry that could duplicate an unconfirmed send, and sends
    /// straight away otherwise.
    private func sendOrConfirm() {
        if state.requiresRetryConfirmation {
            isConfirmingUncertainRetry = true
        } else {
            onSend()
        }
    }

    private var draftRetentionText: String {
        state.isOfflineStorageEnabled
            ? String(
                localized: "Drafts are saved on this device for the current server profile only, protected at rest, and removed when the message sends or the profile is deleted. Selected attachments stay in memory only.",
                comment: "Composer footnote shown when protected offline storage is enabled"
            )
            : String(
                localized: "Drafts and selected attachments stay in memory only and are discarded when you switch conversations or server profiles.",
                comment: "Composer footnote shown when protected offline storage is disabled"
            )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    modePicker
                    Spacer()
                    visibilityText
                }

                VStack(alignment: .leading, spacing: 6) {
                    modePicker
                    visibilityText
                }
            }

            if let error = state.sendErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Send error: \(error)")
            }

            if !state.pendingAttachments.isEmpty {
                pendingAttachmentList
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    isSelectingAttachments = true
                } label: {
                    if isImportingAttachments {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Add attachments", systemImage: "paperclip")
                            .labelStyle(.iconOnly)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(state.isSending || isImportingAttachments)
                .help("Add files to this message")
                .accessibilityLabel("Add attachments")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $state.draft)
                        .focused($isDraftFocused)
                        .onChange(of: isDraftFocused) { _, focused in
                            isComposing = focused
                        }
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(minHeight: 64, maxHeight: 128)
                        .background(Color.secondary.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        }
                        .accessibilityLabel(state.composerMode == .reply ? "Reply text" : "Private note text")
                        .accessibilityIdentifier("conversation-composer")

                    if state.draft.isEmpty {
                        Text(state.composerMode == .reply ? "Write a reply..." : "Write a private note...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }

                Button(action: sendOrConfirm) {
                    if state.isSending {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 70)
                    } else {
                        Text(state.composerMode.sendButtonTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!state.canSend)
                .help("Send with Command and Return")
                .accessibilityHint("Sends the current draft to Chatwoot")
                .accessibilityIdentifier("send-message")
            }

            Text(draftRetentionText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
        .confirmationDialog(
            "This message may already have been sent",
            isPresented: $isConfirmingUncertainRetry,
            titleVisibility: .visible
        ) {
            Button("Send Again", role: .destructive) {
                Task {
                    await state.acknowledgeUncertainSends()
                    onSend()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("WootDesk could not confirm whether an earlier attempt reached the server. Check the conversation first, because sending again may post the message twice.")
        }
        .fileImporter(
            isPresented: $isSelectingAttachments,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            importAttachments(result)
        }
        .onDisappear {
            attachmentImportTask?.cancel()
            attachmentImportTask = nil
        }
    }

    private var modePicker: some View {
        Picker("Message type", selection: $state.composerMode) {
            ForEach(ConversationComposerMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
        .accessibilityLabel("Choose public reply or private note")
    }

    private var visibilityText: some View {
        Text(state.composerMode == .reply ? "Visible to the contact" : "Visible only to Chatwoot agents")
            .font(.caption)
            .foregroundStyle(state.composerMode == .privateNote ? .orange : .secondary)
    }

    private var pendingAttachmentList: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(state.pendingAttachments) { attachment in
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(attachment.fileName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text(attachment.data.count.formatted(.byteCount(style: .file)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            state.removePendingAttachment(id: attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .disabled(state.isSending)
                        .accessibilityLabel("Remove \(attachment.fileName)")
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Selected attachments")
    }

    private func importAttachments(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else {
            if case .failure(let error) = result {
                let cocoaError = error as NSError
                guard !(cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError) else {
                    return
                }
                state.reportAttachmentSelectionError(error)
            }
            return
        }

        guard state.pendingAttachments.count + urls.count <= OutgoingMessageAttachment.maximumCount else {
            state.reportAttachmentSelectionError(AttachmentSelectionError.tooManyFiles)
            return
        }

        isImportingAttachments = true
        let contextID = state.attachmentSelectionContextID
        let existingBytes = state.pendingAttachments.reduce(0) { $0 + $1.data.count }
        attachmentImportTask?.cancel()
        attachmentImportTask = Task {
            defer { isImportingAttachments = false }
            do {
                var loaded: [OutgoingMessageAttachment] = []
                var loadedBytes = 0
                for url in urls {
                    try Task.checkCancellation()
                    let attachment = try await OutgoingMessageAttachment.load(from: url)
                    loadedBytes += attachment.data.count
                    guard existingBytes + loadedBytes <= OutgoingMessageAttachment.maximumTotalBytes else {
                        throw AttachmentSelectionError.totalSizeExceeded
                    }
                    loaded.append(attachment)
                }
                try Task.checkCancellation()
                try state.addPendingAttachments(loaded, ifCurrent: contextID)
            } catch {
                guard !Task.isCancelled else { return }
                state.reportAttachmentSelectionError(error)
            }
        }
    }
}

#Preview("Composer: Reply") {
    ConversationComposerView(
        state: ConversationDetailState(),
        isComposing: .constant(false),
        onSend: {}
    )
        .frame(width: 620)
}

#Preview("Composer: Private Note") {
    let state = ConversationDetailState()
    state.composerMode = .privateNote
    state.draft = "An invented internal note"
    return ConversationComposerView(state: state, isComposing: .constant(false), onSend: {})
        .frame(width: 620)
}
