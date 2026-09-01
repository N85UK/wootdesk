import Foundation

public extension Int {
    /// The value rendered as an identifier, without grouping separators.
    ///
    /// Chatwoot conversation and account numbers are opaque references, not
    /// quantities. Locale number formatting renders conversation 7007 as
    /// "7,007", which does not match the identifier shown in Chatwoot and
    /// cannot be pasted or searched for. Both SwiftUI `Text` string literals and
    /// `String(localized:)` apply that formatting to an interpolated integer, so
    /// every identifier shown to an agent goes through this property instead.
    var identifierText: String {
        String(self)
    }
}
