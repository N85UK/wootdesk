import Testing
import Foundation
@testable import WootDesk

@Suite("URL Normalisation and Request Construction Tests")
struct URLAndRequestTests {

    @Test("Trims whitespace and adds default https scheme")
    func testNormaliseURLTrimsAndAddsScheme() throws {
        let raw = "   chatwoot.example.com/support/   "
        let url = try APIRequest.normaliseBaseURL(raw, isDebug: false)
        #expect(url.absoluteString == "https://chatwoot.example.com/support")
    }

    @Test("Preserves base-URL path prefix")
    func testNormaliseURLPreservesPathPrefix() throws {
        let raw = "https://app.company.org/helpdesk/"
        let url = try APIRequest.normaliseBaseURL(raw, isDebug: false)
        #expect(url.absoluteString == "https://app.company.org/helpdesk")
        #expect(url.path == "/helpdesk")
    }

    @Test("Rejects HTTP scheme in release mode")
    func testRejectsHTTPInRelease() {
        let raw = "http://chatwoot.example.com"
        #expect(throws: APIError.insecureScheme) {
            _ = try APIRequest.normaliseBaseURL(raw, isDebug: false)
        }
    }

    @Test("Permits HTTP only for localhost in debug mode")
    func testPermitsLocalhostHTTPInDebug() throws {
        let rawLocal = "http://localhost:3000"
        let url = try APIRequest.normaliseBaseURL(rawLocal, isDebug: true)
        #expect(url.absoluteString == "http://localhost:3000")

        let rawIP = "http://127.0.0.1:3000"
        let ipURL = try APIRequest.normaliseBaseURL(rawIP, isDebug: true)
        #expect(ipURL.absoluteString == "http://127.0.0.1:3000")

        let rawRemote = "http://remote-server.com"
        #expect(throws: APIError.insecureScheme) {
            _ = try APIRequest.normaliseBaseURL(rawRemote, isDebug: true)
        }
    }

    @Test("Rejects malformed hostnames or empty input")
    func testRejectsMalformedURLs() {
        #expect(throws: APIError.invalidURL) {
            _ = try APIRequest.normaliseBaseURL("   ", isDebug: false)
        }

        #expect(throws: APIError.invalidURL) {
            _ = try APIRequest.normaliseBaseURL("https://user:password@chatwoot.example.com", isDebug: false)
        }

        #expect(throws: APIError.invalidURL) {
            _ = try APIRequest.normaliseBaseURL("https://chatwoot.example.com?token=value", isDebug: false)
        }

        #expect(throws: APIError.invalidURL) {
            _ = try APIRequest.normaliseBaseURL("https://chatwoot.example.com#fragment", isDebug: false)
        }
    }

    @Test("Correctly constructs profile endpoint URL without duplicate slashes")
    func testProfileEndpointConstruction() throws {
        let baseURL = URL(string: "https://chatwoot.example.com/custom-path")!
        let endpoint = try APIRequest.endpointURL(baseURL: baseURL, path: "api/v1/profile")
        #expect(endpoint.absoluteString == "https://chatwoot.example.com/custom-path/api/v1/profile")
    }

    @Test("Correctly constructs conversation endpoint URL with query parameters")
    func testConversationEndpointConstruction() throws {
        let baseURL = URL(string: "https://chatwoot.example.com")!
        let queryItems = [
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "status", value: "open")
        ]
        let endpoint = try APIRequest.endpointURL(
            baseURL: baseURL,
            path: "api/v1/accounts/14/conversations",
            queryItems: queryItems
        )
        #expect(endpoint.path == "/api/v1/accounts/14/conversations")
        #expect(endpoint.query?.contains("page=2") == true)
        #expect(endpoint.query?.contains("status=open") == true)
    }

    @Test("Applies documented and proxy-compatible access-token headers")
    func testMakeRequestHeaders() throws {
        let url = URL(string: "https://chatwoot.example.com/api/v1/profile")!
        let token = "test"
        let request = APIRequest.makeRequest(url: url, method: "GET", token: token)

        #expect(request.value(forHTTPHeaderField: "api_access_token") == token)
        #expect(request.value(forHTTPHeaderField: "api-access-token") == token)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.httpMethod == "GET")
    }
}
