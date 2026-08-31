import SwiftUI

/// Presents attachment metadata without downloading remote content automatically.
public struct ConversationAttachmentView: View {
    @Environment(\.openURL) private var openURL
    public let attachment: ConversationAttachment
    @State private var pendingURL: URL?
    @State private var isConfirmingOpen = false

    public init(attachment: ConversationAttachment) {
        self.attachment = attachment
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)

                Text(metadata)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let dataURL = attachment.dataURL {
                Button {
                    pendingURL = dataURL
                    isConfirmingOpen = true
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Open this attachment using the system handler")
                .accessibilityLabel("Open \(attachment.displayName)")
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .help("Chatwoot did not provide a safe HTTPS attachment address")
                    .accessibilityLabel("Attachment unavailable")
            }
        }
        .padding(9)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .alert("Open attachment?", isPresented: $isConfirmingOpen) {
            Button("Cancel", role: .cancel) {
                pendingURL = nil
            }
            Button("Open") {
                if let pendingURL {
                    openURL(pendingURL)
                }
                pendingURL = nil
            }
        } message: {
            Text(openConfirmationMessage)
        }
    }

    private var metadata: String {
        var parts = [attachment.fileType.displayName]
        if let fileSize = attachment.fileSize, fileSize >= 0 {
            parts.append(fileSize.formatted(.byteCount(style: .file)))
        }
        if let width = attachment.width,
           let height = attachment.height,
           width > 0,
           height > 0 {
            parts.append("\(width) by \(height)")
        }
        return parts.joined(separator: ", ")
    }

    private var openConfirmationMessage: String {
        let host = pendingURL?.host ?? "the attachment host"
        return "This opens content from \(host) outside WootDesk. Your Chatwoot access token is not included."
    }

    private var iconName: String {
        switch attachment.fileType {
        case .image: "photo"
        case .audio: "waveform"
        case .video: "video"
        case .location: "location"
        case .contact: "person.crop.circle"
        case .file, .fallback, .unknown: "doc"
        }
    }
}

#Preview("Attachment") {
    ConversationAttachmentView(
        attachment: ConversationAttachment(
            id: "sample-attachment",
            serverID: 90,
            fileType: .image,
            dataURL: URL(string: "https://files.example.invalid/sample-diagram.png"),
            fileSize: 82_410,
            width: 1_200,
            height: 800,
            fileExtension: "png"
        )
    )
    .padding()
    .frame(width: 420)
}
