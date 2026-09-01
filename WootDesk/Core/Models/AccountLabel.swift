import Foundation

/// A label defined at Chatwoot account level and available to apply to
/// conversations in that account.
public struct AccountLabel: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let title: String
    /// The server-supplied display colour, when the Chatwoot version provides one.
    public let colour: String?

    public init(id: Int, title: String, colour: String? = nil) {
        self.id = id
        self.title = title
        self.colour = colour
    }
}
