import SwiftUI

/// Renders a single conversation row with contact information, status, and message preview.
public struct ConversationRowView: View {
    public let conversation: Conversation

    public init(conversation: Conversation) {
        self.conversation = conversation
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Text(conversation.contact?.initials ?? "#\(conversation.id)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityHidden(true)

            // Conversation details
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.contact?.name ?? "Conversation #\(conversation.id)")
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedTime(conversation.lastActivityAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let preview = conversation.lastMessagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }

                HStack(spacing: 6) {
                    statusBadge(conversation.status)

                    if let priority = conversation.priority {
                        priorityBadge(priority)
                    }

                    if let inbox = conversation.inboxName {
                        Text(inbox)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(conversation.unreadCount) unread messages")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func statusBadge(_ status: ConversationStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .open: return (.blue.opacity(0.15), .blue)
            case .resolved: return (.green.opacity(0.15), .green)
            case .pending: return (.orange.opacity(0.15), .orange)
            case .snoozed: return (.purple.opacity(0.15), .purple)
            }
        }()

        return Text(status.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
    }

    private func priorityBadge(_ priority: ConversationPriority) -> some View {
        let fg: Color = {
            switch priority {
            case .urgent: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .gray
            }
        }()

        return Label(priority.displayName, systemImage: "flag.fill")
            .font(.caption2)
            .foregroundStyle(fg)
            .labelStyle(.titleAndIcon)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview("Row: Unread and Prioritised") {
    List {
        ForEach(PreviewData.conversations) { conversation in
            ConversationRowView(conversation: conversation)
        }
    }
    .frame(width: 420, height: 380)
}

#Preview("Row: Minimal Fields") {
    ConversationRowView(
        conversation: Conversation(
            id: 2048,
            accountID: 1,
            inboxID: 0,
            status: .pending,
            lastActivityAt: Date().addingTimeInterval(-3600)
        )
    )
    .padding()
    .frame(width: 420)
}
