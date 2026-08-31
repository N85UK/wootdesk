import Foundation

/// Invented sample data for SwiftUI previews and tests.
///
/// Every value here is fictional. No real Chatwoot server, customer, or
/// message content is represented.
public enum PreviewData {

    public static let singleAccount = ChatwootAccount(
        id: 1,
        name: "Sample Support Desk",
        role: "administrator",
        status: "active",
        availability: .online,
        availabilityStatus: .online,
        autoOffline: true
    )

    public static let multipleAccounts: [ChatwootAccount] = [
        ChatwootAccount(id: 1, name: "Sample Support Desk", role: "administrator", status: "active"),
        ChatwootAccount(id: 2, name: "Sample Sales Team", role: "agent", status: "active"),
        ChatwootAccount(id: 3, name: "Sample Beta Programme", role: "agent", status: "active")
    ]

    public static let profile = ServerProfile(
        id: UUID(uuidString: "0F5C7A26-9C36-4E3B-95A2-2A6C1D3F4B10")!,
        displayName: "Sample Support Desk",
        baseURL: URL(string: "https://chatwoot.example.com")!,
        selectedAccountID: 1,
        selectedAccountName: "Sample Support Desk"
    )

    public static let conversations: [Conversation] = [
        Conversation(
            id: 1041,
            accountID: 1,
            inboxID: 3,
            status: .open,
            priority: .urgent,
            contact: Contact(id: 501, name: "Ada Sample", email: "ada@example.invalid"),
            inboxName: "Website Live Chat",
            lastActivityAt: Date().addingTimeInterval(-60 * 4),
            unreadCount: 3,
            lastMessagePreview: "The export still times out when I select the full date range.",
            channel: "Channel::WebWidget",
            createdAt: Date().addingTimeInterval(-60 * 60 * 6)
        ),
        Conversation(
            id: 1038,
            accountID: 1,
            inboxID: 2,
            status: .open,
            priority: .medium,
            contact: Contact(id: 502, name: "Bruno Example", email: "bruno@example.invalid"),
            inboxName: "Support Inbox",
            lastActivityAt: Date().addingTimeInterval(-60 * 52),
            unreadCount: 1,
            lastMessagePreview: "Thanks, that worked. One more question about billing dates.",
            channel: "Channel::Email",
            createdAt: Date().addingTimeInterval(-60 * 60 * 26)
        ),
        Conversation(
            id: 1024,
            accountID: 1,
            inboxID: 2,
            status: .pending,
            priority: nil,
            contact: Contact(id: 503, name: "Chidi Placeholder"),
            inboxName: "Support Inbox",
            lastActivityAt: Date().addingTimeInterval(-60 * 60 * 5),
            unreadCount: 0,
            lastMessagePreview: "Waiting on the engineering team to confirm the fix window.",
            channel: "Channel::Email",
            createdAt: Date().addingTimeInterval(-60 * 60 * 72)
        ),
        Conversation(
            id: 1011,
            accountID: 1,
            inboxID: 4,
            status: .resolved,
            priority: .low,
            contact: Contact(id: 504, name: "Dara Fictional", email: "dara@example.invalid"),
            inboxName: "Onboarding",
            lastActivityAt: Date().addingTimeInterval(-60 * 60 * 30),
            unreadCount: 0,
            lastMessagePreview: "Perfect, the team is all set up now. Closing this off.",
            channel: "Channel::Api",
            createdAt: Date().addingTimeInterval(-60 * 60 * 120)
        )
    ]

    public static let messages: [ConversationMessage] = [
        ConversationMessage(
            id: 8_001,
            content: "Hello, the sample export stops before it finishes.",
            kind: .incoming,
            createdAt: Date(timeIntervalSince1970: 1_735_736_100),
            senderName: "Ada Sample",
            senderType: "Contact",
            deliveryStatus: "sent",
            contentType: "text"
        ),
        ConversationMessage(
            id: 8_002,
            content: "Thanks for the clear report. I am checking the export job now.",
            kind: .outgoing,
            createdAt: Date(timeIntervalSince1970: 1_735_736_280),
            senderName: "Sample Agent",
            senderType: "User",
            deliveryStatus: "sent",
            contentType: "text"
        ),
        ConversationMessage(
            id: 8_003,
            content: "Internal check: compare the worker timeout with the sample job size.",
            kind: .outgoing,
            isPrivate: true,
            createdAt: Date(timeIntervalSince1970: 1_735_736_340),
            senderName: "Sample Agent",
            senderType: "User",
            deliveryStatus: "sent",
            contentType: "text"
        ),
        ConversationMessage(
            id: 8_004,
            content: "The export still times out when I select the **full date range**.",
            kind: .incoming,
            createdAt: Date(timeIntervalSince1970: 1_735_736_520),
            senderName: "Ada Sample",
            senderType: "Contact",
            deliveryStatus: "sent",
            contentType: "text",
            attachments: [
                ConversationAttachment(
                    id: "preview-attachment-1",
                    serverID: 91,
                    fileType: .image,
                    dataURL: URL(string: "https://files.example.invalid/sample-export.png"),
                    thumbnailURL: URL(string: "https://files.example.invalid/sample-export-thumbnail.png"),
                    fileSize: 82_410,
                    width: 1_200,
                    height: 800,
                    fileExtension: "png"
                )
            ]
        )
    ]
}
