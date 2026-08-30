import Foundation

/// Data Transfer Object for `GET /api/v1/profile`.
public struct ChatwootProfileDTO: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let email: String?
    public let accounts: [ChatwootAccountDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case accounts
    }

    public init(
        id: Int? = nil,
        name: String? = nil,
        email: String? = nil,
        accounts: [ChatwootAccountDTO]? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.accounts = accounts
    }
}
