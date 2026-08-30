import Foundation

/// Helper for constructing and validating Chatwoot API requests.
public enum APIRequest {
    /// Normalises a user-entered base URL.
    ///
    /// - Parameters:
    ///   - rawURLString: The raw user-provided server URL.
    ///   - isDebug: Whether running in debug mode (enabling localhost HTTP).
    /// - Returns: A validated and normalised base URL.
    public static func normaliseBaseURL(_ rawURLString: String, isDebug: Bool = false) throws -> URL {
        var trimmed = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw APIError.invalidURL
        }

        // Add default https scheme if missing
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
            throw APIError.invalidURL
        }

        if scheme == "http" {
            let normalisedHost = host.lowercased()
            let isLocalhost = normalisedHost == "localhost" || normalisedHost == "127.0.0.1" || normalisedHost == "::1"
            if !isDebug || !isLocalhost {
                throw APIError.insecureScheme
            }
        } else if scheme != "https" {
            throw APIError.insecureScheme
        }

        // Clean trailing slashes while preserving existing path prefix
        var path = parsed.path
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = parsed.port
        components.path = (path == "/" || path.isEmpty) ? "" : path

        guard let normalisedURL = components.url else {
            throw APIError.invalidURL
        }

        return normalisedURL
    }

    /// Builds a URL for an endpoint path appended to the given base URL.
    public static func endpointURL(baseURL: URL, path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let fullURL = baseURL.appendingPathComponent(cleanPath)

        guard var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }

        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let finalURL = components.url else {
            throw APIError.invalidURL
        }

        return finalURL
    }

    /// Builds a URLRequest with the mandatory Chatwoot headers.
    public static func makeRequest(
        url: URL,
        method: String = "GET",
        token: String,
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "api_access_token")
        // Chatwoot also reads HTTP_API_ACCESS_TOKEN, which Rack derives from
        // this hyphenated form. Keep the documented header above and include
        // the alias for reverse proxies that reject underscore header names.
        request.setValue(token, forHTTPHeaderField: "api-access-token")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}
