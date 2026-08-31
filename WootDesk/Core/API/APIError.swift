import Foundation

/// Structured, user-safe errors encountered during API operations.
///
/// Under no circumstances should authentication tokens or confidential data
/// be embedded in error messages or descriptions.
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
    case noAccountsAvailable
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL provided is invalid. Please check the hostname and path."
        case .insecureScheme:
            return "HTTPS is required for secure connections to Chatwoot servers. Plain HTTP is only permitted on localhost in debug builds."
        case .unauthorized:
            return "Authentication failed. Please verify that your Chatwoot personal access token is active and valid."
        case .forbidden:
            return "Access denied. Your user profile does not have permission to access this resource or account."
        case .notFound:
            return "The requested resource was not found on the Chatwoot server. Please check the account ID and server configuration."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limit reached. Please wait \(Int(retryAfter)) seconds before trying again."
            }
            return "Rate limit reached. Please wait a moment before trying again."
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "The Chatwoot server reported an error (HTTP \(statusCode)): \(message)"
            }
            return "The Chatwoot server returned an error (HTTP \(statusCode))."
        case .offline:
            return "WootDesk appears to be offline. Check your network connection and try again."
        case .timedOut:
            return "The Chatwoot server took too long to respond. Check the server address and try again."
        case .tlsFailure:
            return "A secure connection to the Chatwoot server could not be established. Check the server certificate and system trust settings."
        case .networkError(let details):
            return "Network connection error: \(details)"
        case .decodingError(let details):
            return "Failed to process the response from the Chatwoot server: \(details)"
        case .invalidMessageContent:
            return "Enter a reply or private note before sending."
        case .noAccountsAvailable:
            return "The validated user profile is not associated with any active Chatwoot accounts."
        case .cancelled:
            return "The network request was cancelled."
        }
    }
}
