import Foundation

public protocol PushGatewayAPIProtocol: Sendable {
    func createRegistration(
        baseURL: URL,
        apiToken: String,
        registration: PushGatewayDeviceRegistrationRequest,
        idempotencyKey: String
    ) async throws -> PushGatewayDeviceRegistration

    func updateRegistration(
        baseURL: URL,
        apiToken: String,
        registration: PushGatewayDeviceRegistrationRequest,
        idempotencyKey: String
    ) async throws -> PushGatewayDeviceRegistration

    func deleteRegistration(
        baseURL: URL,
        apiToken: String,
        deviceID: UUID,
        idempotencyKey: String
    ) async throws
}

public enum PushGatewayAPIError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case insecureScheme
    case invalidRequest
    case unauthorised
    case notFound
    case conflict
    case payloadTooLarge
    case rateLimited(retryAfter: TimeInterval?)
    case unavailable
    case offline
    case timedOut
    case tlsFailure
    case malformedResponse
    case cancelled
    case networkFailure

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The push gateway address is invalid. Check the hostname and path."
        case .insecureScheme:
            return "HTTPS is required for the push gateway. Plain HTTP is permitted only for localhost in debug builds."
        case .invalidRequest:
            return "The push gateway rejected the device registration. Check the gateway configuration."
        case .unauthorised:
            return "The push gateway credential was rejected. Check that it is active and authorised for device registration."
        case .notFound:
            return "The device registration could not be found on the push gateway."
        case .conflict:
            return "The push gateway reported a conflicting device registration. Remove the existing registration and try again."
        case .payloadTooLarge:
            return "The push gateway rejected an oversized registration request."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "The push gateway rate limit was reached. Try again in \(Int(retryAfter)) seconds."
            }
            return "The push gateway rate limit was reached. Wait a moment and try again."
        case .unavailable:
            return "The push gateway is temporarily unavailable. Try again later."
        case .offline:
            return "WootDesk appears to be offline. Check the network connection and try again."
        case .timedOut:
            return "The push gateway took too long to respond. Try again."
        case .tlsFailure:
            return "A secure connection to the push gateway could not be established. Check its certificate and system trust settings."
        case .malformedResponse:
            return "The push gateway returned data WootDesk could not understand."
        case .cancelled:
            return "The push gateway request was cancelled."
        case .networkFailure:
            return "WootDesk could not connect to the push gateway."
        }
    }
}
