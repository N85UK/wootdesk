import Foundation
import os

/// Actor-backed implementation of `ChatwootAPIProtocol` using `URLSession`.
public actor ChatwootAPIClient: ChatwootAPIProtocol {
    private let session: URLSession
    private let isDebug: Bool

    public init(session: URLSession = .shared, isDebug: Bool = false) {
        self.session = session
        self.isDebug = isDebug
    }

    public func fetchProfile(
        baseURL: URL,
        token: String
    ) async throws -> (profileName: String, accounts: [ChatwootAccount]) {
        let endpoint = try APIRequest.endpointURL(baseURL: baseURL, path: "api/v1/profile")
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching the current Chatwoot profile.")

        let data = try await perform(request: request)

        do {
            let decoder = JSONDecoder()
            let profileDTO = try decoder.decode(ChatwootProfileDTO.self, from: data)

            let domainAccounts = profileDTO.accounts?.map { $0.toDomain() } ?? []
            guard !domainAccounts.isEmpty else {
                throw APIError.noAccountsAvailable
            }

            let profileName = profileDTO.name ?? profileDTO.email ?? baseURL.host ?? "Chatwoot User"
            return (profileName: profileName, accounts: domainAccounts)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            AppLogger.network.error("The Chatwoot profile response could not be decoded.")
            throw APIError.decodingError("The server returned profile data in an unsupported format.")
        }
    }

    public func fetchConversations(
        baseURL: URL,
        token: String,
        accountID: Int,
        status: ConversationStatus? = nil,
        page: Int = 1
    ) async throws -> [Conversation] {
        let requestedStatus = status?.rawValue ?? "all"
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "status", value: requestedStatus)
        ]

        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations",
            queryItems: queryItems
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching a page of Chatwoot conversations.")

        let data = try await perform(request: request)

        do {
            let decoder = JSONDecoder()
            let envelope = try decoder.decode(ChatwootConversationListResponseDTO.self, from: data)
            return envelope.conversations.map { $0.toDomain(defaultAccountID: accountID) }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            AppLogger.network.error("The Chatwoot conversation response could not be decoded.")
            throw APIError.decodingError("The server returned conversation data in an unsupported format.")
        }
    }

    // MARK: - Private Request Execution

    private func perform(request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid non-HTTP response received.")
            }

            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 429:
                let retryAfterStr = httpResponse.value(forHTTPHeaderField: "Retry-After")
                let retryAfter = retryAfterStr.flatMap(Double.init)
                throw APIError.rateLimited(retryAfter: retryAfter)
            case 500...599:
                let message = parseErrorMessage(from: data)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
            default:
                let message = parseErrorMessage(from: data)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let apiError as APIError {
            throw apiError
        } catch let urlError as URLError {
            switch urlError.code {
            case .cancelled:
                throw APIError.cancelled
            case .notConnectedToInternet, .internationalRoamingOff, .dataNotAllowed:
                throw APIError.offline
            case .timedOut:
                throw APIError.timedOut
            case .secureConnectionFailed,
                 .serverCertificateHasBadDate,
                 .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid,
                 .clientCertificateRejected,
                 .clientCertificateRequired,
                 .appTransportSecurityRequiresSecureConnection:
                throw APIError.tlsFailure
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .networkConnectionLost:
                throw APIError.networkError("The Chatwoot server could not be reached.")
            default:
                throw APIError.networkError("The request could not be completed.")
            }
        } catch {
            throw APIError.networkError("The request could not be completed.")
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String {
                return sanitisedServerMessage(message)
            }
            if let error = json["error"] as? String {
                return sanitisedServerMessage(error)
            }
            if let errors = json["errors"] as? [String] {
                return sanitisedServerMessage(errors.joined(separator: ", "))
            }
        }
        return nil
    }

    private func sanitisedServerMessage(_ message: String) -> String? {
        let flattened = message
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !flattened.isEmpty else { return nil }
        return String(flattened.prefix(300))
    }
}
