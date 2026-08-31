import Foundation
import Testing
@testable import WootDesk

@Suite("Agent Availability State Tests")
struct AgentAvailabilityStateTests {
    @Test("Loads availability for the selected account")
    @MainActor
    func testLoadsSelectedAccountAvailability() async {
        let profile = PreviewData.profile
        let state = AgentAvailabilityState(apiClient: StubChatwootAPI())

        await state.load(profile: profile, token: "test-token")

        #expect(state.availability == .online)
        #expect(state.errorMessage == nil)
        #expect(state.isLoading == false)
    }

    @Test("Changes local availability only after a successful server update")
    @MainActor
    func testSuccessfulUpdateChangesAvailability() async {
        let profile = PreviewData.profile
        let state = AgentAvailabilityState(apiClient: StubChatwootAPI())
        await state.load(profile: profile, token: "test-token")

        await state.update(.busy, profile: profile, token: "test-token")

        #expect(state.availability == .busy)
        #expect(state.errorMessage == nil)
        #expect(state.isUpdating == false)
    }

    @Test("A failed update preserves the last confirmed availability")
    @MainActor
    func testFailedUpdatePreservesAvailability() async {
        let profile = PreviewData.profile
        let api = StubChatwootAPI(availabilityUpdateOutcome: .failure(.unauthorized))
        let state = AgentAvailabilityState(apiClient: api)
        await state.load(profile: profile, token: "test-token")

        await state.update(.offline, profile: profile, token: "test-token")

        #expect(state.availability == .online)
        #expect(state.errorMessage == APIError.unauthorized.errorDescription)
        #expect(state.isUpdating == false)
    }

    @Test("Missing status remains selectable and reports compatibility context")
    @MainActor
    func testMissingStatusRemainsSelectable() async {
        let profile = PreviewData.profile
        let account = ChatwootAccount(id: profile.selectedAccountID, name: "Invented Support")
        let api = StubChatwootAPI(
            profileOutcome: .success(.init(name: "Sample Agent", accounts: [account]))
        )
        let state = AgentAvailabilityState(apiClient: api)

        await state.load(profile: profile, token: "test-token")
        #expect(state.availability == nil)
        #expect(state.errorMessage?.contains("did not report") == true)

        await state.update(.offline, profile: profile, token: "test-token")
        #expect(state.availability == .offline)
        #expect(state.errorMessage == nil)
    }

    @Test("Clearing the active profile removes server-specific status")
    @MainActor
    func testClearRemovesStatus() async {
        let profile = PreviewData.profile
        let state = AgentAvailabilityState(apiClient: StubChatwootAPI())
        await state.load(profile: profile, token: "test-token")

        state.clear()

        #expect(state.availability == nil)
        #expect(state.errorMessage == nil)
        #expect(state.isLoading == false)
        #expect(state.isUpdating == false)
    }

    @Test("Switching profiles clears the prior status while the next profile loads")
    @MainActor
    func testSwitchingProfilesClearsPriorStatus() async {
        let firstProfile = makeProfile(
            host: "first.example.com",
            accountID: 11,
            accountName: "First Support"
        )
        let secondProfile = makeProfile(
            host: "second.example.com",
            accountID: 22,
            accountName: "Second Support"
        )
        let api = AvailabilityProfileTestAPI(responses: [
            firstProfile.baseURL: .init(
                account: ChatwootAccount(
                    id: firstProfile.selectedAccountID,
                    name: firstProfile.selectedAccountName,
                    availabilityStatus: .online
                )
            ),
            secondProfile.baseURL: .init(
                account: ChatwootAccount(
                    id: secondProfile.selectedAccountID,
                    name: secondProfile.selectedAccountName,
                    availabilityStatus: .busy
                ),
                delay: .milliseconds(100)
            )
        ])
        let state = AgentAvailabilityState(apiClient: api)
        await state.load(profile: firstProfile, token: "test-token")
        #expect(state.availability == .online)

        let secondLoad = Task { @MainActor in
            await state.load(profile: secondProfile, token: "test-token")
        }
        await waitForLoadingState(state)

        #expect(state.isLoading)
        #expect(state.availability == nil)

        await secondLoad.value
        #expect(state.availability == .busy)
        #expect(state.errorMessage == nil)
    }

    @Test("A slow response from a prior profile cannot replace the active status")
    @MainActor
    func testSlowPriorProfileCannotReplaceActiveStatus() async {
        let firstProfile = makeProfile(
            host: "slow.example.com",
            accountID: 31,
            accountName: "Slow Support"
        )
        let secondProfile = makeProfile(
            host: "active.example.com",
            accountID: 42,
            accountName: "Active Support"
        )
        let api = AvailabilityProfileTestAPI(responses: [
            firstProfile.baseURL: .init(
                account: ChatwootAccount(
                    id: firstProfile.selectedAccountID,
                    name: firstProfile.selectedAccountName,
                    availabilityStatus: .online
                ),
                delay: .milliseconds(100)
            ),
            secondProfile.baseURL: .init(
                account: ChatwootAccount(
                    id: secondProfile.selectedAccountID,
                    name: secondProfile.selectedAccountName,
                    availabilityStatus: .offline
                )
            )
        ])
        let state = AgentAvailabilityState(apiClient: api)

        let slowLoad = Task { @MainActor in
            await state.load(profile: firstProfile, token: "test-token")
        }
        await waitForLoadingState(state)
        await state.load(profile: secondProfile, token: "test-token")
        await slowLoad.value

        #expect(state.availability == .offline)
        #expect(state.errorMessage == nil)
        #expect(state.isLoading == false)
    }

    @Test("Changing availability, switching profiles, and relaunching restores only the active profile")
    @MainActor
    func testRelaunchRestoresSelectedProfileAvailability() async throws {
        let firstProfile = makeProfile(
            host: "first-relaunch.example.com",
            accountID: 51,
            accountName: "First Relaunch Support"
        )
        let secondProfile = makeProfile(
            host: "second-relaunch.example.com",
            accountID: 62,
            accountName: "Second Relaunch Support"
        )
        let api = AvailabilityProfileTestAPI(responses: [
            firstProfile.baseURL: .init(
                account: ChatwootAccount(
                    id: firstProfile.selectedAccountID,
                    name: firstProfile.selectedAccountName,
                    availabilityStatus: .online
                )
            ),
            secondProfile.baseURL: .init(
                account: ChatwootAccount(
                    id: secondProfile.selectedAccountID,
                    name: secondProfile.selectedAccountName,
                    availabilityStatus: .offline
                ),
                delay: .milliseconds(100)
            )
        ])
        let environment = AppEnvironment.preview(
            profiles: [firstProfile, secondProfile],
            activeProfileID: firstProfile.id,
            tokens: [
                firstProfile.id: "test-token",
                secondProfile.id: "test-token"
            ],
            apiClient: api
        )
        let firstSession = AppModel(environment: environment)
        let firstSessionAvailability = AgentAvailabilityState(apiClient: api)

        await firstSession.initialize()
        await firstSessionAvailability.load(
            profile: firstSession.activeProfile,
            token: firstSession.activeToken
        )
        #expect(firstSession.activeProfile?.id == firstProfile.id)
        #expect(firstSessionAvailability.availability == .online)

        await firstSessionAvailability.update(
            .busy,
            profile: firstSession.activeProfile,
            token: firstSession.activeToken
        )
        #expect(firstSessionAvailability.availability == .busy)
        #expect(firstSessionAvailability.errorMessage == nil)

        await firstSession.selectProfile(secondProfile)
        let secondLoad = Task { @MainActor in
            await firstSessionAvailability.load(
                profile: firstSession.activeProfile,
                token: firstSession.activeToken
            )
        }
        await waitForLoadingState(firstSessionAvailability)

        #expect(firstSession.activeProfile?.id == secondProfile.id)
        #expect(firstSessionAvailability.isLoading)
        #expect(firstSessionAvailability.availability == nil)

        await secondLoad.value
        #expect(firstSessionAvailability.availability == .offline)
        #expect(try await environment.profileRepository.loadActiveProfileID() == secondProfile.id)

        let relaunchedSession = AppModel(environment: environment)
        let relaunchedAvailability = AgentAvailabilityState(apiClient: api)
        await relaunchedSession.initialize()
        await relaunchedAvailability.load(
            profile: relaunchedSession.activeProfile,
            token: relaunchedSession.activeToken
        )

        #expect(relaunchedSession.activeProfile?.id == secondProfile.id)
        #expect(relaunchedSession.activeToken == "test-token")
        #expect(relaunchedAvailability.availability == .offline)
        #expect(relaunchedAvailability.errorMessage == nil)
    }

    @MainActor
    private func waitForLoadingState(_ state: AgentAvailabilityState) async {
        for _ in 0..<100 where !state.isLoading {
            await Task.yield()
        }
    }

    private func makeProfile(
        host: String,
        accountID: Int,
        accountName: String
    ) -> ServerProfile {
        ServerProfile(
            displayName: accountName,
            baseURL: URL(string: "https://\(host)")!,
            selectedAccountID: accountID,
            selectedAccountName: accountName
        )
    }
}

private actor AvailabilityProfileTestAPI: ChatwootAPIProtocol {
    struct Response: Sendable {
        var account: ChatwootAccount
        let delay: Duration

        init(account: ChatwootAccount, delay: Duration = .zero) {
            self.account = account
            self.delay = delay
        }
    }

    private var responses: [URL: Response]

    init(responses: [URL: Response]) {
        self.responses = responses
    }

    func fetchProfile(
        baseURL: URL,
        token: String
    ) async throws -> (profileName: String, accounts: [ChatwootAccount]) {
        guard let response = responses[baseURL] else {
            throw APIError.notFound
        }
        if response.delay > .zero {
            try await Task.sleep(for: response.delay)
        }
        return ("Invented Agent", [response.account])
    }

    func updateAvailability(
        baseURL: URL,
        token: String,
        accountID: Int,
        availability: AgentAvailability
    ) async throws {
        guard var response = responses[baseURL], response.account.id == accountID else {
            throw APIError.notFound
        }
        let account = response.account
        response.account = ChatwootAccount(
            id: account.id,
            name: account.name,
            role: account.role,
            status: account.status,
            availability: account.availability,
            availabilityStatus: availability,
            autoOffline: account.autoOffline
        )
        responses[baseURL] = response
    }

    func fetchConversations(
        baseURL: URL,
        token: String,
        accountID: Int,
        status: ConversationStatus?,
        page: Int
    ) async throws -> [Conversation] {
        throw APIError.notFound
    }

    func fetchMessages(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        beforeMessageID: Int?
    ) async throws -> ConversationMessagePage {
        throw APIError.notFound
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
}
