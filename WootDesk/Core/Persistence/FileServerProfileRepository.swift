import Foundation
import os

/// Atomically persists server profile metadata as JSON within the Application Support directory.
public actor FileServerProfileRepository: ServerProfileRepository {
    private let directoryURL: URL
    private let profilesFileURL: URL
    private let activeProfileFileURL: URL
    private let fileManager: FileManager

    public init(
        customDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let rootDir: URL
        if let customDirectoryURL {
            rootDir = customDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            rootDir = appSupport.appendingPathComponent("WootDesk", isDirectory: true)
        }
        self.directoryURL = rootDir
        self.profilesFileURL = rootDir.appendingPathComponent("server_profiles.json")
        self.activeProfileFileURL = rootDir.appendingPathComponent("active_profile_id.json")
    }

    public func loadProfiles() async throws -> [ServerProfile] {
        guard fileManager.fileExists(atPath: profilesFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: profilesFileURL)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ServerProfile].self, from: data)
        } catch let decodingError as DecodingError {
            AppLogger.persistence.error("The saved server profile file is corrupt and cannot be decoded.")
            try backupCorruptedFile()
            AppLogger.persistence.debug("Profile decoding failure type: \(String(describing: decodingError), privacy: .private(mask: .hash))")
            return []
        }
    }

    public func saveProfiles(_ profiles: [ServerProfile]) async throws {
        try ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profiles)

        try data.write(to: profilesFileURL, options: .atomic)
        AppLogger.persistence.debug("Saved \(profiles.count) server profiles atomically.")
    }

    public func loadActiveProfileID() async throws -> UUID? {
        guard fileManager.fileExists(atPath: activeProfileFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: activeProfileFileURL)
            let decoder = JSONDecoder()
            let id = try decoder.decode(UUID.self, from: data)
            return id
        } catch let decodingError as DecodingError {
            AppLogger.persistence.error("The saved active profile preference is corrupt and will be ignored.")
            try backupCorruptedActiveProfileFile()
            AppLogger.persistence.debug("Active profile decoding failure type: \(String(describing: decodingError), privacy: .private(mask: .hash))")
            return nil
        }
    }

    public func saveActiveProfileID(_ id: UUID?) async throws {
        try ensureDirectoryExists()

        guard let id else {
            if fileManager.fileExists(atPath: activeProfileFileURL.path) {
                try fileManager.removeItem(at: activeProfileFileURL)
            }
            return
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(id)
        try data.write(to: activeProfileFileURL, options: .atomic)
    }

    // MARK: - Private Helpers

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private func backupCorruptedFile() throws {
        let backupURL = directoryURL.appendingPathComponent("server_profiles.corrupt.\(UUID().uuidString).json")
        try fileManager.moveItem(at: profilesFileURL, to: backupURL)
        AppLogger.persistence.info("The corrupted profile file was preserved as a recovery copy.")
    }

    private func backupCorruptedActiveProfileFile() throws {
        let backupURL = directoryURL.appendingPathComponent("active_profile_id.corrupt.\(UUID().uuidString).json")
        try fileManager.moveItem(at: activeProfileFileURL, to: backupURL)
        AppLogger.persistence.info("The corrupted active profile preference was preserved as a recovery copy.")
    }
}
