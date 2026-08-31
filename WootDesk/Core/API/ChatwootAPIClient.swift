import Foundation
import os

/// Actor-backed implementation of `ChatwootAPIProtocol` using `URLSession`.
public actor ChatwootAPIClient: ChatwootAPIProtocol {
    private static let messagePageSize = 20
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

    public func fetchMessages(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        beforeMessageID: Int? = nil
    ) async throws -> ConversationMessagePage {
        let queryItems = beforeMessageID.map { [URLQueryItem(name: "before", value: String($0))] }
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)/messages",
            queryItems: queryItems
        )
        let request = APIRequest.makeRequest(url: endpoint, method: "GET", token: token)

        AppLogger.network.debug("Fetching a page of Chatwoot conversation messages.")
        let data = try await perform(request: request)

        do {
            let envelope = try JSONDecoder().decode(ChatwootMessageListResponseDTO.self, from: data)
            let messages = try envelope.messages.map {
                try $0.toDomain(allowsInsecureLocalhost: isDebug)
            }
            return ConversationMessagePage(
                messages: messages,
                hasOlderMessages: messages.count >= Self.messagePageSize
            )
        } catch let apiError as APIError {
            throw apiError
        } catch {
            AppLogger.network.error("The Chatwoot message response could not be decoded.")
            throw APIError.decodingError("The server returned message data in an unsupported format.")
        }
    }

    public func createMessage(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        content: String,
        isPrivate: Bool,
        attachments: [OutgoingMessageAttachment]
    ) async throws -> ConversationMessage {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty || !attachments.isEmpty else {
            throw APIError.invalidMessageContent
        }

        guard attachments.count <= OutgoingMessageAttachment.maximumCount else {
            throw AttachmentSelectionError.tooManyFiles
        }
        guard attachments.reduce(0, { $0 + $1.data.count }) <= OutgoingMessageAttachment.maximumTotalBytes else {
            throw AttachmentSelectionError.totalSizeExceeded
        }

        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/\(accountID)/conversations/\(conversationID)/messages"
        )
        let request: URLRequest
        if attachments.isEmpty {
            let payload = CreateMessageRequestDTO(
                content: trimmedContent,
                messageType: "outgoing",
                isPrivate: isPrivate,
                contentType: "text",
                contentAttributes: [:]
            )
            let body = try JSONEncoder().encode(payload)
            request = APIRequest.makeRequest(
                url: endpoint,
                method: "POST",
                token: token,
                body: body
            )
        } else {
            let multipart = MultipartMessageBody(
                content: trimmedContent,
                isPrivate: isPrivate,
                attachments: attachments
            )
            request = APIRequest.makeRequest(
                url: endpoint,
                method: "POST",
                token: token,
                body: multipart.data,
                contentType: "multipart/form-data; boundary=\(multipart.boundary)"
            )
        }

        AppLogger.network.debug("Creating a Chatwoot conversation message.")
        let data = try await perform(request: request)

        do {
            let response = try JSONDecoder().decode(ChatwootCreatedMessageResponseDTO.self, from: data)
            return try response.message.toDomain(allowsInsecureLocalhost: isDebug)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            AppLogger.network.error("The created Chatwoot message response could not be decoded.")
            throw APIError.decodingError("The server returned the created message in an unsupported format.")
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

private struct CreateMessageRequestDTO: Encodable, Sendable {
    let content: String
    let messageType: String
    let isPrivate: Bool
    let contentType: String
    let contentAttributes: [String: String]

    enum CodingKeys: String, CodingKey {
        case content
        case messageType = "message_type"
        case isPrivate = "private"
        case contentType = "content_type"
        case contentAttributes = "content_attributes"
    }
}

private struct MultipartMessageBody: Sendable {
    let boundary: String
    let data: Data

    init(
        content: String,
        isPrivate: Bool,
        attachments: [OutgoingMessageAttachment]
    ) {
        let boundary = "WootDesk-\(UUID().uuidString)"
        var body = Data()
        body.appendMultipartField(name: "content", value: content, boundary: boundary)
        body.appendMultipartField(name: "message_type", value: "outgoing", boundary: boundary)
        body.appendMultipartField(name: "private", value: isPrivate ? "true" : "false", boundary: boundary)
        body.appendMultipartField(name: "content_type", value: "text", boundary: boundary)

        for attachment in attachments {
            body.appendMultipartFile(
                name: "attachments[]",
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                fileData: attachment.data,
                boundary: boundary
            )
        }

        body.append(Data("--\(boundary)--\r\n".utf8))
        self.boundary = boundary
        self.data = body
    }
}

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        append(Data(value.utf8))
        append(Data("\r\n".utf8))
    }

    mutating func appendMultipartFile(
        name: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".utf8
        ))
        append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        append(fileData)
        append(Data("\r\n".utf8))
    }
}
