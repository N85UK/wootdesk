import Foundation

public protocol PushGatewayRegistrationManaging: Sendable {
    func summary(for profileID: UUID) async throws -> PushGatewayConfigurationSummary?

    func configure(
        baseURL: String,
        apiToken: String,
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) async throws -> PushGatewayConfigurationSummary

    func refreshRegistration(
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) async throws -> PushGatewayConfigurationSummary?

    func removeRegistration(for profileID: UUID) async throws
}

public actor PushGatewayRegistrationManager: PushGatewayRegistrationManaging {
    public static let appTopic = "dev.n85.wootdesk"

    private let api: PushGatewayAPIProtocol
    private let store: PushGatewayConfigurationStore
    private let isDebug: Bool
    private let idempotencyKey: @Sendable () -> String
    private let makeDeviceID: @Sendable () -> UUID

    public init(
        api: PushGatewayAPIProtocol,
        store: PushGatewayConfigurationStore,
        isDebug: Bool,
        idempotencyKey: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
        makeDeviceID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.api = api
        self.store = store
        self.isDebug = isDebug
        self.idempotencyKey = idempotencyKey
        self.makeDeviceID = makeDeviceID
    }

    public func summary(for profileID: UUID) async throws -> PushGatewayConfigurationSummary? {
        try await store.loadConfiguration(for: profileID)?.summary
    }

    public func configure(
        baseURL rawBaseURL: String,
        apiToken rawAPIToken: String,
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) async throws -> PushGatewayConfigurationSummary {
        let baseURL = try PushGatewayRequest.normaliseBaseURL(rawBaseURL, isDebug: isDebug)
        let apiToken = rawAPIToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard apiToken.range(
            of: "^[A-Za-z0-9_-]{43,172}$",
            options: .regularExpression
        ) != nil else {
            throw PushGatewayRegistrationError.missingCredential
        }
        guard !deviceToken.isEmpty else {
            throw PushGatewayRegistrationError.missingDeviceToken
        }

        // Enrolling without this succeeds and then silently receives nothing,
        // so refuse here rather than let the gateway reject the request.
        guard let agentID = profile.agentID else {
            throw PushGatewayRegistrationError.missingAgentIdentity
        }

        let previousConfiguration = try await store.loadConfiguration(for: profile.id)
        let deviceID = previousConfiguration?.deviceID ?? makeDeviceID()
        let request = registrationRequest(
            deviceID: deviceID,
            profile: profile,
            agentID: agentID,
            deviceToken: deviceToken,
            environment: environment
        )

        if let previousConfiguration, previousConfiguration.baseURL != baseURL {
            try await api.deleteRegistration(
                baseURL: previousConfiguration.baseURL,
                apiToken: previousConfiguration.apiToken,
                deviceID: previousConfiguration.deviceID,
                idempotencyKey: idempotencyKey()
            )

            do {
                _ = try await api.createRegistration(
                    baseURL: baseURL,
                    apiToken: apiToken,
                    registration: request,
                    idempotencyKey: idempotencyKey()
                )
            } catch {
                try await store.deleteConfiguration(for: profile.id)
                throw error
            }
        } else if previousConfiguration != nil {
            _ = try await api.updateRegistration(
                baseURL: baseURL,
                apiToken: apiToken,
                registration: request,
                idempotencyKey: idempotencyKey()
            )
        } else {
            _ = try await api.createRegistration(
                baseURL: baseURL,
                apiToken: apiToken,
                registration: request,
                idempotencyKey: idempotencyKey()
            )
        }

        let configuration = PushGatewayConfiguration(
            baseURL: baseURL,
            apiToken: apiToken,
            deviceID: deviceID,
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            environment: environment,
            topic: Self.appTopic
        )

        do {
            try await store.saveConfiguration(configuration, for: profile.id)
        } catch let storageError {
            do {
                try await api.deleteRegistration(
                    baseURL: baseURL,
                    apiToken: apiToken,
                    deviceID: deviceID,
                    idempotencyKey: idempotencyKey()
                )
                try await store.deleteConfiguration(for: profile.id)
            } catch {
                throw PushGatewayRegistrationError.recoveryRequired
            }
            throw storageError
        }

        return configuration.summary
    }

    public func refreshRegistration(
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) async throws -> PushGatewayConfigurationSummary? {
        guard var configuration = try await store.loadConfiguration(for: profile.id) else {
            return nil
        }
        guard !deviceToken.isEmpty else {
            throw PushGatewayRegistrationError.missingDeviceToken
        }
        guard let agentID = profile.agentID else {
            throw PushGatewayRegistrationError.missingAgentIdentity
        }

        let request = registrationRequest(
            deviceID: configuration.deviceID,
            profile: profile,
            agentID: agentID,
            deviceToken: deviceToken,
            environment: environment
        )
        _ = try await api.updateRegistration(
            baseURL: configuration.baseURL,
            apiToken: configuration.apiToken,
            registration: request,
            idempotencyKey: idempotencyKey()
        )

        configuration = PushGatewayConfiguration(
            baseURL: configuration.baseURL,
            apiToken: configuration.apiToken,
            deviceID: configuration.deviceID,
            profileID: profile.id,
            accountID: profile.selectedAccountID,
            environment: environment,
            topic: configuration.topic
        )
        try await store.saveConfiguration(configuration, for: profile.id)
        return configuration.summary
    }

    public func removeRegistration(for profileID: UUID) async throws {
        guard let configuration = try await store.loadConfiguration(for: profileID) else {
            return
        }

        try await api.deleteRegistration(
            baseURL: configuration.baseURL,
            apiToken: configuration.apiToken,
            deviceID: configuration.deviceID,
            idempotencyKey: idempotencyKey()
        )
        try await store.deleteConfiguration(for: profileID)
    }

    private func registrationRequest(
        deviceID: UUID,
        profile: ServerProfile,
        agentID: Int,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) -> PushGatewayDeviceRegistrationRequest {
        PushGatewayDeviceRegistrationRequest(
            deviceId: deviceID,
            profileId: profile.id,
            accountId: profile.selectedAccountID,
            agentId: agentID,
            environment: environment,
            topic: Self.appTopic,
            token: deviceToken.hexadecimalString
        )
    }
}

public enum PushGatewayRegistrationError: LocalizedError, Sendable, Equatable {
    case missingCredential
    case missingDeviceToken
    case missingAgentIdentity
    case noActiveProfile
    case recoveryRequired

    public var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "Enter the device API token issued by your WootDesk Push Gateway."
        case .missingDeviceToken:
            return "WootDesk must register this device with Apple before it can enable remote notifications."
        case .missingAgentIdentity:
            return "WootDesk could not confirm which agent this profile signs in as, so notifications would not reach you. Reconnect the server profile and try again."
        case .noActiveProfile:
            return "Select a Chatwoot server profile before configuring remote notifications."
        case .recoveryRequired:
            return "WootDesk could not safely roll back the push registration. Ask the gateway administrator to remove this device before trying again."
        }
    }
}
