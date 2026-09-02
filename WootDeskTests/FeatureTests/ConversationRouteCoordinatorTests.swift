import Foundation
import Testing
@testable import WootDesk

@Suite("Conversation Route Coordinator Tests")
struct ConversationRouteCoordinatorTests {
    private static let firstProfileID = UUID(uuidString: "0F5C7A26-9C36-4E3B-95A2-2A6C1D3F4B10")!
    private static let secondProfileID = UUID(uuidString: "1A2B3C4D-5E6F-4A7B-8C9D-0E1F2A3B4C5D")!

    private func profile(id: UUID, accountID: Int, name: String) -> ServerProfile {
        ServerProfile(
            id: id,
            displayName: name,
            baseURL: URL(string: "https://\(accountID).example.com")!,
            selectedAccountID: accountID,
            selectedAccountName: "Account \(accountID)"
        )
    }

    private func conversation(id: Int, accountID: Int = 1, status: ConversationStatus = .open) -> Conversation {
        Conversation(
            id: id,
            accountID: accountID,
            inboxID: 1,
            status: status,
            contact: Contact(id: id, name: "Contact \(id)"),
            lastActivityAt: Date(timeIntervalSince1970: 1_735_737_000)
        )
    }

    /// Builds an app model whose saved profiles and credentials are already
    /// restored, matching the state a notification arrives into.
    @MainActor
    private func makeAppModel(
        profiles: [ServerProfile],
        activeProfileID: UUID?,
        api: ChatwootAPIProtocol
    ) async -> AppModel {
        let environment = AppEnvironment.preview(
            profiles: profiles,
            activeProfileID: activeProfileID,
            tokens: Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, "token-\($0.id)") }),
            apiClient: api
        )
        let appModel = AppModel(environment: environment)
        await appModel.initialize()
        return appModel
    }

    // MARK: - AC1 Open a conversation outside the loaded page

    @Test("A conversation outside the loaded page is fetched directly and displayed")
    @MainActor
    func testOpensConversationOutsideLoadedPage() async {
        let listed = [conversation(id: 1_001), conversation(id: 1_002)]
        let routed = conversation(id: 9_500)
        let api = RouteTestAPI(listed: listed, fetchable: [9_500: routed])
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let appModel = await makeAppModel(
            profiles: [saved],
            activeProfileID: saved.id,
            api: api
        )
        let listState = ConversationListState()
        let coordinator = ConversationRouteCoordinator()

        let opened = await coordinator.open(
            route: route(profileID: saved.id, accountID: 1, conversationID: 9_500),
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(opened)
        #expect(listState.selectedConversationID == 9_500)
        #expect(listState.conversations.contains { $0.id == 9_500 })
        #expect(coordinator.errorMessage == nil)
        await #expect(api.recorder.directFetches() == [9_500])
    }

    @Test("A conversation already in the loaded page is selected without a direct fetch")
    @MainActor
    func testSelectsListedConversation() async {
        let listed = [conversation(id: 1_001), conversation(id: 1_002)]
        let api = RouteTestAPI(listed: listed)
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let listState = ConversationListState()
        let coordinator = ConversationRouteCoordinator()

        let opened = await coordinator.open(
            route: route(profileID: saved.id, accountID: 1, conversationID: 1_002),
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(opened)
        #expect(listState.selectedConversationID == 1_002)
        await #expect(api.recorder.directFetches().isEmpty)
    }

    // MARK: - AC2 Open a filtered conversation

    @Test("A conversation hidden by a search term and status filter is still displayed")
    @MainActor
    func testOpensConversationHiddenByFilters() async {
        let listed = [conversation(id: 1_001, status: .open)]
        let routed = conversation(id: 2_002, status: .resolved)
        let api = RouteTestAPI(listed: listed, fetchable: [2_002: routed])
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let listState = ConversationListState()
        listState.searchQuery = "an unrelated search term"
        listState.statusFilter = .pending
        let coordinator = ConversationRouteCoordinator()

        let opened = await coordinator.open(
            route: route(profileID: saved.id, accountID: 1, conversationID: 2_002),
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(opened)
        #expect(listState.searchQuery.isEmpty)
        #expect(listState.statusFilter == nil)
        // The conversation is visible through the filter the agent can see.
        #expect(listState.filteredConversations.contains { $0.id == 2_002 })
        #expect(listState.selectedConversationID == 2_002)
    }

    // MARK: - AC3 Switch to the notified profile safely

    @Test("Data from the previous profile is cleared before the notified profile is displayed")
    @MainActor
    func testClearsPreviousProfileData() async {
        let first = profile(id: Self.firstProfileID, accountID: 1, name: "First Server")
        let second = profile(id: Self.secondProfileID, accountID: 2, name: "Second Server")
        let routed = conversation(id: 3_003, accountID: 2)
        let api = RouteTestAPI(listed: [], fetchable: [3_003: routed])
        let appModel = await makeAppModel(
            profiles: [first, second],
            activeProfileID: first.id,
            api: api
        )

        let listState = ConversationListState()
        let detailState = ConversationDetailState()
        let triageState = ConversationTriageState()
        // Screen data belonging to the first profile.
        listState.adoptRoutedConversation(conversation(id: 1_001, accountID: 1))
        triageState.adopt(conversation(id: 1_001, accountID: 1), profile: first)
        #expect(triageState.conversation != nil)

        let coordinator = ConversationRouteCoordinator()
        let opened = await coordinator.open(
            route: route(profileID: second.id, accountID: 2, conversationID: 3_003),
            appModel: appModel,
            listState: listState,
            detailState: detailState,
            triageState: triageState,
            using: api
        )

        #expect(opened)
        #expect(appModel.activeProfile?.id == second.id)
        // No conversation from the first profile survives the switch.
        #expect(!listState.conversations.contains { $0.accountID == 1 })
        #expect(listState.conversations.map(\.id) == [3_003])
        #expect(triageState.conversation == nil)
    }

    @Test("A notification for an unknown profile is refused without changing the active profile")
    @MainActor
    func testRefusesUnknownProfile() async {
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let api = RouteTestAPI(listed: [conversation(id: 1_001)])
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let listState = ConversationListState()
        let coordinator = ConversationRouteCoordinator()

        let opened = await coordinator.open(
            route: route(profileID: Self.secondProfileID, accountID: 9, conversationID: 4_004),
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(!opened)
        #expect(appModel.activeProfile?.id == saved.id)
        #expect(listState.selectedConversationID == nil)
        #expect(coordinator.errorMessage != nil)
    }

    @Test("A notification whose account does not match the saved profile is refused")
    @MainActor
    func testRefusesAccountMismatch() async {
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let api = RouteTestAPI(listed: [], fetchable: [5_005: conversation(id: 5_005)])
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let listState = ConversationListState()
        let coordinator = ConversationRouteCoordinator()

        let opened = await coordinator.open(
            route: route(profileID: saved.id, accountID: 99, conversationID: 5_005),
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(!opened)
        #expect(listState.selectedConversationID == nil)
        await #expect(api.recorder.directFetches().isEmpty)
    }

    // MARK: - AC4 Handle an unavailable conversation

    @Test(
        "An unavailable conversation is explained and no other conversation is substituted",
        arguments: [APIError.notFound, APIError.forbidden, APIError.offline, APIError.timedOut]
    )
    @MainActor
    func testUnavailableConversation(error: APIError) async {
        let listed = [conversation(id: 1_001), conversation(id: 1_002)]
        let api = RouteTestAPI(listed: listed, fetchFailure: error)
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let listState = ConversationListState()
        let coordinator = ConversationRouteCoordinator()

        let opened = await coordinator.open(
            route: route(profileID: saved.id, accountID: 1, conversationID: 7_007),
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(!opened)
        // No substitute conversation is selected.
        #expect(listState.selectedConversationID == nil)
        #expect(!listState.conversations.contains { $0.id == 7_007 })
        let message = coordinator.errorMessage
        #expect(message?.contains("conversation #7007") == true)
    }

    @Test("A deleted conversation is explained in terms the agent can act on")
    @MainActor
    func testDeletedConversationMessage() async {
        let api = RouteTestAPI(listed: [], fetchFailure: .notFound)
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let coordinator = ConversationRouteCoordinator()

        _ = await coordinator.open(
            route: route(profileID: saved.id, accountID: 1, conversationID: 8_008),
            appModel: appModel,
            listState: ConversationListState(),
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(coordinator.errorMessage?.contains("deleted") == true)
    }

    @Test("A conversation reachable directly is shown even when the page load failed")
    @MainActor
    func testDirectFetchSucceedsAfterFailedPageLoad() async {
        let routed = conversation(id: 6_006)
        let api = RouteTestAPI(
            listed: [],
            fetchable: [6_006: routed],
            listFailure: .serverError(statusCode: 500, message: nil)
        )
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let listState = ConversationListState()
        let coordinator = ConversationRouteCoordinator()

        let opened = await coordinator.open(
            route: route(profileID: saved.id, accountID: 1, conversationID: 6_006),
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )

        #expect(opened)
        #expect(listState.selectedConversationID == 6_006)
        #expect(listState.errorMessage == nil)
    }

    // MARK: - AC5 Handle repeated notification actions

    @Test("Opening the same notification twice while one is in progress yields one result")
    @MainActor
    func testRepeatedActivationIsIgnoredWhileOpening() async {
        let gate = RouteGate()
        let routed = conversation(id: 9_500)
        let api = RouteTestAPI(listed: [], fetchable: [9_500: routed], gate: gate)
        let saved = profile(id: Self.firstProfileID, accountID: 1, name: "Sample Server")
        let appModel = await makeAppModel(profiles: [saved], activeProfileID: saved.id, api: api)
        let listState = ConversationListState()
        let coordinator = ConversationRouteCoordinator()
        let notificationRoute = route(profileID: saved.id, accountID: 1, conversationID: 9_500)

        async let first = coordinator.open(
            route: notificationRoute,
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )
        await gate.waitUntilEntered()
        #expect(coordinator.isOpening)

        let second = await coordinator.open(
            route: notificationRoute,
            appModel: appModel,
            listState: listState,
            detailState: ConversationDetailState(),
            triageState: ConversationTriageState(),
            using: api
        )
        await gate.open()
        let firstResult = await first

        #expect(firstResult)
        #expect(!second, "The repeat activation must not start a second navigation")
        #expect(listState.selectedConversationID == 9_500)
        await #expect(api.recorder.directFetches() == [9_500])
        #expect(!coordinator.isOpening)
    }

    private func route(profileID: UUID, accountID: Int, conversationID: Int) -> PushNotificationRoute {
        // Built through the real payload initialiser so tests exercise the same
        // parsing the notification path uses.
        PushNotificationRoute(userInfo: [
            "profile_id": profileID.uuidString,
            "account_id": accountID,
            "conversation_id": conversationID
        ])!
    }
}

// MARK: - Test Support

private actor RouteAPICallRecorder {
    private var fetched: [Int] = []

    func recordFetch(_ conversationID: Int) { fetched.append(conversationID) }
    func directFetches() -> [Int] { fetched }
}

private actor RouteGate {
    private var isOpen = false
    private var hasEntered = false

    func enter() async {
        hasEntered = true
        while !isOpen {
            await Task.yield()
        }
    }

    func open() { isOpen = true }

    func waitUntilEntered() async {
        while !hasEntered {
            await Task.yield()
        }
    }
}

private struct RouteTestAPI: ChatwootAPIProtocol {
    let listed: [Conversation]
    let fetchable: [Int: Conversation]
    let listFailure: APIError?
    let fetchFailure: APIError?
    let recorder: RouteAPICallRecorder
    let gate: RouteGate?

    init(
        listed: [Conversation],
        fetchable: [Int: Conversation] = [:],
        listFailure: APIError? = nil,
        fetchFailure: APIError? = nil,
        recorder: RouteAPICallRecorder = RouteAPICallRecorder(),
        gate: RouteGate? = nil
    ) {
        self.listed = listed
        self.fetchable = fetchable
        self.listFailure = listFailure
        self.fetchFailure = fetchFailure
        self.recorder = recorder
        self.gate = gate
    }

    func fetchProfile(baseURL: URL, token: String) async throws -> (profileName: String, agentID: Int?, accounts: [ChatwootAccount]) {
        (profileName: "Sample Agent", agentID: nil, accounts: [ChatwootAccount(id: 1, name: "Sample Account")])
    }

    func updateAvailability(
        baseURL: URL,
        token: String,
        accountID: Int,
        availability: AgentAvailability
    ) async throws {
        throw APIError.notFound
    }

    func fetchConversations(
        baseURL: URL,
        token: String,
        accountID: Int,
        status: ConversationStatus?,
        page: Int
    ) async throws -> [Conversation] {
        if let listFailure { throw listFailure }
        return page <= 1 ? listed : []
    }

    func fetchMessages(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        beforeMessageID: Int?
    ) async throws -> ConversationMessagePage {
        ConversationMessagePage(messages: [], hasOlderMessages: false)
    }

    func createMessage(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        content: String,
        isPrivate: Bool,
        attachments: [OutgoingMessageAttachment]
    ) async throws -> ConversationMessage {
        throw APIError.notFound
    }

    func fetchConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> Conversation {
        await gate?.enter()
        await recorder.recordFetch(conversationID)
        if let fetchFailure { throw fetchFailure }
        guard let conversation = fetchable[conversationID] else {
            throw APIError.notFound
        }
        return conversation
    }
}
