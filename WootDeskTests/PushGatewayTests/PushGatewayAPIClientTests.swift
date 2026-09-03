import Foundation
import Testing
@testable import WootDesk

@Suite("Push Gateway API Client Tests", .serialized)
struct PushGatewayAPIClientTests {
    private let deviceID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let profileID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    private let idempotencyKey = "22222222-2222-4222-8222-222222222222"

    @Test("Gateway URL policy trims input and preserves a path prefix")
    func normalisesGatewayURL() throws {
        let url = try PushGatewayRequest.normaliseBaseURL(
            "  https://push.example.com/wootdesk/  ",
            isDebug: false
        )
        #expect(url.absoluteString == "https://push.example.com/wootdesk")

        let endpoint = try PushGatewayRequest.endpointURL(baseURL: url, path: "/v1/devices")
        #expect(endpoint.absoluteString == "https://push.example.com/wootdesk/v1/devices")
    }

    @Test("Gateway URL policy rejects HTTP outside debug localhost")
    func rejectsInsecureGatewayURL() {
        #expect(throws: PushGatewayAPIError.insecureScheme) {
            try PushGatewayRequest.normaliseBaseURL("http://push.example.com", isDebug: true)
        }
        #expect(throws: PushGatewayAPIError.insecureScheme) {
            try PushGatewayRequest.normaliseBaseURL("http://localhost:8080", isDebug: false)
        }
    }

    @Test("Creating a registration applies bearer and idempotency headers")
    func createsAuthenticatedRegistration() async throws {
        let recorder = GatewayRequestRecorder()
        MockURLProtocol.setHandler { request in
            recorder.record(request)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 201,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                self.registrationResponse()
            )
        }

        let session = MockURLProtocol.makeMockSession()
        defer { session.finishTasksAndInvalidate() }
        let client = PushGatewayAPIClient(session: session)
        let registration = try await client.createRegistration(
            baseURL: URL(string: "https://push.example.com/service")!,
            apiToken: "gateway-secret",
            registration: request(),
            idempotencyKey: idempotencyKey
        )

        #expect(registration.deviceId == deviceID)
        let observed = try #require(recorder.request())
        #expect(observed.url?.absoluteString == "https://push.example.com/service/v1/devices")
        #expect(observed.httpMethod == "POST")
        #expect(observed.value(forHTTPHeaderField: "Authorization") == "Bearer gateway-secret")
        #expect(observed.value(forHTTPHeaderField: "Idempotency-Key") == idempotencyKey)
        let body = try #require(recorder.body())
        let decoded = try JSONDecoder().decode(PushGatewayDeviceRegistrationRequest.self, from: body)
        #expect(decoded == request())
    }

    @Test("Updating a registration omits the device ID from its JSON body")
    func updatesRegistration() async throws {
        let recorder = GatewayRequestRecorder()
        MockURLProtocol.setHandler { request in
            recorder.record(request)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                self.registrationResponse()
            )
        }

        let session = MockURLProtocol.makeMockSession()
        defer { session.finishTasksAndInvalidate() }
        let client = PushGatewayAPIClient(session: session)
        _ = try await client.updateRegistration(
            baseURL: URL(string: "https://push.example.com")!,
            apiToken: "gateway-secret",
            registration: request(),
            idempotencyKey: idempotencyKey
        )

        let observed = try #require(recorder.request())
        #expect(observed.url?.path == "/v1/devices/11111111-1111-4111-8111-111111111111")
        #expect(observed.httpMethod == "PUT")
        let recordedBody = try #require(recorder.body())
        let decodedObject = try JSONSerialization.jsonObject(with: recordedBody)
        let object = try #require(decodedObject as? [String: Any])
        #expect(object["deviceId"] == nil)
        #expect(object["profileId"] as? String == profileID.uuidString.uppercased())
    }

    @Test("Deleting a missing registration is treated as idempotent success")
    func deletesMissingRegistration() async throws {
        MockURLProtocol.setHandler { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }

        let session = MockURLProtocol.makeMockSession()
        defer { session.finishTasksAndInvalidate() }
        let client = PushGatewayAPIClient(session: session)
        try await client.deleteRegistration(
            baseURL: URL(string: "https://push.example.com")!,
            apiToken: "gateway-secret",
            deviceID: deviceID,
            idempotencyKey: idempotencyKey
        )
    }

    @Test("Gateway status codes map to safe typed errors", arguments: [
        (401, PushGatewayAPIError.unauthorised),
        (409, PushGatewayAPIError.conflict),
        (413, PushGatewayAPIError.payloadTooLarge),
        (503, PushGatewayAPIError.unavailable),
    ])
    func mapsGatewayStatus(status: Int, expected: PushGatewayAPIError) async {
        MockURLProtocol.setHandler { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("{\"error\":{\"code\":\"invented\",\"message\":\"Invented\"}}".utf8)
            )
        }

        let session = MockURLProtocol.makeMockSession()
        defer { session.finishTasksAndInvalidate() }
        let client = PushGatewayAPIClient(session: session)
        do {
            _ = try await client.createRegistration(
                baseURL: URL(string: "https://push.example.com")!,
                apiToken: "never-exposed",
                registration: request(),
                idempotencyKey: idempotencyKey
            )
            Issue.record("Expected gateway error")
        } catch let error as PushGatewayAPIError {
            #expect(error == expected)
            #expect(!(error.errorDescription ?? "").contains("never-exposed"))
        } catch {
            Issue.record("Expected PushGatewayAPIError")
        }
    }

    @Test("Gateway network errors map without exposing credentials", arguments: [
        (URLError.Code.notConnectedToInternet, PushGatewayAPIError.offline),
        (URLError.Code.timedOut, PushGatewayAPIError.timedOut),
        (URLError.Code.serverCertificateUntrusted, PushGatewayAPIError.tlsFailure),
    ])
    func mapsNetworkError(code: URLError.Code, expected: PushGatewayAPIError) async {
        MockURLProtocol.setHandler { _ in throw URLError(code) }
        let session = MockURLProtocol.makeMockSession()
        defer { session.finishTasksAndInvalidate() }
        let client = PushGatewayAPIClient(session: session)

        do {
            _ = try await client.createRegistration(
                baseURL: URL(string: "https://push.example.com")!,
                apiToken: "never-exposed",
                registration: request(),
                idempotencyKey: idempotencyKey
            )
            Issue.record("Expected gateway network error")
        } catch let error as PushGatewayAPIError {
            #expect(error == expected)
            #expect(!(error.errorDescription ?? "").contains("never-exposed"))
        } catch {
            Issue.record("Expected PushGatewayAPIError")
        }
    }

    @Test("A successful but malformed response is not treated as enrolment")
    func rejectsMalformedResponse() async {
        MockURLProtocol.setHandler { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 201,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("{}".utf8)
            )
        }

        let session = MockURLProtocol.makeMockSession()
        defer { session.finishTasksAndInvalidate() }
        let client = PushGatewayAPIClient(session: session)
        do {
            _ = try await client.createRegistration(
                baseURL: URL(string: "https://push.example.com")!,
                apiToken: "gateway-secret",
                registration: request(),
                idempotencyKey: idempotencyKey
            )
            Issue.record("Expected malformed response error")
        } catch let error as PushGatewayAPIError {
            #expect(error == .malformedResponse)
        } catch {
            Issue.record("Expected PushGatewayAPIError")
        }
    }

    private func request() -> PushGatewayDeviceRegistrationRequest {
        PushGatewayDeviceRegistrationRequest(
            deviceId: deviceID,
            profileId: profileID,
            accountId: 42,
            agentId: 7,
            environment: .development,
            topic: "dev.n85.wootdesk",
            token: "ab" + String(repeating: "01", count: 31)
        )
    }

    private func registrationResponse() -> Data {
        Data(
            """
            {"registration":{"deviceId":"11111111-1111-4111-8111-111111111111","profileId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","accountId":42,"environment":"development","topic":"dev.n85.wootdesk","updatedAt":"2026-08-31T12:00:00.000Z"}}
            """.utf8
        )
    }
}

private final class GatewayRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequest: URLRequest?
    private var recordedBody: Data?

    func record(_ request: URLRequest) {
        let body = request.httpBody ?? Self.readBody(from: request.httpBodyStream)
        lock.lock()
        recordedRequest = request
        recordedBody = body
        lock.unlock()
    }

    func request() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequest
    }

    func body() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return recordedBody
    }

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
