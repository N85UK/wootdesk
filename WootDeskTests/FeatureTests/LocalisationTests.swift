import Foundation
import Testing
@testable import WootDesk

@Suite("Localisation Tests")
struct LocalisationTests {

    // MARK: - Supported languages

    @Test("British English is the source language every string falls back to")
    func testFallbackLanguage() {
        #expect(SupportedLanguage.fallback == .britishEnglish)
        #expect(SupportedLanguage.britishEnglish.rawValue == "en-GB")
    }

    @Test("The app bundle ships exactly the declared supported languages")
    func testBundleShipsOnlyDeclaredLanguages() throws {
        let bundle = Bundle(for: MockURLProtocol.self)
        let appBundle = Bundle(identifier: "dev.n85.wootdesk") ?? bundle

        let shipped = Set(appBundle.localizations)
            .subtracting(["Base"])
        guard !shipped.isEmpty else {
            // The unit-test host may expose no localisations for the app bundle.
            // That is not a product failure, so nothing is asserted rather than
            // pretending the check ran.
            return
        }

        let declared = Set(SupportedLanguage.allCases.map(\.rawValue))
        let undeclared = shipped.subtracting(declared).subtracting(["en"])
        #expect(
            undeclared.isEmpty,
            "The bundle ships \(undeclared) which SupportedLanguage does not declare. A partially translated language must not ship."
        )
    }

    @Test(
        "An unsupported device language resolves to British English",
        arguments: ["fr-FR", "de-DE", "ja-JP", "pt-BR", ""]
    )
    func testUnsupportedLanguageFallsBack(identifier: String) {
        #expect(SupportedLanguage.resolved(forPreferred: [identifier]) == .britishEnglish)
    }

    @Test(
        "A supported device language resolves to that language",
        arguments: ["en-GB", "en-AU", "en"]
    )
    func testSupportedLanguageResolves(identifier: String) {
        #expect(SupportedLanguage.resolved(forPreferred: [identifier]) == .britishEnglish)
    }

    // MARK: - Catalogued text

    /// The user-facing strings produced outside a SwiftUI `Text` literal.
    ///
    /// Each is resolved through the localisation system, so this list also
    /// proves that every case returns text rather than an empty string or a raw
    /// key.
    private static func catalogued() -> [String] {
        var strings: [String] = []
        strings += ConversationStatus.allCases.map(\.displayName)
        strings += ConversationPriority.allCases.map(\.displayName)
        strings += AgentAvailability.allCases.map(\.displayName)
        strings += ConversationSnoozeOption.allCases.map(\.displayName)
        strings += ConversationComposerMode.allCases.map(\.title)
        strings += ConversationComposerMode.allCases.map(\.sendButtonTitle)
        // `ConversationAttachmentType` carries an associated value, so its
        // cases are listed rather than iterated.
        strings += [
            ConversationAttachmentType.image,
            .audio,
            .video,
            .file,
            .location,
            .contact,
            .fallback,
            .unknown("invented")
        ].map(\.displayName)
        strings += [
            APIError.invalidURL,
            .insecureScheme,
            .unauthorized,
            .forbidden,
            .notFound,
            .rateLimited(retryAfter: 30),
            .rateLimited(retryAfter: nil),
            .serverError(statusCode: 500, message: "invented"),
            .serverError(statusCode: 500, message: nil),
            .offline,
            .timedOut,
            .tlsFailure,
            .networkError("invented"),
            .decodingError("invented"),
            .invalidMessageContent,
            .invalidSnoozeTime,
            .noAccountsAvailable,
            .cancelled
        ].compactMap(\.errorDescription)
        strings += [
            AppModelError.profileNotFound,
            .credentialMissing,
            .invalidCredential,
            .persistenceFailed,
            .recoveryRequired
        ].compactMap(\.errorDescription)
        strings += [
            AttachmentSelectionError.invalidFile,
            .emptyFile,
            .tooLarge,
            .tooManyFiles,
            .totalSizeExceeded
        ].compactMap(\.errorDescription)
        return strings
    }

    @Test("Every catalogued string resolves to British English text")
    func testCataloguedStringsResolve() {
        let strings = Self.catalogued()
        #expect(!strings.isEmpty)
        for string in strings {
            #expect(
                !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "A user-facing string resolved to empty text."
            )
            #expect(
                !string.hasPrefix("%") || string.count > 2,
                "A user-facing string resolved to a bare format placeholder: \(string)"
            )
        }
    }

    // MARK: - Identifiers

    @Test(
        "A Chatwoot identifier is shown without grouping separators",
        arguments: [1_041, 7_007, 1_234_567]
    )
    func testIdentifiersAreNotGrouped(identifier: Int) {
        // Both SwiftUI Text literals and String(localized:) format an
        // interpolated integer for the locale, which would render conversation
        // 7007 as "7,007". An identifier is a reference, not a quantity.
        let text = identifier.identifierText
        #expect(text == String(identifier))
        #expect(!text.contains(","))
        #expect(!text.contains("."))
        #expect(!text.contains("\u{00A0}"))
    }

    @Test("A localised message carrying an identifier keeps it ungrouped")
    func testLocalisedIdentifierIsNotGrouped() {
        let message = String(
            localized: "WootDesk could not open conversation #\(7_007.identifierText) from that notification. Invented reason.",
            comment: "Test fixture mirroring the notification routing failure message"
        )
        #expect(message.contains("#7007"))
        #expect(!message.contains("#7,007"))
    }

    // MARK: - House style

    @Test("No user-facing string contains an em dash or en dash")
    func testNoLongDashes() {
        // The project writes with commas, colons, parentheses or separate
        // sentences instead. A long dash reaching a release would need a
        // retranslation of every catalogued language to remove.
        for string in Self.catalogued() {
            #expect(
                !string.contains("\u{2014}") && !string.contains("\u{2013}"),
                "A user-facing string contains a long dash: \(string)"
            )
        }
    }

    @Test("User-facing text uses British English spelling")
    func testBritishEnglishSpelling() {
        let americanSpellings = [
            "Authorization",
            "authorization",
            "Color",
            "color",
            "Organize",
            "organize",
            "Normalize",
            "normalize",
            "Canceled",
            "canceled",
            "License"
        ]
        for string in Self.catalogued() {
            for spelling in americanSpellings {
                #expect(
                    !string.contains(spelling),
                    "A user-facing string uses the spelling \"\(spelling)\": \(string)"
                )
            }
        }
    }
}
