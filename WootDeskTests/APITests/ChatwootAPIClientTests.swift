import Testing
import Foundation
@testable import WootDesk

@Suite("Chatwoot API Client HTTP & Error Mapping Tests")
struct ChatwootAPIClientTests {
    private final class RequestRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var recordedURL: URL?

        func record(_ request: URLRequest) {
            lock.lock()
            recordedURL = request.url
            lock.unlock()
        }

        func url() -> URL? {
            lock.lock()
            defer { lock.unlock() }
            return recordedURL
        }
    }

    private func makeClient() -> (ChatwootAPIClient, URL) {
        let session = MockURLProtocol.makeMockSession()
        let client = ChatwootAPIClient(session: session, isDebug: true)
        let baseURL = URL(string: "https://chatwoot.example.com")!
        return (client, baseURL)
    }

    @Test("Maps HTTP 401 response to APIError.unauthorized")
    func test401Unauthorized() async throws {
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"error": "Invalid access token"}
            """.data(using: .utf8)!
            return (response, data)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "bad_token")
            #expect(Bool(false), "Expected APIError.unauthorized to be thrown")
        } catch let apiError as APIError {
            #expect(apiError == .unauthorized)
        }
    }

    @Test("Maps HTTP 403 response to APIError.forbidden")
    func test403Forbidden() async throws {
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchConversations(baseURL: baseURL, token: "token", accountID: 1)
            #expect(Bool(false), "Expected APIError.forbidden")
        } catch let apiError as APIError {
            #expect(apiError == .forbidden)
        }
    }

    @Test("Maps HTTP 404 response to APIError.notFound")
    func test404NotFound() async throws {
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchConversations(baseURL: baseURL, token: "token", accountID: 999)
            #expect(Bool(false), "Expected APIError.notFound")
        } catch let apiError as APIError {
            #expect(apiError == .notFound)
        }
    }

    @Test("Maps HTTP 429 response to APIError.rateLimited with Retry-After")
    func test429RateLimited() async throws {
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "30"]
            )!
            return (response, Data())
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected APIError.rateLimited")
        } catch let apiError as APIError {
            #expect(apiError == .rateLimited(retryAfter: 30))
        }
    }

    @Test("Maps HTTP 500 response to APIError.serverError")
    func test500ServerError() async throws {
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"message": "Internal Database Error"}
            """.data(using: .utf8)!
            return (response, data)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected APIError.serverError")
        } catch let apiError as APIError {
            #expect(apiError == .serverError(statusCode: 500, message: "Internal Database Error"))
        }
    }

    @Test("Maps an offline connection to APIError.offline")
    func testNetworkConnectionError() async throws {
        MockURLProtocol.setHandler { _ in
            throw URLError(.notConnectedToInternet)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected offline")
        } catch let apiError as APIError {
            #expect(apiError == .offline)
        }
    }

    @Test("Maps request timeout to APIError.timedOut")
    func testTimeoutError() async throws {
        MockURLProtocol.setHandler { _ in
            throw URLError(.timedOut)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected .timedOut")
        } catch let apiError as APIError {
            #expect(apiError == .timedOut)
        }
    }

    @Test("Maps a TLS trust failure to APIError.tlsFailure")
    func testTLSFailure() async throws {
        MockURLProtocol.setHandler { _ in
            throw URLError(.serverCertificateUntrusted)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected .tlsFailure")
        } catch let apiError as APIError {
            #expect(apiError == .tlsFailure)
        }
    }

    @Test("Maps a malformed conversation response to APIError.decodingError")
    func testMalformedConversationResponse() async throws {
        let body = try FixtureLoader.loadData(named: "malformed_response.json")
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchConversations(baseURL: baseURL, token: "token", accountID: 1)
            #expect(Bool(false), "A response matching no known shape must not be reported as an empty list")
        } catch let apiError as APIError {
            guard case .decodingError = apiError else {
                #expect(Bool(false), "Expected .decodingError but got \(apiError)")
                return
            }
        }
    }

    @Test("Maps a non-JSON response body to APIError.decodingError")
    func testNonJSONResponseBody() async throws {
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("<html><body>Gateway online</body></html>".utf8))
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected .decodingError for an HTML body")
        } catch let apiError as APIError {
            guard case .decodingError = apiError else {
                #expect(Bool(false), "Expected .decodingError but got \(apiError)")
                return
            }
        }
    }

    @Test("An empty conversation payload decodes to an empty list, not an error")
    func testEmptyConversationPayload() async throws {
        let body = try FixtureLoader.loadData(named: "conversations_empty.json")
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        let (client, baseURL) = makeClient()
        let conversations = try await client.fetchConversations(baseURL: baseURL, token: "token", accountID: 1)

        #expect(conversations.isEmpty)
    }

    @Test("A profile with no accounts maps to APIError.noAccountsAvailable")
    func testProfileWithoutAccounts() async throws {
        let body = try FixtureLoader.loadData(named: "profile_no_accounts.json")
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected .noAccountsAvailable")
        } catch let apiError as APIError {
            #expect(apiError == .noAccountsAvailable)
        }
    }

    @Test("A successful profile fetch returns the profile name and accounts")
    func testSuccessfulProfileFetch() async throws {
        let body = try FixtureLoader.loadData(named: "profile_multi_account.json")
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        let (client, baseURL) = makeClient()
        let (name, accounts) = try await client.fetchProfile(baseURL: baseURL, token: "token")

        #expect(name == "Alex Multi Team")
        #expect(accounts.count == 3)
    }

    @Test("No error description ever contains the access token")
    func testErrorsNeverLeakTheToken() async throws {
        let credential = String(repeating: "s", count: 32)
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"message\": \"boom\"}".utf8))
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: credential)
            #expect(Bool(false), "Expected a server error")
        } catch let apiError as APIError {
            let description = apiError.errorDescription ?? ""
            #expect(!description.contains(credential))
        }
    }

    @Test("Surfaces the errors-array body shape used by self-hosted Chatwoot")
    func testErrorsArrayBodyShape() async throws {
        // Some self-hosted versions return an errors array rather than a message
        // string, so the client accepts both non-secret error shapes.
        let body = try FixtureLoader.loadData(named: "error_response_errors_array.json")
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected a server error")
        } catch let apiError as APIError {
            guard case .serverError(let statusCode, let message) = apiError else {
                #expect(Bool(false), "Expected .serverError but got \(apiError)")
                return
            }
            #expect(statusCode == 500)
            #expect(message == "You need to sign in or sign up before continuing.")
        }
    }

    @Test("A nil conversation status requests Chatwoot's all status")
    func testNilConversationStatusRequestsAll() async throws {
        let recorder = RequestRecorder()
        MockURLProtocol.setHandler { request in
            recorder.record(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = try FixtureLoader.loadData(named: "conversations_empty.json")
            return (response, data)
        }

        let (client, baseURL) = makeClient()
        _ = try await client.fetchConversations(
            baseURL: baseURL,
            token: "token",
            accountID: 1,
            status: nil
        )

        let observedURL = try #require(recorder.url())
        let components = try #require(URLComponents(url: observedURL, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(URLQueryItem(name: "status", value: "all")) == true)
    }

    @Test("An unauthenticated request maps to unauthorized regardless of body shape")
    func testUnauthorizedWithErrorsArrayBody() async throws {
        // A live Chatwoot instance answers an unauthenticated GET /api/v1/profile
        // with HTTP 401 and this body.
        let body = try FixtureLoader.loadData(named: "error_response_errors_array.json")
        MockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        let (client, baseURL) = makeClient()

        do {
            _ = try await client.fetchProfile(baseURL: baseURL, token: "token")
            #expect(Bool(false), "Expected .unauthorized")
        } catch let apiError as APIError {
            #expect(apiError == .unauthorized)
        }
    }
}
