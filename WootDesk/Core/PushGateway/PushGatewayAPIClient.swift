import Foundation

public actor PushGatewayAPIClient: PushGatewayAPIProtocol {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func createRegistration(
        baseURL: URL,
        apiToken: String,
        registration: PushGatewayDeviceRegistrationRequest,
        idempotencyKey: String
    ) async throws -> PushGatewayDeviceRegistration {
        let endpoint = try PushGatewayRequest.endpointURL(baseURL: baseURL, path: "v1/devices")
        let body = try encode(registration)
        let request = PushGatewayRequest.makeRequest(
            url: endpoint,
            method: "POST",
            apiToken: apiToken,
            idempotencyKey: idempotencyKey,
            body: body
        )
        return try await performRegistrationRequest(request, expectedStatus: 201)
    }

    public func updateRegistration(
        baseURL: URL,
        apiToken: String,
        registration: PushGatewayDeviceRegistrationRequest,
        idempotencyKey: String
    ) async throws -> PushGatewayDeviceRegistration {
        let endpoint = try PushGatewayRequest.endpointURL(
            baseURL: baseURL,
            path: "v1/devices/\(registration.deviceId.uuidString.lowercased())"
        )
        let update = PushGatewayDeviceRegistrationUpdate(
            profileId: registration.profileId,
            accountId: registration.accountId,
            environment: registration.environment,
            topic: registration.topic,
            token: registration.token
        )
        let body = try encode(update)
        let request = PushGatewayRequest.makeRequest(
            url: endpoint,
            method: "PUT",
            apiToken: apiToken,
            idempotencyKey: idempotencyKey,
            body: body
        )
        return try await performRegistrationRequest(request, expectedStatus: 200)
    }

    public func deleteRegistration(
        baseURL: URL,
        apiToken: String,
        deviceID: UUID,
        idempotencyKey: String
    ) async throws {
        let endpoint = try PushGatewayRequest.endpointURL(
            baseURL: baseURL,
            path: "v1/devices/\(deviceID.uuidString.lowercased())"
        )
        let request = PushGatewayRequest.makeRequest(
            url: endpoint,
            method: "DELETE",
            apiToken: apiToken,
            idempotencyKey: idempotencyKey
        )
        let (_, response) = try await send(request)
        guard response.statusCode == 204 || response.statusCode == 404 else {
            throw mapHTTPError(response)
        }
    }

    private func performRegistrationRequest(
        _ request: URLRequest,
        expectedStatus: Int
    ) async throws -> PushGatewayDeviceRegistration {
        let (data, response) = try await send(request)
        guard response.statusCode == expectedStatus else {
            throw mapHTTPError(response)
        }

        do {
            return try JSONDecoder().decode(PushGatewayRegistrationEnvelope.self, from: data).registration
        } catch {
            throw PushGatewayAPIError.malformedResponse
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PushGatewayAPIError.malformedResponse
            }
            return (data, httpResponse)
        } catch let error as PushGatewayAPIError {
            throw error
        } catch let error as URLError {
            throw mapNetworkError(error)
        } catch is CancellationError {
            throw PushGatewayAPIError.cancelled
        } catch {
            throw PushGatewayAPIError.networkFailure
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw PushGatewayAPIError.invalidRequest
        }
    }

    private func mapHTTPError(_ response: HTTPURLResponse) -> PushGatewayAPIError {
        switch response.statusCode {
        case 400:
            .invalidRequest
        case 401, 403:
            .unauthorised
        case 404:
            .notFound
        case 409:
            .conflict
        case 413:
            .payloadTooLarge
        case 429:
            .rateLimited(retryAfter: response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init))
        case 500...599:
            .unavailable
        default:
            .malformedResponse
        }
    }

    private func mapNetworkError(_ error: URLError) -> PushGatewayAPIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            .offline
        case .timedOut:
            .timedOut
        case .cancelled:
            .cancelled
        case .secureConnectionFailed, .serverCertificateHasBadDate,
             .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired:
            .tlsFailure
        default:
            .networkFailure
        }
    }
}

private struct PushGatewayDeviceRegistrationUpdate: Encodable, Sendable {
    let profileId: UUID
    let accountId: Int
    let environment: PushGatewayEnvironment
    let topic: String
    let token: String
}
