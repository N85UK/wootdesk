import Foundation
import Testing
@testable import WootDesk

@Suite("Conversation Detail State Tests")
struct ConversationDetailStateTests {
    private func profile(id: UUID = UUID(), accountID: Int = 1) -> ServerProfile {
        ServerProfile(
            id: id,
            displayName: "Sample Server",
            baseURL: URL(string: "https://messages.example.com")!,
            selectedAccountID: accountID,
            selectedAccountName: "Sample Account"
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

    private func message(
        id: Int,
        content: String? = nil,
        kind: ConversationMessageKind = .incoming,
        isPrivate: Bool = false
    ) -> ConversationMessage {
        ConversationMessage(
            id: id,
            content: content ?? "Invented message \(id)",
            kind: kind,
            isPrivate: isPrivate,
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_735_736_000 + id))
        )
    }

    private func attachment(
        name: String = "invented.txt",
        data: Data = Data("invented attachment".utf8)
    ) throws -> OutgoingMessageAttachment {
        try OutgoingMessageAttachment(
            fileName: name,
            mimeType: "text/plain",
            data: data
        )
    }

    @Test("Loads and orders the newest message page")
    @MainActor
    func testLoadsNewestPage() async {
        let api = MessageTestAPI(
            newestPages: [1041: ConversationMessagePage(
                messages: [message(id: 3), message(id: 1), message(id: 2)],
                hasOlderMessages: true
            )]
        )
        let state = ConversationDetailState()

        await state.loadMessages(
            profile: profile(),
            conversation: conversation(id: 1041),
            token: "test",
            using: api
        )

        #expect(state.messages.map(\.id) == [1, 2, 3])
        #expect(state.hasOlderMessages)
        #expect(state.errorMessage == nil)
        #expect(state.isLoading == false)
    }

    @Test("Loads older messages with the oldest ID and removes duplicates")
    @MainActor
    func testLoadsOlderPage() async {
        let recorder = MessageAPICallRecorder()
        let api = MessageTestAPI(
            newestPages: [1041: ConversationMessagePage(
                messages: [message(id: 3), message(id: 4)],
                hasOlderMessages: true
            )],
            olderPages: [1041: ConversationMessagePage(
                messages: [message(id: 1), message(id: 2), message(id: 3)],
                hasOlderMessages: false
            )],
            recorder: recorder
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()
        let selectedConversation = conversation(id: 1041)

        await state.loadMessages(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )
        await state.loadOlderMessages(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )

        #expect(state.messages.map(\.id) == [1, 2, 3, 4])
        #expect(state.hasOlderMessages == false)
        #expect(await recorder.fetchCursors() == [nil, 3])
    }

    @Test("A successful private note clears the submitted draft and appends the server response")
    @MainActor
    func testSendsPrivateNote() async {
        let recorder = MessageAPICallRecorder()
        let created = message(id: 20, content: "Invented internal note", kind: .outgoing, isPrivate: true)
        let api = MessageTestAPI(
            newestPages: [1041: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false)],
            createResult: .success(created),
            recorder: recorder
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()
        let selectedConversation = conversation(id: 1041)
        await state.loadMessages(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )
        state.composerMode = .privateNote
        state.draft = "  Invented internal note  "

        await state.sendMessage(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )

        #expect(state.messages.map(\.id) == [1, 20])
        #expect(state.draft.isEmpty)
        #expect(state.sendErrorMessage == nil)
        let send = await recorder.lastSend()
        #expect(send?.content == "Invented internal note")
        #expect(send?.isPrivate == true)
    }

    @Test("A failed reply retains the draft for recovery")
    @MainActor
    func testFailedSendRetainsDraft() async {
        let api = MessageTestAPI(
            newestPages: [1041: ConversationMessagePage(messages: [], hasOlderMessages: false)],
            createResult: .failure(.offline)
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()
        let selectedConversation = conversation(id: 1041)
        await state.loadMessages(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )
        state.draft = "Please keep this invented draft"

        await state.sendMessage(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )

        #expect(state.draft == "Please keep this invented draft")
        #expect(state.messages.isEmpty)
        #expect(state.sendErrorMessage == APIError.offline.errorDescription)
    }

    @Test("An attachment-only private note sends and clears its in-memory selection")
    @MainActor
    func testSendsAttachmentOnlyMessage() async throws {
        let recorder = MessageAPICallRecorder()
        let created = message(id: 21, content: nil, kind: .outgoing, isPrivate: true)
        let api = MessageTestAPI(
            newestPages: [1041: ConversationMessagePage(messages: [], hasOlderMessages: false)],
            createResult: .success(created),
            recorder: recorder
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()
        let selectedConversation = conversation(id: 1041)
        await state.loadMessages(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )
        state.composerMode = .privateNote
        try state.addPendingAttachments([attachment()])
        #expect(state.canSend)

        await state.sendMessage(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )

        #expect(state.pendingAttachments.isEmpty)
        #expect(state.messages.map(\.id) == [21])
        let send = await recorder.lastSend()
        #expect(send?.content == "")
        #expect(send?.isPrivate == true)
        #expect(send?.attachmentCount == 1)
    }

    @Test("A failed attachment upload retains the selection for recovery")
    @MainActor
    func testFailedAttachmentSendRetainsSelection() async throws {
        let api = MessageTestAPI(
            newestPages: [1041: ConversationMessagePage(messages: [], hasOlderMessages: false)],
            createResult: .failure(.offline)
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()
        let selectedConversation = conversation(id: 1041)
        await state.loadMessages(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )
        try state.addPendingAttachments([attachment()])

        await state.sendMessage(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )

        #expect(state.pendingAttachments.count == 1)
        #expect(state.sendErrorMessage == APIError.offline.errorDescription)
    }

    @Test("Attachment selection rejects more than Chatwoot's documented maximum")
    @MainActor
    func testRejectsTooManyAttachments() throws {
        let state = ConversationDetailState()
        let attachments = try (0...OutgoingMessageAttachment.maximumCount).map {
            try attachment(name: "invented-\($0).txt")
        }

        #expect(throws: AttachmentSelectionError.tooManyFiles) {
            try state.addPendingAttachments(attachments)
        }
        #expect(state.pendingAttachments.isEmpty)
    }

    @Test("Attachment selection rejects a total above the in-memory limit")
    @MainActor
    func testRejectsAttachmentTotalSize() throws {
        let state = ConversationDetailState()
        let maximumSized = try attachment(
            name: "invented-maximum.bin",
            data: Data(repeating: 0x41, count: OutgoingMessageAttachment.maximumTotalBytes)
        )
        let extra = try attachment(name: "invented-extra.txt", data: Data([0x42]))

        #expect(throws: AttachmentSelectionError.totalSizeExceeded) {
            try state.addPendingAttachments([maximumSized, extra])
        }
        #expect(state.pendingAttachments.isEmpty)
    }

    @Test("A successful send does not erase a newer draft edit")
    @MainActor
    func testSuccessfulSendPreservesNewerDraft() async throws {
        let created = message(id: 20, content: "Submitted draft", kind: .outgoing)
        let api = MessageTestAPI(
            newestPages: [1041: ConversationMessagePage(messages: [], hasOlderMessages: false)],
            createResult: .success(created),
            createDelay: .milliseconds(100)
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()
        let selectedConversation = conversation(id: 1041)
        await state.loadMessages(
            profile: selectedProfile,
            conversation: selectedConversation,
            token: "test",
            using: api
        )
        state.draft = "Submitted draft"

        let send = Task {
            await state.sendMessage(
                profile: selectedProfile,
                conversation: selectedConversation,
                token: "test",
                using: api
            )
        }
        try await Task.sleep(for: .milliseconds(20))
        state.draft = "A newer draft written while sending"
        await send.value

        #expect(state.messages.map(\.id) == [20])
        #expect(state.draft == "A newer draft written while sending")
    }

    @Test("Switching conversations clears the prior messages and draft")
    @MainActor
    func testSwitchingConversationClearsContent() async throws {
        let api = MessageTestAPI(
            newestPages: [
                1041: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false),
                2041: ConversationMessagePage(messages: [message(id: 2)], hasOlderMessages: false)
            ]
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()

        await state.loadMessages(
            profile: selectedProfile,
            conversation: conversation(id: 1041),
            token: "test",
            using: api
        )
        state.draft = "Draft for the first conversation"
        try state.addPendingAttachments([attachment()])

        await state.loadMessages(
            profile: selectedProfile,
            conversation: conversation(id: 2041),
            token: "test",
            using: api
        )

        #expect(state.messages.map(\.id) == [2])
        #expect(state.draft.isEmpty)
        #expect(state.pendingAttachments.isEmpty)
        #expect(state.composerMode == .reply)
    }

    @Test("A completed file import from an old conversation is discarded")
    @MainActor
    func testStaleAttachmentImportIsDiscarded() async throws {
        let api = MessageTestAPI(
            newestPages: [
                1041: ConversationMessagePage(messages: [], hasOlderMessages: false),
                2041: ConversationMessagePage(messages: [], hasOlderMessages: false)
            ]
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()
        await state.loadMessages(
            profile: selectedProfile,
            conversation: conversation(id: 1041),
            token: "test",
            using: api
        )
        let oldContextID = state.attachmentSelectionContextID

        await state.loadMessages(
            profile: selectedProfile,
            conversation: conversation(id: 2041),
            token: "test",
            using: api
        )
        let wasAdded = try state.addPendingAttachments(
            [attachment()],
            ifCurrent: oldContextID
        )

        #expect(wasAdded == false)
        #expect(state.pendingAttachments.isEmpty)
    }

    @Test("Changing accounts on the same saved profile clears prior content")
    @MainActor
    func testChangingAccountClearsContent() async {
        let profileID = UUID()
        let api = MessageTestAPI(
            newestPages: [
                1041: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false),
                2041: ConversationMessagePage(messages: [message(id: 2)], hasOlderMessages: false)
            ]
        )
        let state = ConversationDetailState()
        await state.loadMessages(
            profile: profile(id: profileID, accountID: 1),
            conversation: conversation(id: 1041, accountID: 1),
            token: "test",
            using: api
        )
        state.draft = "Draft for the first account"

        await state.loadMessages(
            profile: profile(id: profileID, accountID: 2),
            conversation: conversation(id: 2041, accountID: 2),
            token: "test",
            using: api
        )

        #expect(state.messages.map(\.id) == [2])
        #expect(state.draft.isEmpty)
    }

    @Test("A slow prior conversation cannot replace the active conversation")
    @MainActor
    func testStaleConversationResultIsIgnored() async throws {
        let api = MessageTestAPI(
            newestPages: [
                1041: ConversationMessagePage(messages: [message(id: 1)], hasOlderMessages: false),
                2041: ConversationMessagePage(messages: [message(id: 2)], hasOlderMessages: false)
            ],
            delayedConversationID: 1041
        )
        let state = ConversationDetailState()
        let selectedProfile = profile()

        let slowLoad = Task {
            await state.loadMessages(
                profile: selectedProfile,
                conversation: conversation(id: 1041),
                token: "test",
                using: api
            )
        }
        try await Task.sleep(for: .milliseconds(20))
        await state.loadMessages(
            profile: selectedProfile,
            conversation: conversation(id: 2041),
            token: "test",
            using: api
        )
        await slowLoad.value

        #expect(state.messages.map(\.id) == [2])
        #expect(state.errorMessage == nil)
    }
}

private actor MessageAPICallRecorder {
    struct Send: Sendable, Equatable {
        let content: String
        let isPrivate: Bool
        let attachmentCount: Int
    }

    private var cursors: [Int?] = []
    private var sends: [Send] = []

    func recordFetch(beforeMessageID: Int?) {
        cursors.append(beforeMessageID)
    }

    func recordSend(content: String, isPrivate: Bool, attachmentCount: Int) {
        sends.append(Send(
            content: content,
            isPrivate: isPrivate,
            attachmentCount: attachmentCount
        ))
    }

    func fetchCursors() -> [Int?] {
        cursors
    }

    func lastSend() -> Send? {
        sends.last
    }
}

private struct MessageTestAPI: ChatwootAPIProtocol {
    let newestPages: [Int: ConversationMessagePage]
    let olderPages: [Int: ConversationMessagePage]
    let createResult: Result<ConversationMessage, APIError>
    let recorder: MessageAPICallRecorder
    let delayedConversationID: Int?
    let createDelay: Duration?

    init(
        newestPages: [Int: ConversationMessagePage],
        olderPages: [Int: ConversationMessagePage] = [:],
        createResult: Result<ConversationMessage, APIError> = .failure(.notFound),
        recorder: MessageAPICallRecorder = MessageAPICallRecorder(),
        delayedConversationID: Int? = nil,
        createDelay: Duration? = nil
    ) {
        self.newestPages = newestPages
        self.olderPages = olderPages
        self.createResult = createResult
        self.recorder = recorder
        self.delayedConversationID = delayedConversationID
        self.createDelay = createDelay
    }

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
        []
    }

    func fetchMessages(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        beforeMessageID: Int?
    ) async throws -> ConversationMessagePage {
        await recorder.recordFetch(beforeMessageID: beforeMessageID)
        if delayedConversationID == conversationID {
            try await Task.sleep(for: .milliseconds(100))
        }
        if beforeMessageID != nil {
            return olderPages[conversationID]
                ?? ConversationMessagePage(messages: [], hasOlderMessages: false)
        }
        return newestPages[conversationID]
            ?? ConversationMessagePage(messages: [], hasOlderMessages: false)
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
        await recorder.recordSend(
            content: content,
            isPrivate: isPrivate,
            attachmentCount: attachments.count
        )
        if let createDelay {
            try await Task.sleep(for: createDelay)
        }
        return try createResult.get()
    }
}
