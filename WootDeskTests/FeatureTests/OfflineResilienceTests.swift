import Foundation
import Testing
@testable import WootDesk

/// Covers N85-16: continuing conversation work through network interruptions.
///
/// Every test uses invented records and an in-memory store, so nothing here
/// touches a real server, the Keychain or Application Support.
@Suite("Offline Resilience Tests")
struct OfflineResilienceTests {
    // MARK: - Fixtures

    private func profile(id: UUID, accountID: Int = 1) -> ServerProfile {
        ServerProfile(
            id: id,
            displayName: "Invented Server",
            baseURL: URL(string: "https://messages.invented.example")!,
            selectedAccountID: accountID,
            selectedAccountName: "Invented Account"
        )
    }

    private func conversation(id: Int, accountID: Int = 1) -> Conversation {
        Conversation(
            id: id,
            accountID: accountID,
            inboxID: 1,
            status: .open,
            lastActivityAt: Date(timeIntervalSince1970: 1_735_737_000)
        )
    }

    private func message(id: Int) -> ConversationMessage {
        ConversationMessage(
            id: id,
            content: "Invented message \(id)",
            kind: .incoming,
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_735_736_000 + id))
        )
    }

    private func enabledStore(
        _ backing: InMemoryOfflineStore = InMemoryOfflineStore()
    ) -> ToggleableOfflineStore {
        ToggleableOfflineStore(
            backing: backing,
            preference: InMemoryOfflineStoragePreference(enabled: true)
        )
    }

    // MARK: - AC1: Preserve a draft

    @Test("A draft written in one profile returns to that profile after a restart")
    @MainActor
    func testDraftSurvivesRelaunch() async throws {
        let backing = InMemoryOfflineStore()
        let store = enabledStore(backing)
        let profileID = UUID()
        let api = OfflineTestAPI(pages: [77: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)])

        let first = ConversationDetailState(offlineStore: store)
        await first.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        first.draft = "An unsent reply"
        first.composerMode = .privateNote
        await first.persistDraftNow()

        // A fresh state stands in for the app being closed and reopened.
        let second = ConversationDetailState(offlineStore: store)
        await second.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )

        #expect(second.draft == "An unsent reply")
        #expect(second.composerMode == .privateNote)
    }

    @Test("A draft is not visible from a different server profile")
    @MainActor
    func testDraftIsIsolatedBetweenProfiles() async throws {
        let store = enabledStore()
        let api = OfflineTestAPI(pages: [77: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)])
        let firstProfileID = UUID()
        let secondProfileID = UUID()

        let writer = ConversationDetailState(offlineStore: store)
        await writer.loadMessages(
            profile: profile(id: firstProfileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        writer.draft = "Only for the first profile"
        await writer.persistDraftNow()

        let reader = ConversationDetailState(offlineStore: store)
        await reader.loadMessages(
            profile: profile(id: secondProfileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )

        #expect(reader.draft.isEmpty)
    }

    @Test("Clearing a draft removes it from the device")
    @MainActor
    func testEmptiedDraftIsDeleted() async throws {
        let backing = InMemoryOfflineStore()
        let store = enabledStore(backing)
        let profileID = UUID()
        let api = OfflineTestAPI(pages: [77: ConversationMessagePage(messages: [], hasOlderMessages: false)])

        let state = ConversationDetailState(offlineStore: store)
        await state.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        state.draft = "Briefly written"
        await state.persistDraftNow()
        state.draft = "   "
        await state.persistDraftNow()

        let scope = ConversationScope(profileID: profileID, accountID: 1, conversationID: 77)
        let record = try await backing.loadRecord(for: scope)
        #expect(record.draft == nil)
        #expect(await backing.recordCount() == 0)
    }

    // MARK: - AC2: Read protected cached content

    @Test("Cached messages stay on screen when a refresh fails, marked as saved")
    @MainActor
    func testCachedContentIsShownAndLabelled() async throws {
        let store = enabledStore()
        let profileID = UUID()
        let page = ConversationMessagePage(messages: [message(id: 1), message(id: 2)], hasOlderMessages: false)
        let api = OfflineTestAPI(pages: [77: page])

        let online = ConversationDetailState(offlineStore: store)
        await online.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        #expect(online.messages.count == 2)
        #expect(online.isShowingCachedContent == false)

        // The same conversation, now with the connection gone.
        let offlineAPI = OfflineTestAPI(pages: [:], fetchError: .offline)
        let offline = ConversationDetailState(offlineStore: store)
        await offline.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: offlineAPI
        )

        #expect(offline.messages.count == 2)
        #expect(offline.isShowingCachedContent)
        #expect(offline.cachedAt != nil)
        #expect(offline.errorMessage?.contains("may be out of date") == true)
    }

    @Test("Cached content is not readable from another profile")
    @MainActor
    func testCacheIsIsolatedBetweenProfiles() async throws {
        let store = enabledStore()
        let page = ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)
        let firstProfileID = UUID()
        let secondProfileID = UUID()

        let online = ConversationDetailState(offlineStore: store)
        await online.loadMessages(
            profile: profile(id: firstProfileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: OfflineTestAPI(pages: [77: page])
        )
        #expect(online.messages.count == 1)

        let other = ConversationDetailState(offlineStore: store)
        await other.loadMessages(
            profile: profile(id: secondProfileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: OfflineTestAPI(pages: [:], fetchError: .offline)
        )

        #expect(other.messages.isEmpty)
        #expect(other.isShowingCachedContent == false)
    }

    // MARK: - AC3: Represent an uncertain send

    @Test(
        "A send interrupted after the request left the device is reported as unconfirmed",
        arguments: [APIError.timedOut, .networkError("dropped"), .serverError(statusCode: 504)]
    )
    @MainActor
    func testUncertainSendIsRecorded(error: APIError) async throws {
        let store = enabledStore()
        let profileID = UUID()
        let api = OfflineTestAPI(
            pages: [77: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)],
            createError: error
        )

        let state = ConversationDetailState(offlineStore: store)
        await state.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        state.draft = "Possibly delivered"
        await state.sendMessage(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )

        #expect(state.uncertainSends.count == 1)
        #expect(state.requiresRetryConfirmation)
        #expect(state.sendErrorMessage?.contains("could not confirm") == true)
        // The draft is kept so the agent can decide what to do with it.
        #expect(state.draft == "Possibly delivered")
    }

    @Test("A send the server definitely refused is reported as a plain failure")
    @MainActor
    func testDefiniteFailureIsNotUncertain() async throws {
        let store = enabledStore()
        let profileID = UUID()
        let api = OfflineTestAPI(
            pages: [77: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)],
            createError: .forbidden
        )

        let state = ConversationDetailState(offlineStore: store)
        await state.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        state.draft = "Refused"
        await state.sendMessage(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )

        #expect(state.uncertainSends.isEmpty)
        #expect(state.requiresRetryConfirmation == false)
    }

    @Test("An unresolved uncertain send warns again when the conversation is reopened")
    @MainActor
    func testUncertainSendWarnsOnReturn() async throws {
        let store = enabledStore()
        let profileID = UUID()
        let page = ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)

        let first = ConversationDetailState(offlineStore: store)
        let failing = OfflineTestAPI(pages: [77: page], createError: .timedOut)
        await first.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: failing
        )
        first.draft = "Unconfirmed"
        await first.sendMessage(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: failing
        )

        let returning = ConversationDetailState(offlineStore: store)
        await returning.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: OfflineTestAPI(pages: [77: page])
        )

        #expect(returning.requiresRetryConfirmation)
        #expect(returning.sendErrorMessage?.contains("may post it twice") == true)
    }

    @Test("A confirmed send clears the earlier warning")
    @MainActor
    func testSuccessfulSendResolvesUncertainty() async throws {
        let store = enabledStore()
        let profileID = UUID()
        let page = ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)
        let api = OfflineTestAPI(pages: [77: page], createError: .timedOut)

        let state = ConversationDetailState(offlineStore: store)
        await state.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        state.draft = "Unconfirmed"
        await state.sendMessage(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        #expect(state.requiresRetryConfirmation)

        await api.setCreateResult(.success(message(id: 9)))
        await state.sendMessage(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )

        #expect(state.requiresRetryConfirmation == false)
        #expect(state.uncertainSends.isEmpty)
        #expect(state.draft.isEmpty)
    }

    @Test("Classifies which failures may still have been applied by the server")
    func testUncertaintyClassification() {
        #expect(APIError.timedOut.isOutcomeUncertain)
        #expect(APIError.networkError("dropped").isOutcomeUncertain)
        #expect(APIError.decodingError("unreadable").isOutcomeUncertain)
        #expect(APIError.serverError(statusCode: 502).isOutcomeUncertain)
        #expect(APIError.serverError(statusCode: 503).isOutcomeUncertain)
        #expect(APIError.serverError(statusCode: 504).isOutcomeUncertain)

        // The request never left the device or was definitively refused.
        #expect(APIError.offline.isOutcomeUncertain == false)
        #expect(APIError.unauthorized.isOutcomeUncertain == false)
        #expect(APIError.forbidden.isOutcomeUncertain == false)
        #expect(APIError.tlsFailure.isOutcomeUncertain == false)
        #expect(APIError.invalidMessageContent.isOutcomeUncertain == false)
        #expect(APIError.serverError(statusCode: 500).isOutcomeUncertain == false)
        #expect(APIError.cancelled.isOutcomeUncertain == false)
    }

    // MARK: - AC4: Invalid or cancelled attachment

    @Test(
        "Executable attachments are refused before any data is read",
        arguments: ["run.sh", "installer.pkg", "Tool.app", "macro.vbs", "setup.EXE"]
    )
    func testExecutableAttachmentsAreRefused(fileName: String) {
        #expect(throws: AttachmentSelectionError.self) {
            try OutgoingMessageAttachment(
                fileName: fileName,
                mimeType: "application/octet-stream",
                data: Data("invented".utf8)
            )
        }
    }

    @Test("A refused attachment names the type and explains why")
    func testDisallowedTypeIsExplained() {
        let error = AttachmentSelectionError.disallowedType("sh")
        #expect(error.errorDescription?.contains("sh") == true)
        #expect(error.errorDescription?.contains("run") == true)
    }

    @Test("A cancelled selection is explained rather than failing silently")
    @MainActor
    func testCancelledSelectionIsExplained() {
        let state = ConversationDetailState()
        state.reportAttachmentSelectionError(AttachmentSelectionError.cancelled)

        #expect(state.sendErrorMessage?.contains("cancelled") == true)
        #expect(state.pendingAttachments.isEmpty)
    }

    @Test("An allowed attachment is still accepted")
    func testAllowedAttachmentIsAccepted() throws {
        let attachment = try OutgoingMessageAttachment(
            fileName: "transcript.txt",
            mimeType: "text/plain",
            data: Data("invented transcript".utf8)
        )
        #expect(attachment.fileName == "transcript.txt")
    }

    // MARK: - AC5: Remove protected profile data

    @Test("Removing a profile deletes its drafts and cached content")
    @MainActor
    func testProfileRemovalDeletesOfflineData() async throws {
        let backing = InMemoryOfflineStore()
        let store = enabledStore(backing)
        let removedID = UUID()
        let keptID = UUID()
        let page = ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)
        let api = OfflineTestAPI(pages: [77: page])

        for id in [removedID, keptID] {
            let state = ConversationDetailState(offlineStore: store)
            await state.loadMessages(
                profile: profile(id: id),
                conversation: conversation(id: 77),
                token: "invented",
                using: api
            )
            state.draft = "Unsent work"
            await state.persistDraftNow()
        }
        #expect(await backing.recordCount() == 2)

        try await store.removeAllData(forProfile: removedID)

        let removedRecord = try await backing.loadRecord(
            for: ConversationScope(profileID: removedID, accountID: 1, conversationID: 77)
        )
        #expect(removedRecord.isEmpty)

        let keptRecord = try await backing.loadRecord(
            for: ConversationScope(profileID: keptID, accountID: 1, conversationID: 77)
        )
        #expect(keptRecord.draft?.text == "Unsent work")
    }

    // MARK: - AC6: Operate without offline storage

    @Test("With offline storage switched off, messaging works and nothing is stored")
    @MainActor
    func testDisabledStorageKeepsNothing() async throws {
        let backing = InMemoryOfflineStore()
        let preference = InMemoryOfflineStoragePreference(enabled: false)
        let store = ToggleableOfflineStore(backing: backing, preference: preference)
        let profileID = UUID()
        let page = ConversationMessagePage(messages: [message(id: 1), message(id: 2)], hasOlderMessages: false)
        let api = OfflineTestAPI(pages: [77: page], createResult: .success(message(id: 9)))

        let state = ConversationDetailState(offlineStore: store)
        await state.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        #expect(state.messages.count == 2)
        #expect(state.isOfflineStorageEnabled == false)

        state.draft = "Sent while connected"
        await state.persistDraftNow()
        await state.sendMessage(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )

        #expect(state.messages.contains { $0.id == 9 })
        #expect(await backing.recordCount() == 0)
    }

    @Test("Switching offline storage off deletes what was already stored")
    @MainActor
    func testDisablingPurgesExistingData() async throws {
        let backing = InMemoryOfflineStore()
        let store = enabledStore(backing)
        let profileID = UUID()
        let api = OfflineTestAPI(pages: [77: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)])

        let state = ConversationDetailState(offlineStore: store)
        await state.loadMessages(
            profile: profile(id: profileID),
            conversation: conversation(id: 77),
            token: "invented",
            using: api
        )
        state.draft = "Stored for now"
        await state.persistDraftNow()
        #expect(await backing.recordCount() == 1)

        try await store.apply(enabled: false, knownProfileIDs: [profileID])

        #expect(await backing.recordCount() == 0)
        #expect(store.isPersisting == false)
    }
}

/// A deterministic Chatwoot double for the offline tests.
///
/// It is an actor so a test can change the outcome of the next send, which is
/// how a retry after an unconfirmed attempt is exercised.
private actor OfflineTestAPI: ChatwootAPIProtocol {
    private let pages: [Int: ConversationMessagePage]
    private let fetchError: APIError?
    private var createResult: Result<ConversationMessage, APIError>

    init(
        pages: [Int: ConversationMessagePage],
        fetchError: APIError? = nil,
        createError: APIError? = nil,
        createResult: Result<ConversationMessage, APIError>? = nil
    ) {
        self.pages = pages
        self.fetchError = fetchError
        if let createResult {
            self.createResult = createResult
        } else if let createError {
            self.createResult = .failure(createError)
        } else {
            self.createResult = .failure(.notFound)
        }
    }

    func setCreateResult(_ result: Result<ConversationMessage, APIError>) {
        createResult = result
    }

    func fetchProfile(
        baseURL: URL,
        token: String
    ) async throws -> (profileName: String, agentID: Int?, accounts: [ChatwootAccount]) {
        (
            profileName: "Invented Agent",
            agentID: nil,
            accounts: [ChatwootAccount(id: 1, name: "Invented Account")]
        )
    }

    func updateAvailability(
        baseURL: URL,
        token: String,
        accountID: Int,
        availability: AgentAvailability
    ) async throws {
        throw UnstubbedChatwootOperation(name: "updateAvailability")
    }

    func fetchConversations(
        baseURL: URL,
        token: String,
        accountID: Int,
        status: ConversationStatus?,
        page: Int
    ) async throws -> [Conversation] {
        []
    }

    func fetchMessages(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        beforeMessageID: Int?
    ) async throws -> ConversationMessagePage {
        if let fetchError { throw fetchError }
        return pages[conversationID] ?? ConversationMessagePage(messages: [], hasOlderMessages: false)
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
        try createResult.get()
    }
}
