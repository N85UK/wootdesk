import Foundation

/// A contact (customer/user) in Chatwoot associated with conversations.
public struct Contact: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let email: String?
    public let phoneNumber: String?
    public let thumbnailURL: URL?
    public let identifier: String?

    public init(
        id: Int,
        name: String,
        email: String? = nil,
        phoneNumber: String? = nil,
        thumbnailURL: URL? = nil,
        identifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.thumbnailURL = thumbnailURL
        self.identifier = identifier
    }

    /// Formatted initials for avatar placeholder display.
    public var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}
