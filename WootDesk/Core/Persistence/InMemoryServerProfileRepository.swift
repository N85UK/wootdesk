import Foundation

/// In-memory implementation of `ServerProfileRepository` for unit tests and previews.
public actor InMemoryServerProfileRepository: ServerProfileRepository {
    private var profiles: [ServerProfile]
    private var activeProfileID: UUID?

    public init(
        initialProfiles: [ServerProfile] = [],
        initialActiveProfileID: UUID? = nil
    ) {
        self.profiles = initialProfiles
        self.activeProfileID = initialActiveProfileID
    }

    public func loadProfiles() async throws -> [ServerProfile] {
        return profiles
    }

    public func saveProfiles(_ profiles: [ServerProfile]) async throws {
        self.profiles = profiles
    }

    public func loadActiveProfileID() async throws -> UUID? {
        return activeProfileID
    }

    public func saveActiveProfileID(_ id: UUID?) async throws {
        self.activeProfileID = id
    }
}
