import Foundation

/// Converts untrusted Chatwoot message content into non-executable presentation data.
public enum MessageTextFormatter {
    public static func plainText(from rawValue: String?) -> String {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return ""
        }

        if value.contains("<"), value.contains(">") {
            value = value.replacingOccurrences(
                of: "(?i)<br\\s*/?>|</p\\s*>|</div\\s*>|</li\\s*>",
                with: "\n",
                options: .regularExpression
            )
            value = value.replacingOccurrences(
                of: "<[^>]+>",
                with: "",
                options: .regularExpression
            )
        }

        let entities = [
            "&nbsp;": " ",
            "&#160;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'"
        ]
        for (entity, replacement) in entities {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }

        value = value.replacingOccurrences(
            of: "\n[\\t ]+",
            with: "\n",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func attributedText(from plainText: String) -> AttributedString {
        var value = (try? AttributedString(
            markdown: plainText,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(plainText)

        for run in value.runs where run.link != nil {
            value[run.range].link = nil
        }
        return value
    }
}
