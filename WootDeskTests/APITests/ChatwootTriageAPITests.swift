import Testing
import Foundation
@testable import WootDesk

@Suite("Chatwoot Triage API Tests")
struct ChatwootTriageAPITests {
    /// Records the sequence of requests one triage call produced, because every
    /// mutation is followed by a confirming read.
    private final class ExchangeRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var exchanges: [(request: URLRequest, body: Data?)] = []

        func record(_ request: URLRequest) {
            let body = request.httpBody ?? Self.readBody(from: request.httpBodyStream)
            lock.lock()
            exchanges.append((request, body))
            lock.unlock()
        }

        func all() -> [(request: URLRequest, body: Data?)] {
            lock.lock()
            defer { lock.unlock() }
            return exchanges
        }

        func first() -> (request: URLRequest, body: Data?)? { all().first }

        private static func readBody(from stream: InputStream?) -> Data? {
            guard let stream else { return nil }
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1_024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            return data.isEmpty ? nil : data
        }
    }

    private func makeClient() -> (ChatwootAPIClient, URL) {
        let session = MockURLProtocol.makeMockSession()
        return (ChatwootAPIClient(session: session, isDebug: true), URL(string: "https://chatwoot.example.com")!)
    }

    /// Answers each request by matching its path, so a test can describe the
    /// mutation and the confirming read independently.
    private func respond(
        recorder: ExchangeRecorder,
        routes: [String: (status: Int, body: Data)]
    ) {
        MockURLProtocol.setHandler { request in
            recorder.record(request)
            let path = request.url?.path ?? ""
            let match = routes.first { path.hasSuffix($0.key) }
            let route = match?.value ?? (status: 404, body: Data("{}".utf8))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: route.status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, route.body)
        }
    }

    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private func decodedBody(_ data: Data?) throws -> [String: Any] {
        let data = try #require(data)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Single Conversation Read

    @Test("Decodes a conversation carrying assignment, labels and a snooze time")
    func testDecodesFullTriageConversation() async throws {
        let recorder = ExchangeRecorder()
        respond(
            recorder: recorder,
            routes: ["/conversations/1041": (200, try FixtureLoader.loadData(named: "conversation_triage_confirmed"))]
        )
        let (client, baseURL) = makeClient()

        let conversation = try await client.fetchConversation(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041
        )

        #expect(conversation.id == 1041)
        #expect(conversation.status == .snoozed)
        #expect(conversation.priority == .urgent)
        #expect(conversation.assignee == ConversationAssignee(id: 7_001, name: "Sample Agent"))
        #expect(conversation.team == AssignableTeam(id: 6_001, name: "Sample Escalations"))
        #expect(conversation.labels == ["billing", "export"])
        #expect(conversation.snoozedUntil == Date(timeIntervalSince1970: 1_767_225_600))

        let path = try #require(recorder.first()?.request.url?.path)
        #expect(path == "/api/v1/accounts/1/conversations/1041")
    }

    @Test("A conversation without triage fields decodes as unknown, not as fabricated values")
    func testDecodesMinimalConversation() async throws {
        let recorder = ExchangeRecorder()
        respond(
            recorder: recorder,
            routes: ["/conversations/1042": (200, try FixtureLoader.loadData(named: "conversation_triage_minimal"))]
        )
        let (client, baseURL) = makeClient()

        let conversation = try await client.fetchConversation(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1042
        )

        #expect(conversation.id == 1042)
        #expect(conversation.assignee == nil)
        #expect(conversation.team == nil)
        #expect(conversation.labels.isEmpty)
        #expect(conversation.snoozedUntil == nil)
    }

    @Test("An unrecognised conversation body is a decoding failure, not an empty conversation")
    func testRejectsUnrecognisedConversationBody() async throws {
        let recorder = ExchangeRecorder()
        respond(
            recorder: recorder,
            routes: ["/conversations/1041": (200, try FixtureLoader.loadData(named: "malformed_response"))]
        )
        let (client, baseURL) = makeClient()

        await #expect(throws: APIError.self) {
            _ = try await client.fetchConversation(
                baseURL: baseURL,
                token: "token",
                accountID: 1,
                conversationID: 1041
            )
        }
    }

    // MARK: - Status and Snooze

    @Test("A status change posts to toggle_status and then reads the conversation back")
    func testStatusChangeRequestAndConfirmation() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: [
            "/toggle_status": (200, Data("{}".utf8)),
            "/conversations/1041": (200, try FixtureLoader.loadData(named: "conversation_triage_confirmed"))
        ])
        let (client, baseURL) = makeClient()

        let confirmed = try await client.updateConversationStatus(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041,
            status: .resolved,
            snoozedUntil: nil
        )

        let exchanges = recorder.all()
        #expect(exchanges.count == 2)
        #expect(exchanges[0].request.url?.path == "/api/v1/accounts/1/conversations/1041/toggle_status")
        #expect(exchanges[0].request.httpMethod == "POST")
        let body = try decodedBody(exchanges[0].body)
        #expect(body["status"] as? String == "resolved")
        #expect(body["snoozed_until"] == nil)
        #expect(exchanges[1].request.httpMethod == "GET")
        // The confirmed value comes from the server read, not the request.
        #expect(confirmed.status == .snoozed)
    }

    @Test("A snooze sends the return time as epoch seconds")
    func testSnoozeSendsEpochSeconds() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: [
            "/toggle_status": (200, Data("{}".utf8)),
            "/conversations/1041": (200, try FixtureLoader.loadData(named: "conversation_triage_confirmed"))
        ])
        let (client, baseURL) = makeClient()
        let returnDate = Date().addingTimeInterval(3_600)

        _ = try await client.updateConversationStatus(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041,
            status: .snoozed,
            snoozedUntil: returnDate
        )

        let body = try decodedBody(recorder.first()?.body)
        #expect(body["status"] as? String == "snoozed")
        #expect(body["snoozed_until"] as? Int == Int(returnDate.timeIntervalSince1970.rounded()))
    }

    @Test("A snooze without a future return time sends no request")
    func testSnoozeRejectedBeforeRequest() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: ["/toggle_status": (200, Data("{}".utf8))])
        let (client, baseURL) = makeClient()

        await #expect(throws: APIError.invalidSnoozeTime) {
            _ = try await client.updateConversationStatus(
                baseURL: baseURL,
                token: "token",
                accountID: 1,
                conversationID: 1041,
                status: .snoozed,
                snoozedUntil: Date().addingTimeInterval(-1)
            )
        }
        #expect(recorder.all().isEmpty)
    }

    @Test("A rejected status change surfaces the mapped error and sends no confirming read")
    func testRejectedStatusChangeStopsAtMutation() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: ["/toggle_status": (403, Data("{}".utf8))])
        let (client, baseURL) = makeClient()

        await #expect(throws: APIError.forbidden) {
            _ = try await client.updateConversationStatus(
                baseURL: baseURL,
                token: "token",
                accountID: 1,
                conversationID: 1041,
                status: .resolved,
                snoozedUntil: nil
            )
        }
        #expect(recorder.all().count == 1)
    }

    // MARK: - Priority

    @Test("A priority change posts to toggle_priority and then confirms")
    func testPriorityChangeRequest() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: [
            "/toggle_priority": (200, Data()),
            "/conversations/1041": (200, try FixtureLoader.loadData(named: "conversation_triage_confirmed"))
        ])
        let (client, baseURL) = makeClient()

        let confirmed = try await client.updateConversationPriority(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041,
            priority: .urgent
        )

        let exchanges = recorder.all()
        #expect(exchanges[0].request.url?.path == "/api/v1/accounts/1/conversations/1041/toggle_priority")
        let body = try decodedBody(exchanges[0].body)
        #expect(body["priority"] as? String == "urgent")
        #expect(confirmed.priority == .urgent)
    }

    @Test("Clearing a priority sends an empty priority value")
    func testClearPriorityRequest() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: [
            "/toggle_priority": (200, Data()),
            "/conversations/1041": (200, try FixtureLoader.loadData(named: "conversation_triage_minimal"))
        ])
        let (client, baseURL) = makeClient()

        _ = try await client.updateConversationPriority(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041,
            priority: nil
        )

        let body = try decodedBody(recorder.first()?.body)
        #expect(body["priority"] as? String == "")
    }

    // MARK: - Assignment

    @Test(
        "Assignment posts the documented parameter for each target",
        arguments: [
            (ConversationAssignmentTarget.agent(id: 7_002), "assignee_id", 7_002),
            (ConversationAssignmentTarget.team(id: 6_001), "team_id", 6_001),
            (ConversationAssignmentTarget.unassignAgent, "assignee_id", 0),
            (ConversationAssignmentTarget.unassignTeam, "team_id", 0)
        ]
    )
    func testAssignmentRequestParameters(
        target: ConversationAssignmentTarget,
        parameterName: String,
        parameterValue: Int
    ) async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: [
            "/assignments": (200, Data("{}".utf8)),
            "/conversations/1041": (200, try FixtureLoader.loadData(named: "conversation_triage_confirmed"))
        ])
        let (client, baseURL) = makeClient()

        _ = try await client.assignConversation(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041,
            target: target
        )

        let exchange = try #require(recorder.first())
        #expect(exchange.request.url?.path == "/api/v1/accounts/1/conversations/1041/assignments")
        let body = try decodedBody(exchange.body)
        #expect(body[parameterName] as? Int == parameterValue)
    }

    // MARK: - Labels

    @Test("Conversation labels decode from a string payload")
    func testDecodesLabelStrings() async throws {
        let recorder = ExchangeRecorder()
        respond(
            recorder: recorder,
            routes: ["/labels": (200, try FixtureLoader.loadData(named: "conversation_labels"))]
        )
        let (client, baseURL) = makeClient()

        let labels = try await client.fetchConversationLabels(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041
        )

        #expect(labels == ["billing", "export"])
    }

    @Test("Conversation labels decode from an object payload on older servers")
    func testDecodesLabelObjects() async throws {
        let recorder = ExchangeRecorder()
        respond(
            recorder: recorder,
            routes: ["/labels": (200, try FixtureLoader.loadData(named: "conversation_labels_objects"))]
        )
        let (client, baseURL) = makeClient()

        let labels = try await client.fetchConversationLabels(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041
        )

        #expect(labels == ["billing", "export"])
    }

    @Test("A label update sends the complete intended set")
    func testLabelUpdateSendsCompleteSet() async throws {
        let recorder = ExchangeRecorder()
        respond(
            recorder: recorder,
            routes: ["/labels": (200, try FixtureLoader.loadData(named: "conversation_labels"))]
        )
        let (client, baseURL) = makeClient()

        let confirmed = try await client.updateConversationLabels(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041,
            labels: ["billing", "export"]
        )

        let exchange = try #require(recorder.first())
        #expect(exchange.request.httpMethod == "POST")
        let body = try decodedBody(exchange.body)
        #expect(body["labels"] as? [String] == ["billing", "export"])
        #expect(confirmed == ["billing", "export"])
    }

    @Test("A label update answered with an empty body reads the confirmed set back")
    func testLabelUpdateReadsBackOnEmptyBody() async throws {
        let recorder = ExchangeRecorder()
        let labelsFixture = try FixtureLoader.loadData(named: "conversation_labels")
        MockURLProtocol.setHandler { request in
            recorder.record(request)
            let isWrite = request.httpMethod == "POST"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, isWrite ? Data() : labelsFixture)
        }
        let (client, baseURL) = makeClient()

        let confirmed = try await client.updateConversationLabels(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            conversationID: 1041,
            labels: ["billing"]
        )

        // The requested set was a single label. The confirmed set is what the
        // follow-up read returned, not what was requested.
        #expect(confirmed == ["billing", "export"])
        #expect(recorder.all().count == 2)
    }

    // MARK: - Assignment Targets and Account Labels

    @Test("Assignment targets combine the agent and team lists")
    func testFetchesAssignmentOptions() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: [
            "/agents": (200, try FixtureLoader.loadData(named: "account_agents")),
            "/teams": (200, try FixtureLoader.loadData(named: "account_teams"))
        ])
        let (client, baseURL) = makeClient()

        let options = try await client.fetchAssignmentOptions(
            baseURL: baseURL,
            token: "token",
            accountID: 1
        )

        #expect(options.agents.count == 3)
        #expect(options.agents[0] == AssignableAgent(id: 7_001, name: "Sample Agent", availability: .online))
        #expect(options.agents[1].availability == .busy)
        // A member with no name is identified rather than given an invented one.
        #expect(options.agents[2].name == "Agent #7003")
        #expect(options.teams.map(\.id) == [6_001, 6_002])
    }

    @Test("A team list the agent may not read yields no teams while agents still load")
    func testForbiddenTeamsYieldsEmptyTeamList() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: [
            "/agents": (200, try FixtureLoader.loadData(named: "account_agents")),
            "/teams": (403, Data("{}".utf8))
        ])
        let (client, baseURL) = makeClient()

        let options = try await client.fetchAssignmentOptions(
            baseURL: baseURL,
            token: "token",
            accountID: 1
        )

        #expect(options.agents.count == 3)
        #expect(options.teams.isEmpty)
    }

    @Test("An agent list failure is reported rather than presented as no agents")
    func testAgentFailurePropagates() async throws {
        let recorder = ExchangeRecorder()
        respond(recorder: recorder, routes: ["/agents": (500, Data("{}".utf8))])
        let (client, baseURL) = makeClient()

        await #expect(throws: APIError.self) {
            _ = try await client.fetchAssignmentOptions(
                baseURL: baseURL,
                token: "token",
                accountID: 1
            )
        }
    }

    @Test("Account labels decode with and without a colour")
    func testFetchesAccountLabels() async throws {
        let recorder = ExchangeRecorder()
        respond(
            recorder: recorder,
            routes: ["/labels": (200, try FixtureLoader.loadData(named: "account_labels"))]
        )
        let (client, baseURL) = makeClient()

        let labels = try await client.fetchAccountLabels(
            baseURL: baseURL,
            token: "token",
            accountID: 1
        )

        #expect(labels == [
            AccountLabel(id: 5_001, title: "billing", colour: "#1F93FF"),
            AccountLabel(id: 5_002, title: "export", colour: nil)
        ])
    }
}
