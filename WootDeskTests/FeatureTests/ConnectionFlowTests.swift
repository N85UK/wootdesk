import Testing
import Foundation
@testable import WootDesk

@Suite("Connection Setup Flow Tests")
struct ConnectionFlowTests {

    @MainActor
    private func makeState(url: String = "chatwoot.example.com", token: String = "token") -> ConnectionViewState {
        ConnectionViewState(initialURL: url, initialToken: token)
    }

    @Test("A single returned account is selected without prompting")
    @MainActor
    func testSingleAccountSkipsPicker() async {
        let state = makeState()
        let client = StubChatwootAPI(
            profileOutcome: .success(.init(name: "Sample Agent", accounts: [PreviewData.singleAccount]))
        )

        let outcome = await state.validate(using: client, isDebug: false)

        guard case .singleAccount(let account, _, let url, let token) = outcome else {
            #expect(Bool(false), "Expected a single-account outcome, got \(outcome)")
            return
        }
        #expect(account.id == PreviewData.singleAccount.id)
        #expect(url.absoluteString == "https://chatwoot.example.com")
        #expect(token == "token")
        #expect(state.isSelectingAccount == false)
        #expect(state.errorMessage == nil)
    }

    @Test("Several returned accounts move the flow into account selection")
    @MainActor
    func testMultipleAccountsShowPicker() async {
        let state = makeState()
        let client = StubChatwootAPI(
            profileOutcome: .success(.init(name: "Sample Agent", accounts: PreviewData.multipleAccounts))
        )

        let outcome = await state.validate(using: client, isDebug: false)

        guard case .multipleAccounts(let accounts, _, _, _) = outcome else {
            #expect(Bool(false), "Expected a multiple-account outcome, got \(outcome)")
            return
        }
        #expect(accounts.count == 3)
        #expect(state.isSelectingAccount == true)
        #expect(state.discoveredAccounts.count == 3)
    }

    @Test("An invalid token reports an authentication failure and keeps entered values")
    @MainActor
    func testInvalidTokenReportsFailure() async {
        let state = makeState(url: "chatwoot.example.com", token: "wrong-token")
        let client = StubChatwootAPI(profileOutcome: .failure(.unauthorized))

        let outcome = await state.validate(using: client, isDebug: false)

        guard case .failure(let message) = outcome else {
            #expect(Bool(false), "Expected a failure outcome, got \(outcome)")
            return
        }
        #expect(message == APIError.unauthorized.errorDescription)
        #expect(state.errorMessage == message)
        // Non-secret input is retained so the user can correct just the token.
        #expect(state.serverURLString == "chatwoot.example.com")
        #expect(state.isValidating == false)
    }

    @Test("An empty token is rejected before any request is made")
    @MainActor
    func testEmptyTokenRejectedLocally() async {
        let state = makeState(token: "   ")
        let client = StubChatwootAPI(profileOutcome: .failure(.serverError(statusCode: 500)))

        let outcome = await state.validate(using: client, isDebug: false)

        guard case .failure = outcome else {
            #expect(Bool(false), "Expected a local validation failure")
            return
        }
        #expect(state.errorMessage?.contains("access token") == true)
    }

    @Test("A plain HTTP server address is rejected outside debug localhost")
    @MainActor
    func testPlainHTTPRejected() async {
        let state = makeState(url: "http://chatwoot.example.com")
        let client = StubChatwootAPI()

        let outcome = await state.validate(using: client, isDebug: false)

        guard case .failure(let message) = outcome else {
            #expect(Bool(false), "Expected HTTPS enforcement to fail validation")
            return
        }
        #expect(message == APIError.insecureScheme.errorDescription)
    }

    @Test("The display name defaults to the validated server host when left blank")
    @MainActor
    func testDisplayNameDefaultsFromProfile() async {
        let state = makeState()
        let client = StubChatwootAPI(
            profileOutcome: .success(.init(name: "Sample Agent", accounts: [PreviewData.singleAccount]))
        )

        _ = await state.validate(using: client, isDebug: false)

        #expect(state.displayName == "chatwoot.example.com")
    }

    @Test("Resetting clears every entered value including the token")
    @MainActor
    func testResetClearsToken() async {
        let state = makeState()
        let client = StubChatwootAPI()
        _ = await state.validate(using: client, isDebug: false)

        state.reset()

        #expect(state.token.isEmpty)
        #expect(state.validatedToken.isEmpty)
        #expect(state.serverURLString.isEmpty)
        #expect(state.discoveredAccounts.isEmpty)
        #expect(state.validatedURL == nil)
    }
}
