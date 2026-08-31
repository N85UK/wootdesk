import Foundation

public protocol PushGatewayConfigurationStore: Sendable {
    func loadConfiguration(for profileID: UUID) async throws -> PushGatewayConfiguration?
    func saveConfiguration(_ configuration: PushGatewayConfiguration, for profileID: UUID) async throws
    func deleteConfiguration(for profileID: UUID) async throws
}

public actor KeychainPushGatewayConfigurationStore: PushGatewayConfigurationStore {
    private let credentialStore: CredentialStore

    public init(
        credentialStore: CredentialStore = KeychainCredentialStore(
            service: "dev.n85.wootdesk.push-gateway"
        )
    ) {
        self.credentialStore = credentialStore
    }

    public func loadConfiguration(for profileID: UUID) throws -> PushGatewayConfiguration? {
        guard let encoded = try credentialStore.loadToken(for: profileID) else {
            return nil
        }
        guard let data = encoded.data(using: .utf8) else {
            throw PushGatewayConfigurationStoreError.invalidStoredConfiguration
        }

        do {
            return try JSONDecoder().decode(PushGatewayConfiguration.self, from: data)
        } catch {
            throw PushGatewayConfigurationStoreError.invalidStoredConfiguration
        }
    }

    public func saveConfiguration(
        _ configuration: PushGatewayConfiguration,
        for profileID: UUID
    ) throws {
        do {
            let data = try JSONEncoder().encode(configuration)
            guard let encoded = String(data: data, encoding: .utf8) else {
                throw PushGatewayConfigurationStoreError.invalidStoredConfiguration
            }
            try credentialStore.saveToken(encoded, for: profileID)
        } catch let error as PushGatewayConfigurationStoreError {
            throw error
        } catch {
            throw PushGatewayConfigurationStoreError.secureStorageFailure
        }
    }

    public func deleteConfiguration(for profileID: UUID) throws {
        do {
            try credentialStore.deleteToken(for: profileID)
        } catch {
            throw PushGatewayConfigurationStoreError.secureStorageFailure
        }
    }
}

public actor InMemoryPushGatewayConfigurationStore: PushGatewayConfigurationStore {
    private var configurations: [UUID: PushGatewayConfiguration]

    public init(configurations: [UUID: PushGatewayConfiguration] = [:]) {
        self.configurations = configurations
    }

    public func loadConfiguration(for profileID: UUID) -> PushGatewayConfiguration? {
        configurations[profileID]
    }

    public func saveConfiguration(
        _ configuration: PushGatewayConfiguration,
        for profileID: UUID
    ) {
        configurations[profileID] = configuration
    }

    public func deleteConfiguration(for profileID: UUID) {
        configurations.removeValue(forKey: profileID)
    }
}

public enum PushGatewayConfigurationStoreError: LocalizedError, Sendable, Equatable {
    case invalidStoredConfiguration
    case secureStorageFailure

    public var errorDescription: String? {
        switch self {
        case .invalidStoredConfiguration:
            return "The saved push gateway settings could not be read from Apple Keychain. Remove and configure notifications again."
        case .secureStorageFailure:
            return "Apple Keychain could not securely save the push gateway settings."
        }
    }
}
