import Testing
import Foundation
@testable import WootDesk

@Suite("Conversation List State Tests")
struct ConversationListStateTests {

    private func makeProfile(
        name: String = "Server A",
        host: String = "a.example.com",
        accountID: Int = 1
    ) -> ServerProfile {
        ServerProfile(
            displayName: name,
            baseURL: URL(string: "https://\(host)")!,
            selectedAccountID: accountID,
            selectedAccountName: "Account \(accountID)"
        )
    }

    private func conversation(id: Int, status: ConversationStatus = .open) -> Conversation {
        Conversation(
            id: id,
            accountID: 1,
            inboxID: 1,
            status: status,
            lastActivityAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("Loads the first page of conversations into the list")
    @MainActor
    func testLoadsFirstPage() async {
        let state = ConversationListState()
        let client = StubChatwootAPI(
            conversationsOutcome: .success([conversation(id: 1), conversation(id: 2)])
        )

        await state.loadConversations(profile: makeProfile(), token: "token", using: client)

        #expect(state.conversations.count == 2)
        #expect(state.errorMessage == nil)
        #expect(state.isLoading == false)
    }

    @Test("Surfaces an API failure as an error message and empties the list")
    @MainActor
    func testLoadFailureSurfacesError() async {
        let state = ConversationListState()
        state.conversations = [conversation(id: 99)]
        let client = StubChatwootAPI(conversationsOutcome: .failure(.unauthorized))

        await state.loadConversations(profile: makeProfile(), token: "token", using: client)

        #expect(state.conversations.isEmpty)
        #expect(state.errorMessage == APIError.unauthorized.errorDescription)
        #expect(state.hasMorePages == false)
    }

    @Test("Switching server profiles clears conversations before loading the new server")
    @MainActor
    func testSwitchingProfilesClearsPriorState() async {
        let state = ConversationListState()
        let serverA = makeProfile(name: "Server A", host: "a.example.com", accountID: 1)
        let clientA = StubChatwootAPI(conversationsOutcome: .success([conversation(id: 11)]))

        await state.loadConversations(profile: serverA, token: "token-a", using: clientA)
        state.selectedConversationID = 11
        #expect(state.conversations.map(\.id) == [11])

        // Switching profiles clears first, exactly as the view's task does, so that
        // one server's data is never displayed under another.
        state.clear()
        #expect(state.conversations.isEmpty)
        #expect(state.selectedConversationID == nil)

        let serverB = makeProfile(name: "Server B", host: "b.example.com", accountID: 7)
        let clientB = StubChatwootAPI(conversationsOutcome: .success([conversation(id: 22)]))
        await state.loadConversations(profile: serverB, token: "token-b", using: clientB)

        #expect(state.conversations.map(\.id) == [22])
    }

    @Test("Requesting a further page stops cleanly when the server returns nothing")
    @MainActor
    func testPagingTerminatesOnEmptyPage() async {
        let state = ConversationListState()
        // The stub serves data on page 1 only, so page 2 comes back empty.
        let client = StubChatwootAPI(
            conversationsOutcome: .success([conversation(id: 1), conversation(id: 2)])
        )
        let profile = makeProfile()

        await state.loadConversations(profile: profile, token: "token", using: client)
        #expect(state.hasMorePages == true)

        await state.loadNextPage(profile: profile, token: "token", using: client)

        #expect(state.conversations.count == 2)
        #expect(state.hasMorePages == false)
        #expect(state.currentPage == 2)
        #expect(state.isLoadingNextPage == false)
    }

    @Test("A failed page keeps the conversations already loaded")
    @MainActor
    func testFailedPageKeepsExistingResults() async {
        let state = ConversationListState()
        let profile = makeProfile()
        let firstPageClient = StubChatwootAPI(conversationsOutcome: .success([conversation(id: 1)]))
        await state.loadConversations(profile: profile, token: "token", using: firstPageClient)

        let client = StubChatwootAPI(conversationsOutcome: .failure(.rateLimited(retryAfter: 5)))
        await state.loadNextPage(profile: profile, token: "token", using: client)

        #expect(state.conversations.map(\.id) == [1])
        #expect(state.hasMorePages == false)
        #expect(state.errorMessage != nil)
    }

    @Test("A slower prior profile request cannot replace the active profile's conversations")
    @MainActor
    func testStaleProfileResultIsIgnored() async throws {
        let state = ConversationListState()
        let serverA = makeProfile(name: "Server A", host: "a.example.com", accountID: 1)
        let serverB = makeProfile(name: "Server B", host: "b.example.com", accountID: 2)
        let client = DelayedConversationAPI(
            slowHost: "a.example.com",
            slowResult: [conversation(id: 11)],
            fastResult: [conversation(id: 22)]
        )

        let firstLoad = Task {
            await state.loadConversations(profile: serverA, token: "token-a", using: client)
        }
        try await Task.sleep(for: .milliseconds(20))

        state.clear()
        await state.loadConversations(profile: serverB, token: "token-b", using: client)
        await firstLoad.value

        #expect(state.conversations.map(\.id) == [22])
        #expect(state.errorMessage == nil)
    }

    @Test("Status filter is applied to the request")
    @MainActor
    func testStatusFilterIsApplied() async {
        let state = ConversationListState()
        state.statusFilter = .resolved

        let client = StubChatwootAPI(
            conversationsOutcome: .success([
                conversation(id: 1, status: .open),
                conversation(id: 2, status: .resolved)
            ])
        )

        await state.loadConversations(profile: makeProfile(), token: "token", using: client)

        #expect(state.conversations.map(\.id) == [2])
    }

    @Test("Search narrows the list without refetching")
    @MainActor
    func testSearchFiltersLocally() async {
        let state = ConversationListState()
        let client = StubChatwootAPI(conversationsOutcome: .success(PreviewData.conversations))

        await state.loadConversations(profile: makeProfile(), token: "token", using: client)
        state.statusFilter = nil
        await state.loadConversations(profile: makeProfile(), token: "token", using: client)

        state.searchQuery = "Bruno"
        #expect(state.filteredConversations.count == 1)

        state.searchQuery = "   "
        #expect(state.filteredConversations.count == state.conversations.count)
    }
}

private struct DelayedConversationAPI: ChatwootAPIProtocol {
    let slowHost: String
    let slowResult: [Conversation]
    let fastResult: [Conversation]

    func fetchProfile(baseURL: URL, token: String) async throws -> (profileName: String, accounts: [ChatwootAccount]) {
        ("Sample Agent", [ChatwootAccount(id: 1, name: "Sample Account")])
    }

    func fetchConversations(
        baseURL: URL,
        token: String,
        accountID: Int,
        status: ConversationStatus?,
        page: Int
    ) async throws -> [Conversation] {
        if baseURL.host == slowHost {
            try await Task.sleep(for: .milliseconds(100))
            return slowResult
        }
        return fastResult
    }
}
