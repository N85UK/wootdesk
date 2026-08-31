import Foundation

public enum PushGatewayRequest {
    public static func normaliseBaseURL(_ rawValue: String, isDebug: Bool) throws -> URL {
        var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PushGatewayAPIError.invalidURL
        }

        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }

        guard let parsed = URLComponents(string: trimmed),
              let scheme = parsed.scheme?.lowercased(),
              let host = parsed.host,
              !host.isEmpty,
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              parsed.user == nil,
              parsed.password == nil,
              parsed.query == nil,
              parsed.fragment == nil else {
            throw PushGatewayAPIError.invalidURL
        }

        if scheme == "http" {
            let normalisedHost = host.lowercased()
            let isLocalhost = normalisedHost == "localhost"
                || normalisedHost == "127.0.0.1"
                || normalisedHost == "::1"
            guard isDebug && isLocalhost else {
                throw PushGatewayAPIError.insecureScheme
            }
        } else if scheme != "https" {
            throw PushGatewayAPIError.insecureScheme
        }

        var path = parsed.path
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = parsed.port
        components.path = (path == "/" || path.isEmpty) ? "" : path

        guard let url = components.url else {
            throw PushGatewayAPIError.invalidURL
        }
        return url
    }

    public static func endpointURL(baseURL: URL, path: String) throws -> URL {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = baseURL.appendingPathComponent(cleanPath)
        guard url.scheme != nil, url.host != nil else {
            throw PushGatewayAPIError.invalidURL
        }
        return url
    }

    public static func makeRequest(
        url: URL,
        method: String,
        apiToken: String,
        idempotencyKey: String,
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
