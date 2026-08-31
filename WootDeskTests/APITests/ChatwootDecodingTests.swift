import Testing
import Foundation
@testable import WootDesk

@Suite("Chatwoot Response Decoding Tests")
struct ChatwootDecodingTests {

    @Test("Decodes profile response with single account")
    func testDecodeProfileSingleAccount() throws {
        let data = try FixtureLoader.loadData(named: "profile_single_account.json")
        let profileDTO = try JSONDecoder().decode(ChatwootProfileDTO.self, from: data)

        #expect(profileDTO.id == 101)
        #expect(profileDTO.name == "Jane Support Lead")
        #expect(profileDTO.email == "jane@example.com")
        #expect(profileDTO.accounts?.count == 1)

        let account = profileDTO.accounts?.first?.toDomain()
        #expect(account?.id == 1)
        #expect(account?.name == "Acme Support Global")
        #expect(account?.role == "administrator")
    }

    @Test("Decodes profile response with multiple accounts")
    func testDecodeProfileMultiAccount() throws {
        let data = try FixtureLoader.loadData(named: "profile_multi_account.json")
        let profileDTO = try JSONDecoder().decode(ChatwootProfileDTO.self, from: data)

        #expect(profileDTO.accounts?.count == 3)
        let domainAccounts = profileDTO.accounts?.map { $0.toDomain() } ?? []
        #expect(domainAccounts.map(\.id) == [1, 2, 3])
        #expect(domainAccounts[1].name == "Acme Americas Tier 2")
    }

    @Test("Decodes wrapped conversation list response")
    func testDecodeConversationsWrapped() throws {
        let data = try FixtureLoader.loadData(named: "conversations_wrapped.json")
        let responseDTO = try JSONDecoder().decode(ChatwootConversationListResponseDTO.self, from: data)

        #expect(responseDTO.conversations.count == 2)

        let conv1 = responseDTO.conversations[0].toDomain(defaultAccountID: 1)
        #expect(conv1.id == 5001)
        #expect(conv1.status == .open)
        #expect(conv1.priority == .urgent)
        #expect(conv1.unreadCount == 2)
        #expect(conv1.contact?.name == "Alice Customer")
        #expect(conv1.lastMessagePreview == "I cannot access the dashboard settings page.")
        #expect(conv1.inboxName == "Web Widget")
    }

    @Test("Decodes flat payload conversation list response")
    func testDecodeConversationsFlat() throws {
        let data = try FixtureLoader.loadData(named: "conversations_flat.json")
        let responseDTO = try JSONDecoder().decode(ChatwootConversationListResponseDTO.self, from: data)

        #expect(responseDTO.conversations.count == 1)

        let conv = responseDTO.conversations[0].toDomain(defaultAccountID: 1)
        #expect(conv.id == 6001)
        #expect(conv.status == .pending)
        #expect(conv.priority == .medium)
        #expect(conv.unreadCount == 1)
        #expect(conv.contact?.name == "Charlie Dev")
    }

    @Test("Decodes conversations with missing optional fields without crashing")
    func testDecodeConversationsMissingFields() throws {
        let data = try FixtureLoader.loadData(named: "conversations_missing_fields.json")
        let responseDTO = try JSONDecoder().decode(ChatwootConversationListResponseDTO.self, from: data)

        #expect(responseDTO.conversations.count == 1)
        let conv = responseDTO.conversations[0].toDomain(defaultAccountID: 99)
        #expect(conv.id == 7001)
        #expect(conv.accountID == 99)
        #expect(conv.status == .open) // Default fallback
        #expect(conv.priority == nil)
        #expect(conv.contact == nil)
        #expect(conv.lastMessagePreview == nil)
        #expect(conv.lastActivityAt == Date(timeIntervalSince1970: 0))
    }

    @Test("Tests DateParser across seconds, milliseconds, and ISO8601 strings")
    func testDateParserTolerantParsing() {
        // Unix seconds
        let dateSec = DateParser.parse(1700000000)
        #expect(dateSec != nil)
        #expect(dateSec?.timeIntervalSince1970 == 1700000000)

        // Unix milliseconds
        let dateMillis = DateParser.parse(1700000000000.0)
        #expect(dateMillis != nil)
        #expect(dateMillis?.timeIntervalSince1970 == 1700000000)

        // ISO8601 string with milliseconds
        let isoStr = "2025-01-15T10:30:00.000Z"
        let dateISO = DateParser.parse(isoStr)
        #expect(dateISO != nil)

        // Nil value
        #expect(DateParser.parse(nil) == nil)
    }

    @Test("Maps message timestamps and private notes into domain values")
    func testDecodeMessages() throws {
        let data = try FixtureLoader.loadData(named: "messages_page.json")
        let response = try JSONDecoder().decode(ChatwootMessageListResponseDTO.self, from: data)
        let messages = try response.messages.map { try $0.toDomain() }

        #expect(messages.count == 3)
        #expect(messages[0].createdAt.timeIntervalSince1970 == 1_735_736_100)
        #expect(messages[0].senderName == "Avery Example")
        #expect(messages[0].kind == .incoming)
        #expect(messages[0].attachmentCount == 1)
        #expect(messages[0].attachments[0].fileType == .image)
        #expect(messages[0].attachments[0].displayName == "sample-export.png")
        #expect(messages[0].attachments[0].fileSize == 82_410)
        #expect(messages[0].attachments[0].width == 1_200)
        #expect(messages[0].attachments[0].dataURL?.scheme == "https")
        #expect(messages[2].isPrivate)
    }

    @Test("Decodes a message with missing optional fields without crashing")
    func testDecodeMessageMissingFields() throws {
        let data = try FixtureLoader.loadData(named: "messages_missing_fields.json")
        let response = try JSONDecoder().decode(ChatwootMessageListResponseDTO.self, from: data)
        let messageDTO = try #require(response.messages.first)
        let message = try messageDTO.toDomain()

        #expect(message.id == 8301)
        #expect(message.kind == .unknown(9))
        #expect(message.createdAt == Date(timeIntervalSince1970: 0))
        #expect(message.attachmentCount == 1)
        #expect(message.displayContent == "File attachment")

        let multipleAttachments = ConversationMessage(
            id: 8302,
            kind: .incoming,
            createdAt: Date(timeIntervalSince1970: 0),
            attachments: [
                ConversationAttachment(id: "one", fileType: .file),
                ConversationAttachment(id: "two", fileType: .image)
            ]
        )
        #expect(multipleAttachments.displayContent == "2 attachments")
    }

    @Test("Rejects unsafe attachment addresses while retaining safe metadata")
    func testUnsafeAttachmentURLIsNotExposed() throws {
        let dto = ChatwootMessageDTO(
            id: 9_001,
            messageType: 0,
            attachments: [
                ChatwootMessageAttachmentDTO(
                    id: 1,
                    fileType: "file",
                    dataURL: "http://files.example.invalid/invented.pdf",
                    fileSize: 400,
                    fileExtension: "pdf"
                )
            ]
        )

        let message = try dto.toDomain()
        #expect(message.attachments[0].dataURL == nil)
        #expect(message.attachments[0].fileSize == 400)
        #expect(message.attachments[0].displayName == "File attachment.pdf")
    }

    @Test("Allows insecure localhost attachment addresses only for debug mapping")
    func testLocalhostAttachmentURLPolicy() throws {
        let dto = ChatwootMessageDTO(
            id: 9_002,
            messageType: 0,
            attachments: [
                ChatwootMessageAttachmentDTO(
                    id: 2,
                    fileType: "image",
                    dataURL: "http://localhost:3000/rails/sample.png"
                )
            ]
        )

        #expect(try dto.toDomain().attachments[0].dataURL == nil)
        #expect(try dto.toDomain(allowsInsecureLocalhost: true).attachments[0].dataURL?.scheme == "http")
    }

    @Test("Converts processed HTML to plain text and disables Markdown links")
    func testSafeMessageFormatting() {
        let html = MessageTextFormatter.plainText(
            from: "<p>Hello &amp; welcome</p><p><strong>Invented</strong> reply</p>"
        )
        #expect(html == "Hello & welcome\nInvented reply")

        let attributed = MessageTextFormatter.attributedText(
            from: "**Important** [outside link](https://example.invalid)"
        )
        #expect(attributed.runs.allSatisfy { $0.link == nil })
    }
}
