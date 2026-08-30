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
}
