import Foundation

public enum FixtureLoader {
    public static func loadData(named filename: String) throws -> Data {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension.isEmpty ? "json" : (filename as NSString).pathExtension

        // 1. Try Test Bundle resources
        let bundle = Bundle(for: MockURLProtocol.self)
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return try Data(contentsOf: url)
        }
        if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") {
            return try Data(contentsOf: url)
        }

        // 2. Try file system paths relative to repo root
        let relativePaths = [
            "WootDeskTests/Fixtures/\(name).\(ext)",
            "Fixtures/\(name).\(ext)",
            "\(name).\(ext)"
        ]
        for relPath in relativePaths {
            if FileManager.default.fileExists(atPath: relPath) {
                return try Data(contentsOf: URL(fileURLWithPath: relPath))
            }
        }

        // 3. Try finding relative to this source file
        let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let localURL = sourceURL.appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: localURL.path) {
            return try Data(contentsOf: localURL)
        }

        throw NSError(domain: "FixtureLoader", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Fixture not found: \(filename)"
        ])
    }
}
