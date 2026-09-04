import SwiftUI

/// How a conversation row arranges its status, priority and inbox badges.
///
/// The badges cannot share one line at an accessibility text size. Left in an
/// `HStack` they are compressed to their minimum intrinsic width, which wraps
/// every label to a single character per line, so "Urgent" renders as a
/// vertical column of letters. Stacking them keeps each badge readable instead.
public enum ConversationRowMetadataLayout: Sendable {
    case row
    case stacked

    public static func preferred(for size: DynamicTypeSize) -> Self {
        size.isAccessibilitySize ? .stacked : .row
    }
}

/// Renders a single conversation row with contact information, status, and message preview.
public struct ConversationRowView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    public let conversation: Conversation

    public init(conversation: Conversation) {
        self.conversation = conversation
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar. Dropped at accessibility text sizes: the details column
            // beside it grows until the row is wider than the window, and the
            // avatar is what gets pushed off the left edge, half of it clipped
            // by the screen. It carries no information VoiceOver can use, being
            // accessibilityHidden already, so the width is better spent on the
            // text. Caught by a UI test at the largest accessibility size,
            // which passes at the default size.
            if !dynamicTypeSize.isAccessibilitySize {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Text(conversation.contact?.initials ?? "#\(conversation.id.identifierText)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)
            }

            // Conversation details
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.contact?.name ?? ConversationDetailView.untitledConversationName(for: conversation))
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

                metadata
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("conversation-row-\(conversation.id)")
    }

    /// The badge row, laid out horizontally or stacked depending on text size.
    @ViewBuilder
    private var metadata: some View {
        switch ConversationRowMetadataLayout.preferred(for: dynamicTypeSize) {
        case .row:
            HStack(spacing: 6) {
                badges
                Spacer()
                unreadBadge
            }
        case .stacked:
            VStack(alignment: .leading, spacing: 4) {
                badges
                unreadBadge
            }
        }
    }

    /// Every badge keeps its intrinsic width so a label never wraps mid-word.
    @ViewBuilder
    private var badges: some View {
        statusBadge(conversation.status)

        if let priority = conversation.priority {
            priorityBadge(priority)
        }

        if let inbox = conversation.inboxName {
            Text(inbox)
                .font(.caption2)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var unreadBadge: some View {
        if conversation.unreadCount > 0 {
            Text("\(conversation.unreadCount)")
                .font(.caption2.bold())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .accessibilityLabel("\(conversation.unreadCount) unread messages")
        }
    }

    private func statusBadge(_ status: ConversationStatus) -> some View {
        let swatch = ConversationBadgePalette.swatch(for: status)
        let bg = swatch.background.color
        let fg = swatch.foreground(for: colorSchemeContrast).color

        return Text(status.displayName)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
    }

    private func priorityBadge(_ priority: ConversationPriority) -> some View {
        let swatch = ConversationBadgePalette.swatch(for: priority)
        let fg = swatch.foreground(for: colorSchemeContrast).color

        // A chip rather than tinted text, for the reason given on the palette:
        // tinted text has to sit on whatever the window background happens to
        // be, and no one colour clears 4.5:1 against both light and dark.
        return Label(priority.displayName, systemImage: "flag.fill")
            .font(.caption2)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(swatch.background.color)
            .foregroundStyle(fg)
            .clipShape(Capsule())
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
