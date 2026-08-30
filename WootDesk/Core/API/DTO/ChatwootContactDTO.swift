import Foundation

/// Data Transfer Object for contacts within conversations.
public struct ChatwootContactDTO: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let email: String?
    public let phoneNumber: String?
    public let thumbnail: String?
    public let identifier: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phoneNumber = "phone_number"
        case thumbnail
        case identifier
    }

    public init(
        id: Int? = nil,
        name: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        thumbnail: String? = nil,
        identifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.thumbnail = thumbnail
        self.identifier = identifier
    }

    public func toDomain() -> Contact? {
        guard let id else { return nil }
        var thumbURL: URL? = nil
        if let thumbnail, let url = URL(string: thumbnail) {
            thumbURL = url
        }

        return Contact(
            id: id,
            name: name ?? email ?? "Contact #\(id)",
            email: email,
            phoneNumber: phoneNumber,
            thumbnailURL: thumbURL,
            identifier: identifier
        )
    }
}
