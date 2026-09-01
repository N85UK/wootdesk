import Foundation

/// Structured, user-safe errors encountered during API operations.
///
/// Under no circumstances should authentication tokens or confidential data
/// be embedded in error messages or descriptions.
///
/// Every message is catalogued. The literal at each call site is the British
/// English wording, so an untranslated language falls back to it.
public enum APIError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case insecureScheme
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String? = nil)
    case offline
    case timedOut
    case tlsFailure
    case networkError(String)
    case decodingError(String)
    case invalidMessageContent
    case invalidSnoozeTime
    case noAccountsAvailable
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(
                localized: "The server URL provided is invalid. Please check the hostname and path.",
                comment: "Shown when a Chatwoot server address cannot be parsed"
            )
        case .insecureScheme:
            return String(
                localized: "HTTPS is required for secure connections to Chatwoot servers. Plain HTTP is only permitted on localhost in debug builds.",
                comment: "Shown when a server address does not use HTTPS"
            )
        case .unauthorized:
            return String(
                localized: "Authentication failed. Please verify that your Chatwoot personal access token is active and valid.",
                comment: "Shown when the Chatwoot server rejects the access token"
            )
        case .forbidden:
            return String(
                localized: "Access denied. Your user profile does not have permission to access this resource or account.",
                comment: "Shown when the agent lacks permission for a Chatwoot resource"
            )
        case .notFound:
            return String(
                localized: "The requested resource was not found on the Chatwoot server. Please check the account ID and server configuration.",
                comment: "Shown when a Chatwoot resource does not exist"
            )
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return String(
                    localized: "Rate limit reached. Please wait \(Int(retryAfter)) seconds before trying again.",
                    comment: "Shown when Chatwoot rate limits a request and states a wait time in seconds"
                )
            }
            return String(
                localized: "Rate limit reached. Please wait a moment before trying again.",
                comment: "Shown when Chatwoot rate limits a request without stating a wait time"
            )
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                return String(
                    localized: "The Chatwoot server reported an error (HTTP \(statusCode)): \(message)",
                    comment: "Shown when Chatwoot returns an error status and a message"
                )
            }
            return String(
                localized: "The Chatwoot server returned an error (HTTP \(statusCode)).",
                comment: "Shown when Chatwoot returns an error status without a message"
            )
        case .offline:
            return String(
                localized: "WootDesk appears to be offline. Check your network connection and try again.",
                comment: "Shown when the device has no network connection"
            )
        case .timedOut:
            return String(
                localized: "The Chatwoot server took too long to respond. Check the server address and try again.",
                comment: "Shown when a request to Chatwoot times out"
            )
        case .tlsFailure:
            return String(
                localized: "A secure connection to the Chatwoot server could not be established. Check the server certificate and system trust settings.",
                comment: "Shown when the TLS handshake with Chatwoot fails"
            )
        case .networkError(let details):
            return String(
                localized: "Network connection error: \(details)",
                comment: "Shown when a network request fails for another reason"
            )
        case .decodingError(let details):
            return String(
                localized: "Failed to process the response from the Chatwoot server: \(details)",
                comment: "Shown when a Chatwoot response cannot be decoded"
            )
        case .invalidMessageContent:
            return String(
                localized: "Enter a reply or private note before sending.",
                comment: "Shown when the agent tries to send an empty message"
            )
        case .invalidSnoozeTime:
            return String(
                localized: "Choose a snooze time in the future.",
                comment: "Shown when the agent chooses a snooze time that has already passed"
            )
        case .noAccountsAvailable:
            return String(
                localized: "The validated user profile is not associated with any active Chatwoot accounts.",
                comment: "Shown when a validated Chatwoot profile has no accounts"
            )
        case .cancelled:
            return String(
                localized: "The network request was cancelled.",
                comment: "Shown when a request is cancelled before it completes"
            )
        }
    }
}
