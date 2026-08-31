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

    public init(state: ConversationDetailState, onSend: @escaping () -> Void) {
        self.state = state
        self.onSend = onSend
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

                Button(action: onSend) {
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

            Text("Drafts and selected attachments stay in memory only and are discarded when you switch conversations or server profiles.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
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
    ConversationComposerView(state: ConversationDetailState(), onSend: {})
        .frame(width: 620)
}

#Preview("Composer: Private Note") {
    let state = ConversationDetailState()
    state.composerMode = .privateNote
    state.draft = "An invented internal note"
    return ConversationComposerView(state: state, onSend: {})
        .frame(width: 620)
}
