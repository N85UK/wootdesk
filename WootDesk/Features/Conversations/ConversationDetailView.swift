import SwiftUI

/// Placeholder detail view for a selected conversation.
///
/// Message history, replies, and attachments are the next milestone. This view
/// deliberately shows only what the conversation list endpoint already returned,
/// so that nothing here implies data the app has not actually loaded.
public struct ConversationDetailView: View {
    public let conversation: Conversation?

    public init(conversation: Conversation?) {
        self.conversation = conversation
    }

    public var body: some View {
        Group {
            if let conversation {
                selectedConversation(conversation)
            } else {
                noSelection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(conversation.map { $0.contact?.name ?? "Conversation #\($0.id)" } ?? "Conversation")
    }

    private func selectedConversation(_ conversation: Conversation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(conversation.contact?.name ?? "Conversation #\(conversation.id)")
                        .font(.title2.bold())

                    Text("Conversation #\(conversation.id) · \(conversation.status.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                summaryGrid(conversation)

                if let preview = conversation.lastMessagePreview, !preview.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latest Message")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(preview)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                nextMilestoneNotice
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func summaryGrid(_ conversation: Conversation) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
            summaryRow("Status", conversation.status.displayName)
            if let priority = conversation.priority {
                summaryRow("Priority", priority.displayName)
            }
            if let inbox = conversation.inboxName {
                summaryRow("Inbox", inbox)
            }
            if let channel = conversation.channel {
                summaryRow("Channel", channel)
            }
            if let email = conversation.contact?.email {
                summaryRow("Contact Email", email)
            }
            summaryRow("Last Activity", conversation.lastActivityAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    private var nextMilestoneNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coming in the next milestone")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Label("Full message history", systemImage: "clock.arrow.circlepath")
            Label("Agent replies and private notes", systemImage: "arrowshape.turn.up.left")
            Label("Attachments and media", systemImage: "paperclip")
            Label("Assignment, labels, and status changes", systemImage: "person.crop.circle.badge.checkmark")
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var noSelection: some View {
        VStack(spacing: 14) {
            Image(systemName: "message.badge")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("No Conversation Selected")
                .font(.title3.bold())

            Text("Select a conversation from the list to see its details. Message history and replies arrive in the next milestone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(32)
    }
}

#Preview("Detail: Selected Conversation") {
    ConversationDetailView(conversation: PreviewData.conversations.first)
        .frame(width: 560, height: 620)
}

#Preview("Detail: No Selection") {
    ConversationDetailView(conversation: nil)
        .frame(width: 560, height: 620)
}
