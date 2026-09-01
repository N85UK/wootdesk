import Foundation
import UniformTypeIdentifiers

/// Metadata for an attachment returned with a Chatwoot message.
public struct ConversationAttachment: Identifiable, Hashable, Sendable {
    public let id: String
    public let serverID: Int?
    public let fileType: ConversationAttachmentType
    public let dataURL: URL?
    public let thumbnailURL: URL?
    public let fileSize: Int?
    public let width: Int?
    public let height: Int?
    public let fileExtension: String?

    public init(
        id: String,
        serverID: Int? = nil,
        fileType: ConversationAttachmentType,
        dataURL: URL? = nil,
        thumbnailURL: URL? = nil,
        fileSize: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        fileExtension: String? = nil
    ) {
        self.id = id
        self.serverID = serverID
        self.fileType = fileType
        self.dataURL = dataURL
        self.thumbnailURL = thumbnailURL
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.fileExtension = fileExtension
    }

    /// A short, non-secret label suitable for the attachment button.
    public var displayName: String {
        if let candidate = dataURL?.lastPathComponent.removingPercentEncoding,
           let sanitised = Self.sanitisedFileName(candidate) {
            return sanitised
        }

        if let fileExtension,
           let sanitisedExtension = Self.sanitisedFileName(fileExtension) {
            return String(
                localized: "\(fileType.displayName) attachment.\(sanitisedExtension)",
                comment: "Fallback attachment name built from its type and file extension"
            )
        }

        return String(
            localized: "\(fileType.displayName) attachment",
            comment: "Fallback attachment name built from its type"
        )
    }

    /// Accepts only HTTPS URLs, with a narrow debug-only localhost exception.
    public static func safeRemoteURL(
        _ rawValue: String?,
        allowsInsecureLocalhost: Bool
    ) -> URL? {
        guard let rawValue,
              let components = URLComponents(string: rawValue),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil else {
            return nil
        }

        if scheme == "https" {
            return components.url
        }

        let localHosts = ["localhost", "127.0.0.1", "::1"]
        if allowsInsecureLocalhost,
           scheme == "http",
           localHosts.contains(host.lowercased()) {
            return components.url
        }

        return nil
    }

    private static func sanitisedFileName(_ value: String) -> String? {
        let withoutControls = value.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        let trimmed = String(String.UnicodeScalarView(withoutControls))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(120))
    }
}

/// The attachment categories currently emitted by Chatwoot, with a tolerant fallback.
public enum ConversationAttachmentType: Hashable, Sendable {
    case image
    case audio
    case video
    case file
    case location
    case contact
    case fallback
    case unknown(String?)

    public init(chatwootValue: String?) {
        switch chatwootValue?.lowercased() {
        case "image": self = .image
        case "audio": self = .audio
        case "video": self = .video
        case "file": self = .file
        case "location": self = .location
        case "contact": self = .contact
        case "fallback": self = .fallback
        default: self = .unknown(chatwootValue)
        }
    }

    public var displayName: String {
        switch self {
        case .image: String(localized: "Image", comment: "Attachment type")
        case .audio: String(localized: "Audio", comment: "Attachment type")
        case .video: String(localized: "Video", comment: "Attachment type")
        case .file: String(localized: "File", comment: "Attachment type")
        case .location: String(localized: "Location", comment: "Attachment type")
        case .contact: String(localized: "Contact", comment: "Attachment type")
        case .fallback: String(localized: "Attachment", comment: "Attachment type")
        case .unknown: String(localized: "Attachment", comment: "Attachment type")
        }
    }
}

/// One file selected for an outgoing message. It exists in memory only.
public struct OutgoingMessageAttachment: Identifiable, Hashable, Sendable {
    public static let maximumCount = 15
    public static let maximumTotalBytes = 25 * 1_024 * 1_024

    public let id: UUID
    public let fileName: String
    public let mimeType: String
    public let data: Data

    public init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        data: Data
    ) throws {
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AttachmentSelectionError.invalidFile
        }
        guard !data.isEmpty else {
            throw AttachmentSelectionError.emptyFile
        }
        guard data.count <= Self.maximumTotalBytes else {
            throw AttachmentSelectionError.tooLarge
        }

        self.id = id
        self.fileName = Self.safeUploadFileName(trimmedName)
        self.mimeType = Self.safeMIMEType(mimeType)
        self.data = data
    }

    /// Copies one security-scoped selection into bounded in-memory data.
    public static func load(from url: URL) async throws -> OutgoingMessageAttachment {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard resourceValues.isRegularFile == true else {
                throw AttachmentSelectionError.invalidFile
            }
            if let fileSize = resourceValues.fileSize,
               fileSize > Self.maximumTotalBytes {
                throw AttachmentSelectionError.tooLarge
            }

            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: Self.maximumTotalBytes + 1) ?? Data()
            guard data.count <= Self.maximumTotalBytes else {
                throw AttachmentSelectionError.tooLarge
            }
            let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            return try OutgoingMessageAttachment(
                fileName: url.lastPathComponent,
                mimeType: contentType,
                data: data
            )
        }.value
    }

    private static func safeUploadFileName(_ value: String) -> String {
        let forbidden = CharacterSet.newlines.union(.controlCharacters)
        let scalars = value.unicodeScalars.map { scalar -> Character in
            if forbidden.contains(scalar) || scalar == "\"" || scalar == "\\" {
                return "_"
            }
            return Character(String(scalar))
        }
        let sanitised = String(scalars)
        return String(sanitised.prefix(160))
    }

    private static func safeMIMEType(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$&^_.+-/")
        guard !value.isEmpty,
              value.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              value.contains("/") else {
            return "application/octet-stream"
        }
        return value
    }
}

public enum AttachmentSelectionError: LocalizedError, Equatable, Sendable {
    case invalidFile
    case emptyFile
    case tooLarge
    case tooManyFiles
    case totalSizeExceeded

    public var errorDescription: String? {
        switch self {
        case .invalidFile:
            String(
                localized: "The selected item is not a readable file.",
                comment: "Shown when a chosen attachment cannot be read"
            )
        case .emptyFile:
            String(
                localized: "The selected file is empty.",
                comment: "Shown when a chosen attachment contains no data"
            )
        case .tooLarge:
            String(
                localized: "The selected file is larger than WootDesk's 25 MB upload limit.",
                comment: "Shown when one chosen attachment exceeds the size limit"
            )
        case .tooManyFiles:
            String(
                localized: "A message can contain up to 15 attachments.",
                comment: "Shown when too many attachments are chosen for one message"
            )
        case .totalSizeExceeded:
            String(
                localized: "The selected attachments exceed WootDesk's 25 MB per-message limit.",
                comment: "Shown when the chosen attachments exceed the per-message size limit"
            )
        }
    }
}
