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
    /// Omitted from the encoded body when absent, which the gateway accepts.
    /// A registration without it cannot be matched to an assigned
    /// conversation, so the gateway excludes and reports it.
    public let agentId: Int?
    public let environment: PushGatewayEnvironment
    public let topic: String
    public let token: String

    public init(
        deviceId: UUID,
        profileId: UUID,
        accountId: Int,
        agentId: Int? = nil,
        environment: PushGatewayEnvironment,
        topic: String,
        token: String
    ) {
        self.deviceId = deviceId
        self.profileId = profileId
        self.accountId = accountId
        self.agentId = agentId
        self.environment = environment
        self.topic = topic
        self.token = token
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
