import Foundation
import SwiftUI

/// Container for shared service dependencies injected through the SwiftUI environment.
public struct AppEnvironment: Sendable {
    public let apiClient: ChatwootAPIProtocol
    public let profileRepository: ServerProfileRepository
    public let credentialStore: CredentialStore
    public let aiProvider: AIProvider
    public let isDebug: Bool

    public init(
        apiClient: ChatwootAPIProtocol,
        profileRepository: ServerProfileRepository,
        credentialStore: CredentialStore,
        aiProvider: AIProvider = MockAIProvider(),
        isDebug: Bool = false
    ) {
        self.apiClient = apiClient
        self.profileRepository = profileRepository
        self.credentialStore = credentialStore
        self.aiProvider = aiProvider
        self.isDebug = isDebug
    }

    /// The live environment: real networking, Keychain, and on-disk profile storage.
    public static func live() -> AppEnvironment {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif

        return AppEnvironment(
            apiClient: ChatwootAPIClient(isDebug: isDebug),
            profileRepository: FileServerProfileRepository(),
            credentialStore: KeychainCredentialStore(),
            aiProvider: MockAIProvider(),
            isDebug: isDebug
        )
    }

    /// An in-memory environment for unit tests and SwiftUI previews.
    ///
    /// Nothing here touches the Keychain, the file system, or the network.
    public static func preview(
        profiles: [ServerProfile] = [],
        activeProfileID: UUID? = nil,
        tokens: [UUID: String] = [:],
        apiClient: ChatwootAPIProtocol = StubChatwootAPI()
    ) -> AppEnvironment {
        AppEnvironment(
            apiClient: apiClient,
            profileRepository: InMemoryServerProfileRepository(
                initialProfiles: profiles,
                initialActiveProfileID: activeProfileID
            ),
            credentialStore: InMemoryCredentialStore(initialTokens: tokens),
            aiProvider: MockAIProvider(),
            isDebug: true
        )
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    /// The app always injects an environment explicitly. This fallback exists only so
    /// that a view rendered outside that hierarchy still behaves sensibly: the live
    /// environment normally, and an inert in-memory one inside Xcode Previews so
    /// previews never reach the Keychain or Application Support.
    static let defaultValue: AppEnvironment = {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .preview()
        }
        return .live()
    }()
}

extension EnvironmentValues {
    public var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
