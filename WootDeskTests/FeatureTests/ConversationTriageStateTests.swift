import Foundation
import Testing
@testable import WootDesk

@Suite("Conversation Triage State Tests")
struct ConversationTriageStateTests {
    private func profile(id: UUID = UUID(), accountID: Int = 1) -> ServerProfile {
        ServerProfile(
            id: id,
            displayName: "Sample Server",
            baseURL: URL(string: "https://messages.example.com")!,
            selectedAccountID: accountID,
            selectedAccountName: "Sample Account"
        )
    }

    private func conversation(
        id: Int = 1041,
        accountID: Int = 1,
        status: ConversationStatus = .open,
        priority: ConversationPriority? = nil,
        assignee: ConversationAssignee? = nil,
        team: AssignableTeam? = nil,
        labels: [String] = []
    ) -> Conversation {
        Conversation(
            id: id,
            accountID: accountID,
            inboxID: 1,
            status: status,
            priority: priority,
            lastActivityAt: Date(timeIntervalSince1970: 1_735_737_000),
            assignee: assignee,
            team: team,
            labels: labels
        )
    }

    @MainActor
    private func adoptedState(
        _ conversation: Conversation,
        profile: ServerProfile
    ) -> ConversationTriageState {
        let state = ConversationTriageState()
        state.adopt(conversation, profile: profile)
        return state
    }

    // MARK: - AC1 Change conversation status

    @Test("A confirmed status change replaces the displayed status")
    @MainActor
    func testConfirmedStatusChange() async {
        let server = TriageTestAPI(conversation: conversation(status: .open))
        let serverProfile = profile()
        let state = adoptedState(conversation(status: .open), profile: serverProfile)

        await state.setStatus(.resolved, profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.status == .resolved)
        #expect(state.errorMessage == nil)
        #expect(state.pendingAction == nil)
        await #expect(server.recorder.statusChanges() == [.resolved])
    }

    @Test("The displayed status is the one the server confirms, not the one requested")
    @MainActor
    func testStatusReflectsServerNotRequest() async {
        // The server accepts the request but reports a different resulting state,
        // for example because an automation rule reopened the conversation.
        let server = TriageTestAPI(
            conversation: conversation(status: .open),
            confirmedOverride: conversation(status: .pending)
        )
        let serverProfile = profile()
        let state = adoptedState(conversation(status: .open), profile: serverProfile)

        await state.setStatus(.resolved, profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.status == .pending)
    }

    // MARK: - AC2 Snooze a conversation

    @Test("A snooze with a future time displays the confirmed return time")
    @MainActor
    func testSnoozeWithFutureTime() async {
        let returnDate = Date().addingTimeInterval(3_600)
        let server = TriageTestAPI(conversation: conversation(status: .open))
        let serverProfile = profile()
        let state = adoptedState(conversation(status: .open), profile: serverProfile)

        await state.setStatus(
            .snoozed,
            snoozedUntil: returnDate,
            profile: serverProfile,
            token: "token",
            using: server
        )

        #expect(state.conversation?.status == .snoozed)
        #expect(state.conversation?.snoozedUntil == returnDate)
        #expect(state.errorMessage == nil)
    }

    @Test("A snooze time in the past is rejected before any request is sent")
    @MainActor
    func testSnoozeRejectsPastTime() async {
        let server = TriageTestAPI(conversation: conversation(status: .open))
        let serverProfile = profile()
        let state = adoptedState(conversation(status: .open), profile: serverProfile)

        await state.setStatus(
            .snoozed,
            snoozedUntil: Date().addingTimeInterval(-60),
            profile: serverProfile,
            token: "token",
            using: server
        )

        #expect(state.conversation?.status == .open)
        #expect(state.errorMessage == APIError.invalidSnoozeTime.errorDescription)
        await #expect(server.recorder.statusChanges().isEmpty)
    }

    @Test("A snooze without a return time is rejected before any request is sent")
    @MainActor
    func testSnoozeRequiresReturnTime() async {
        let server = TriageTestAPI(conversation: conversation(status: .open))
        let serverProfile = profile()
        let state = adoptedState(conversation(status: .open), profile: serverProfile)

        await state.setStatus(.snoozed, profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.status == .open)
        #expect(state.errorMessage == APIError.invalidSnoozeTime.errorDescription)
        await #expect(server.recorder.statusChanges().isEmpty)
    }

    @Test("Snooze presets resolve to a future return time")
    func testSnoozePresetsAreInTheFuture() throws {
        let reference = Date(timeIntervalSince1970: 1_735_737_000)
        for option in ConversationSnoozeOption.allCases {
            let resolved = try #require(option.returnDate(from: reference))
            #expect(resolved > reference, "\(option.rawValue) must return after the reference date")
        }
    }

    // MARK: - AC3 Change conversation priority

    @Test("A confirmed priority change replaces the displayed priority")
    @MainActor
    func testConfirmedPriorityChange() async {
        let server = TriageTestAPI(conversation: conversation(priority: .low))
        let serverProfile = profile()
        let state = adoptedState(conversation(priority: .low), profile: serverProfile)

        await state.setPriority(.urgent, profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.priority == .urgent)
        #expect(state.errorMessage == nil)
    }

    @Test("Clearing a priority is confirmed by the server")
    @MainActor
    func testClearedPriority() async {
        let server = TriageTestAPI(conversation: conversation(priority: .urgent))
        let serverProfile = profile()
        let state = adoptedState(conversation(priority: .urgent), profile: serverProfile)

        await state.setPriority(nil, profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.priority == nil)
    }

    // MARK: - AC4 Assign a conversation

    @Test("A confirmed agent assignment is displayed")
    @MainActor
    func testConfirmedAgentAssignment() async {
        let server = TriageTestAPI(
            conversation: conversation(),
            options: ConversationAssignmentOptions(
                agents: [AssignableAgent(id: 7_002, name: "Elif Placeholder")]
            )
        )
        let serverProfile = profile()
        let state = adoptedState(conversation(), profile: serverProfile)

        await state.assign(to: .agent(id: 7_002), profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.assignee?.id == 7_002)
        #expect(state.conversation?.assignee?.name == "Elif Placeholder")
    }

    @Test("A confirmed team assignment is displayed")
    @MainActor
    func testConfirmedTeamAssignment() async {
        let server = TriageTestAPI(
            conversation: conversation(),
            options: ConversationAssignmentOptions(
                teams: [AssignableTeam(id: 6_001, name: "Sample Escalations")]
            )
        )
        let serverProfile = profile()
        let state = adoptedState(conversation(), profile: serverProfile)

        await state.assign(to: .team(id: 6_001), profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.team?.id == 6_001)
    }

    @Test("Removing an assignment is confirmed by the server")
    @MainActor
    func testUnassign() async {
        let assigned = conversation(assignee: ConversationAssignee(id: 7_001, name: "Sample Agent"))
        let server = TriageTestAPI(conversation: assigned)
        let serverProfile = profile()
        let state = adoptedState(assigned, profile: serverProfile)

        await state.assign(to: .unassignAgent, profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.assignee == nil)
    }

    @Test("An account with no assignment targets reports an empty set, not a failure")
    @MainActor
    func testEmptyAssignmentOptions() async {
        let server = TriageTestAPI(
            conversation: conversation(),
            options: ConversationAssignmentOptions()
        )
        let serverProfile = profile()
        let state = adoptedState(conversation(), profile: serverProfile)

        await state.loadOptions(profile: serverProfile, token: "token", using: server)

        #expect(state.assignmentOptions.isEmpty)
        #expect(state.optionsErrorMessage == nil)
    }

    // MARK: - AC5 Preserve the complete label set

    @Test("Adding a label preserves labels added on the server since display")
    @MainActor
    func testAddLabelPreservesLatestServerLabels() async {
        // The conversation was displayed with one label. Another agent added
        // "vip" on the server in the meantime.
        let displayed = conversation(labels: ["billing"])
        let server = TriageTestAPI(
            conversation: displayed,
            serverLabels: ["billing", "vip"]
        )
        let serverProfile = profile()
        let state = adoptedState(displayed, profile: serverProfile)

        await state.addLabel("export", profile: serverProfile, token: "token", using: server)

        let submitted = await server.recorder.submittedLabels()
        #expect(submitted == [["billing", "vip", "export"]])
        #expect(state.conversation?.labels == ["billing", "vip", "export"])
    }

    @Test("Removing a label preserves labels added on the server since display")
    @MainActor
    func testRemoveLabelPreservesLatestServerLabels() async {
        let displayed = conversation(labels: ["billing"])
        let server = TriageTestAPI(
            conversation: displayed,
            serverLabels: ["billing", "vip"]
        )
        let serverProfile = profile()
        let state = adoptedState(displayed, profile: serverProfile)

        await state.removeLabel("billing", profile: serverProfile, token: "token", using: server)

        let submitted = await server.recorder.submittedLabels()
        #expect(submitted == [["vip"]])
        #expect(state.conversation?.labels == ["vip"])
    }

    @Test("Adding a label that already exists does not duplicate it")
    @MainActor
    func testAddExistingLabelIsNotDuplicated() async {
        let displayed = conversation(labels: ["billing"])
        let server = TriageTestAPI(conversation: displayed, serverLabels: ["Billing"])
        let serverProfile = profile()
        let state = adoptedState(displayed, profile: serverProfile)

        await state.addLabel("billing", profile: serverProfile, token: "token", using: server)

        let submitted = await server.recorder.submittedLabels()
        #expect(submitted == [["billing"]])
    }

    @Test("The label set displayed is the one the server confirms")
    @MainActor
    func testLabelsReflectServerConfirmation() async {
        let displayed = conversation(labels: ["billing"])
        let server = TriageTestAPI(
            conversation: displayed,
            serverLabels: ["billing"],
            confirmedLabelsOverride: ["billing", "export", "audit"]
        )
        let serverProfile = profile()
        let state = adoptedState(displayed, profile: serverProfile)

        await state.addLabel("export", profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.labels == ["billing", "export", "audit"])
    }

    @Test("An empty label title is rejected before any request is sent")
    @MainActor
    func testEmptyLabelRejected() async {
        let server = TriageTestAPI(conversation: conversation())
        let serverProfile = profile()
        let state = adoptedState(conversation(), profile: serverProfile)

        await state.addLabel("   ", profile: serverProfile, token: "token", using: server)

        let submitted = await server.recorder.submittedLabels()
        #expect(submitted.isEmpty)
        #expect(state.errorMessage != nil)
    }

    // MARK: - AC6 Reject an unconfirmed triage change

    @Test(
        "A rejected triage change explains the failure and keeps the confirmed state",
        arguments: [
            APIError.unauthorized,
            APIError.forbidden,
            APIError.rateLimited(retryAfter: 30),
            APIError.offline,
            APIError.serverError(statusCode: 500, message: nil)
        ]
    )
    @MainActor
    func testRejectedStatusChange(error: APIError) async {
        let server = TriageTestAPI(conversation: conversation(status: .open), failure: error)
        let serverProfile = profile()
        let state = adoptedState(conversation(status: .open), profile: serverProfile)

        await state.setStatus(.resolved, profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.status == .open)
        #expect(state.pendingAction == nil)
        let message = state.errorMessage
        #expect(message?.contains("could not set the status to Resolved") == true)
        #expect(message?.contains(error.errorDescription ?? "") == true)
    }

    @Test("A rejected label change keeps the confirmed label set")
    @MainActor
    func testRejectedLabelChange() async {
        let displayed = conversation(labels: ["billing"])
        let server = TriageTestAPI(
            conversation: displayed,
            serverLabels: ["billing"],
            failure: .forbidden
        )
        let serverProfile = profile()
        let state = adoptedState(displayed, profile: serverProfile)

        await state.addLabel("export", profile: serverProfile, token: "token", using: server)

        #expect(state.conversation?.labels == ["billing"])
        #expect(state.errorMessage?.contains("could not add the label export") == true)
    }

    @Test("A failure loading assignment targets is reported without inventing an empty account")
    @MainActor
    func testOptionsFailureIsReported() async {
        let server = TriageTestAPI(conversation: conversation(), failure: .offline)
        let serverProfile = profile()
        let state = adoptedState(conversation(), profile: serverProfile)

        await state.loadOptions(profile: serverProfile, token: "token", using: server)

        #expect(state.assignmentOptions.isEmpty)
        #expect(state.optionsErrorMessage == APIError.offline.errorDescription)
    }

    // MARK: - Duplicate submission and profile isolation

    @Test("A second identical action while one is pending does not submit twice")
    @MainActor
    func testDuplicateSubmissionPrevented() async {
        let gate = TriageGate()
        let server = TriageTestAPI(conversation: conversation(status: .open), gate: gate)
        let serverProfile = profile()
        let state = adoptedState(conversation(status: .open), profile: serverProfile)

        async let first: Void = state.setStatus(
            .resolved,
            profile: serverProfile,
            token: "token",
            using: server
        )
        // Let the first submission reach the gated request.
        await gate.waitUntilEntered()
        #expect(state.isSubmitting)

        await state.setStatus(.resolved, profile: serverProfile, token: "token", using: server)
        await gate.open()
        await first

        await #expect(server.recorder.statusChanges() == [.resolved])
        #expect(state.conversation?.status == .resolved)
    }

    @Test("Adopting a conversation from another profile discards the previous triage state")
    @MainActor
    func testProfileIsolation() async {
        let firstProfile = profile(id: UUID(), accountID: 1)
        let secondProfile = profile(id: UUID(), accountID: 2)
        let server = TriageTestAPI(
            conversation: conversation(),
            options: ConversationAssignmentOptions(
                agents: [AssignableAgent(id: 7_001, name: "Sample Agent")]
            )
        )
        let state = adoptedState(conversation(labels: ["billing"]), profile: firstProfile)
        await state.loadOptions(profile: firstProfile, token: "token", using: server)
        #expect(!state.assignmentOptions.agents.isEmpty)

        state.adopt(conversation(id: 2_001, accountID: 2), profile: secondProfile)

        #expect(state.conversation?.id == 2_001)
        #expect(state.conversation?.labels.isEmpty == true)
        #expect(state.assignmentOptions.isEmpty)
        #expect(state.accountLabels.isEmpty)
    }

    @Test("Clearing the selection removes every triage value")
    @MainActor
    func testClearOnNoSelection() async {
        let serverProfile = profile()
        let state = adoptedState(conversation(labels: ["billing"]), profile: serverProfile)

        state.adopt(nil, profile: serverProfile)

        #expect(state.conversation == nil)
        #expect(state.errorMessage == nil)
        #expect(state.pendingAction == nil)
    }

    @Test("Available labels exclude those already applied, ignoring case")
    @MainActor
    func testAvailableLabelsExcludeApplied() async {
        let server = TriageTestAPI(
            conversation: conversation(labels: ["Billing"]),
            accountLabels: [
                AccountLabel(id: 1, title: "billing"),
                AccountLabel(id: 2, title: "export")
            ]
        )
        let serverProfile = profile()
        let state = adoptedState(conversation(labels: ["Billing"]), profile: serverProfile)
        await state.loadOptions(profile: serverProfile, token: "token", using: server)

        #expect(state.availableLabelsToAdd == ["export"])
    }
}

// MARK: - Test Support

/// Records the triage requests a test double received.
private actor TriageAPICallRecorder {
    private var statuses: [ConversationStatus] = []
    private var labelSubmissions: [[String]] = []
    private var assignments: [ConversationAssignmentTarget] = []

    func recordStatus(_ status: ConversationStatus) { statuses.append(status) }
    func recordLabels(_ labels: [String]) { labelSubmissions.append(labels) }
    func recordAssignment(_ target: ConversationAssignmentTarget) { assignments.append(target) }

    func statusChanges() -> [ConversationStatus] { statuses }
    func submittedLabels() -> [[String]] { labelSubmissions }
    func assignmentTargets() -> [ConversationAssignmentTarget] { assignments }
}

/// Holds a request open until the test releases it, so that a second submission
/// can be attempted while the first is genuinely in flight.
private actor TriageGate {
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

private struct TriageTestAPI: ChatwootAPIProtocol {
    let conversation: Conversation
    let confirmedOverride: Conversation?
    let serverLabels: [String]
    let confirmedLabelsOverride: [String]?
    let options: ConversationAssignmentOptions
    let accountLabels: [AccountLabel]
    let failure: APIError?
    let recorder: TriageAPICallRecorder
    let gate: TriageGate?

    init(
        conversation: Conversation,
        confirmedOverride: Conversation? = nil,
        serverLabels: [String] = [],
        confirmedLabelsOverride: [String]? = nil,
        options: ConversationAssignmentOptions = ConversationAssignmentOptions(),
        accountLabels: [AccountLabel] = [],
        failure: APIError? = nil,
        recorder: TriageAPICallRecorder = TriageAPICallRecorder(),
        gate: TriageGate? = nil
    ) {
        self.conversation = conversation
        self.confirmedOverride = confirmedOverride
        self.serverLabels = serverLabels
        self.confirmedLabelsOverride = confirmedLabelsOverride
        self.options = options
        self.accountLabels = accountLabels
        self.failure = failure
        self.recorder = recorder
        self.gate = gate
    }

    func fetchProfile(baseURL: URL, token: String) async throws -> (profileName: String, accounts: [ChatwootAccount]) {
        ("Sample Agent", [ChatwootAccount(id: 1, name: "Sample Account")])
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
        []
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
        confirmedOverride ?? conversation
    }

    func updateConversationStatus(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        status: ConversationStatus,
        snoozedUntil: Date?
    ) async throws -> Conversation {
        await gate?.enter()
        if let failure { throw failure }
        await recorder.recordStatus(status)
        if let confirmedOverride { return confirmedOverride }
        return conversation.applying(
            status: status,
            snoozedUntil: .some(status == .snoozed ? snoozedUntil : nil)
        )
    }

    func updateConversationPriority(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        priority: ConversationPriority?
    ) async throws -> Conversation {
        if let failure { throw failure }
        if let confirmedOverride { return confirmedOverride }
        return conversation.applying(priority: .some(priority))
    }

    func assignConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        target: ConversationAssignmentTarget
    ) async throws -> Conversation {
        if let failure { throw failure }
        await recorder.recordAssignment(target)
        if let confirmedOverride { return confirmedOverride }

        switch target {
        case .agent(let id):
            guard let agent = options.agents.first(where: { $0.id == id }) else {
                throw APIError.notFound
            }
            return conversation.applying(
                assignee: .some(ConversationAssignee(id: agent.id, name: agent.name))
            )
        case .team(let id):
            guard let team = options.teams.first(where: { $0.id == id }) else {
                throw APIError.notFound
            }
            return conversation.applying(team: .some(team))
        case .unassignAgent:
            return conversation.applying(assignee: .some(nil))
        case .unassignTeam:
            return conversation.applying(team: .some(nil))
        }
    }

    func fetchConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> [String] {
        serverLabels
    }

    func updateConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        labels: [String]
    ) async throws -> [String] {
        if let failure { throw failure }
        await recorder.recordLabels(labels)
        return confirmedLabelsOverride ?? labels
    }

    func fetchAssignmentOptions(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> ConversationAssignmentOptions {
        if let failure { throw failure }
        return options
    }

    func fetchAccountLabels(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> [AccountLabel] {
        if let failure { throw failure }
        return accountLabels
    }
}
