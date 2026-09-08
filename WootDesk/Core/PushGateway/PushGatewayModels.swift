import Foundation

public enum PushGatewayEnvironment: String, Codable, Sendable, CaseIterable {
    case development
    case production

    public static var current: PushGatewayEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}

public struct PushGatewayDeviceRegistrationRequest: Codable, Equatable, Sendable {
    public let deviceId: UUID
    public let profileId: UUID
    public let accountId: Int
    /// The Chatwoot user this device belongs to. Not optional: a registration
    /// without one is excluded from every assigned conversation, and when that
    /// was expressible the app reported delivery enabled while receiving
    /// nothing. The type no longer allows the state to be constructed.
    public let agentId: Int
    public let environment: PushGatewayEnvironment
    public let topic: String
    public let token: String
    /// The Chatwoot server this profile signs in to.
    ///
    /// The gateway uses it to work out which configured deployment the device
    /// is enrolling against. An account number is unique only within one
    /// Chatwoot, so without this a gateway serving two deployments cannot tell
    /// an event for account 1 on one server from account 1 on the other, and
    /// could notify a device about a server it has no relationship with.
    ///
    /// Not a secret: it is the address the agent already signs in to.
    public let baseUrl: String

    public init(
        deviceId: UUID,
        profileId: UUID,
        accountId: Int,
        agentId: Int,
        environment: PushGatewayEnvironment,
        topic: String,
        token: String,
        baseUrl: String
    ) {
        self.deviceId = deviceId
        self.profileId = profileId
        self.accountId = accountId
        self.agentId = agentId
        self.environment = environment
        self.topic = topic
        self.token = token
        self.baseUrl = baseUrl
    }
}

public struct PushGatewayDeviceRegistration: Codable, Equatable, Sendable {
    public let deviceId: UUID
    public let profileId: UUID
    public let accountId: Int
    public let environment: PushGatewayEnvironment
    public let topic: String
    public let updatedAt: String
}

struct PushGatewayRegistrationEnvelope: Decodable, Sendable {
    let registration: PushGatewayDeviceRegistration
}

public struct PushGatewayConfiguration: Codable, Equatable, Sendable {
    public let baseURL: URL
    public let apiToken: String
    public let deviceID: UUID
    public let profileID: UUID
    public let accountID: Int
    public let environment: PushGatewayEnvironment
    public let topic: String
    public let updatedAt: Date

    public init(
        baseURL: URL,
        apiToken: String,
        deviceID: UUID,
        profileID: UUID,
        accountID: Int,
        environment: PushGatewayEnvironment,
        topic: String,
        updatedAt: Date = Date()
    ) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.deviceID = deviceID
        self.profileID = profileID
        self.accountID = accountID
        self.environment = environment
        self.topic = topic
        self.updatedAt = updatedAt
    }

    public var summary: PushGatewayConfigurationSummary {
        PushGatewayConfigurationSummary(
            baseURL: baseURL,
            deviceID: deviceID,
            profileID: profileID,
            accountID: accountID,
            environment: environment,
            updatedAt: updatedAt
        )
    }
}

public struct PushGatewayConfigurationSummary: Equatable, Sendable {
    public let baseURL: URL
    public let deviceID: UUID
    public let profileID: UUID
    public let accountID: Int
    public let environment: PushGatewayEnvironment
    public let updatedAt: Date

    public var displayHost: String {
        baseURL.host ?? baseURL.absoluteString
    }
}

public extension Data {
    var hexadecimalString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
