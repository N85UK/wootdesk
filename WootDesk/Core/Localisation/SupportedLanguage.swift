import Foundation

/// The languages WootDesk ships catalogued user-facing text for.
///
/// British English is the source language. Every catalogued string is written
/// in British English at the call site, so a key with no translation in the
/// active language resolves to British English rather than showing a raw key.
///
/// Adding a language means adding a case here and a complete translation in
/// `Localizable.xcstrings`. A partially translated language is deliberately not
/// shipped, because it would present a mixture of two languages to the agent.
public enum SupportedLanguage: String, CaseIterable, Identifiable, Sendable {
    case britishEnglish = "en-GB"

    public var id: Self { self }

    /// The language every catalogued string falls back to.
    public static let fallback: SupportedLanguage = .britishEnglish

    /// The language name as written in that language.
    public var endonym: String {
        switch self {
        case .britishEnglish: return "English (United Kingdom)"
        }
    }

    /// Resolves a device language to the language WootDesk will display.
    ///
    /// An unsupported device language resolves to the fallback rather than to a
    /// partially translated one.
    public static func resolved(forPreferred identifiers: [String]) -> SupportedLanguage {
        for identifier in identifiers {
            let candidate = Locale(identifier: identifier)
            for supported in allCases {
                let supportedLocale = Locale(identifier: supported.rawValue)
                if candidate.identifier == supportedLocale.identifier {
                    return supported
                }
                if let candidateLanguage = candidate.language.languageCode?.identifier,
                   let supportedLanguage = supportedLocale.language.languageCode?.identifier,
                   candidateLanguage == supportedLanguage {
                    return supported
                }
            }
        }
        return fallback
    }
}
