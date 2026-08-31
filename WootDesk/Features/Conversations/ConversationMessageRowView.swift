import SwiftUI

/// A timeline row for incoming messages, agent replies, activities, and notes.
public struct ConversationMessageRowView: View {
    public let message: ConversationMessage

    public init(message: ConversationMessage) {
        self.message = message
    }

    public var body: some View {
        if message.isActivity {
            activityRow
        } else {
            messageRow
        }
    }

    private var messageRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.isOutgoing {
                Spacer(minLength: 44)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    if message.isPrivate {
                        Label("Private note", systemImage: "lock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    } else if let senderName = message.senderName, !senderName.isEmpty {
                        Text(senderName)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(message.createdAt, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if message.hasTextContent || message.attachments.isEmpty {
                    Text(message.safeAttributedContent)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !message.attachments.isEmpty {
                    VStack(spacing: 7) {
                        ForEach(message.attachments) { attachment in
                            ConversationAttachmentView(attachment: attachment)
                        }
                    }
                }

                if message.isOutgoing,
                   let deliveryStatus = message.deliveryStatus,
                   !deliveryStatus.isEmpty {
                    Text(deliveryStatus.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: 520, alignment: .leading)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if message.isPrivate {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                }
            }

            if !message.isOutgoing {
                Spacer(minLength: 44)
            }
        }
        .accessibilityElement(children: message.attachments.isEmpty ? .combine : .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("message-\(message.id)")
    }

    private var activityRow: some View {
        HStack {
            Spacer()
            Label(message.displayContent, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var bubbleBackground: Color {
        if message.isPrivate {
            return .orange.opacity(0.12)
        }
        if message.isOutgoing {
            return .accentColor.opacity(0.14)
        }
        return .secondary.opacity(0.10)
    }

    private var accessibilityLabel: String {
        let type: String
        if message.isPrivate {
            type = "Private note"
        } else if message.isOutgoing {
            type = "Outgoing reply"
        } else {
            type = "Incoming message"
        }
        let sender = message.senderName.map { " from \($0)" } ?? ""
        return "\(type)\(sender): \(message.displayContent)"
    }
}

#Preview("Message Rows") {
    ScrollView {
        LazyVStack(spacing: 14) {
            ForEach(PreviewData.messages) { message in
                ConversationMessageRowView(message: message)
            }
        }
        .padding()
    }
    .frame(width: 560, height: 520)
}
