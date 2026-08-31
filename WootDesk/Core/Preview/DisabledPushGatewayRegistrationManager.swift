import Foundation

/// Inert push gateway boundary for previews, UI tests, and tests that do not opt in.
///
/// It never reaches the network or Apple Keychain and never reports a simulated
/// registration success.
public actor DisabledPushGatewayRegistrationManager: PushGatewayRegistrationManaging {
    public init() {}

    public func summary(for profileID: UUID) -> PushGatewayConfigurationSummary? {
        nil
    }

    public func configure(
        baseURL: String,
        apiToken: String,
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) throws -> PushGatewayConfigurationSummary {
        throw PushGatewayAPIError.unavailable
    }

    public func refreshRegistration(
        profile: ServerProfile,
        deviceToken: Data,
        environment: PushGatewayEnvironment
    ) -> PushGatewayConfigurationSummary? {
        nil
    }

    public func removeRegistration(for profileID: UUID) {}
}
