import Testing
import Foundation
@testable import WootDesk

@Suite("Server Profile Persistence Tests")
struct ServerProfilePersistenceTests {

    @Test("ServerProfile JSON round trip encoding and decoding")
    func testServerProfileJSONRoundTrip() throws {
        let profile = ServerProfile(
            id: UUID(),
            displayName: "Acme Production",
            baseURL: URL(string: "https://support.acme.com")!,
            selectedAccountID: 42,
            selectedAccountName: "Global Tier 1",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            lastUsedAt: Date(timeIntervalSince1970: 1700050000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ServerProfile.self, from: data)

        #expect(decoded.id == profile.id)
        #expect(decoded.displayName == profile.displayName)
        #expect(decoded.baseURL == profile.baseURL)
        #expect(decoded.selectedAccountID == profile.selectedAccountID)
        #expect(decoded.selectedAccountName == profile.selectedAccountName)
    }

    @Test("FileServerProfileRepository saves and loads profiles and active profile ID")
    func testFileRepositorySaveAndLoad() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("WootDeskTests_\(UUID().uuidString)")
        let repository = FileServerProfileRepository(customDirectoryURL: tempDir)

        let profile1 = ServerProfile(
            id: UUID(),
            displayName: "Server 1",
            baseURL: URL(string: "https://server1.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Account 1"
        )
        let profile2 = ServerProfile(
            id: UUID(),
            displayName: "Server 2",
            baseURL: URL(string: "https://server2.example.com")!,
            selectedAccountID: 2,
            selectedAccountName: "Account 2"
        )

        try await repository.saveProfiles([profile1, profile2])
        try await repository.saveActiveProfileID(profile2.id)

        let loaded = try await repository.loadProfiles()
        let activeID = try await repository.loadActiveProfileID()

        #expect(loaded.count == 2)
        #expect(loaded.map(\.id) == [profile1.id, profile2.id])
        #expect(activeID == profile2.id)

        // Clean up
        _ = try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("FileServerProfileRepository handles corrupt files by backing up and recovering")
    func testCorruptFileRecovery() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("WootDeskTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let corruptFileURL = tempDir.appendingPathComponent("server_profiles.json")
        let badData = "INVALID_JSON_{{".data(using: .utf8)!
        try badData.write(to: corruptFileURL)

        let repository = FileServerProfileRepository(customDirectoryURL: tempDir)
        let profiles = try await repository.loadProfiles()

        // Should return empty list and not crash
        #expect(profiles.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: corruptFileURL.path))

        let recoveredFiles = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(recoveredFiles.contains(where: { $0.hasPrefix("server_profiles.corrupt.") }))

        // Clean up
        _ = try? FileManager.default.removeItem(at: tempDir)
    }
}
