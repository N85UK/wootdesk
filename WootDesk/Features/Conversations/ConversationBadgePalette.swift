import SwiftUI

/// The colours the conversation list uses to carry status and priority.
///
/// These were system colours until a contrast audit found every pair failing
/// WCAG AA for small text. Status badges drew the hue as text over the same hue
/// at fifteen percent, which is a coloured word on a wash of itself: blue
/// reached 3.30:1, purple 3.42:1, green 1.96:1 and orange 1.95:1. Priority drew
/// the hue directly on the window background, where red reached 3.55:1, grey
/// 3.26:1, orange 2.20:1 and yellow 1.51:1. Caption text needs 4.5:1. Yellow at
/// 1.51:1 is barely a mark on the screen.
///
/// Each badge is a chip carrying its own background rather than tinted text on
/// whatever is behind it. That is deliberate: no single fixed colour can reach
/// 4.5:1 against both the light and the dark system background, because a
/// colour dark enough to pass on white is too dark to pass on black. Owning the
/// background makes the pair self-contained and legible either way.
///
/// The values are checked by `ConversationBadgePaletteTests`, which computes the
/// WCAG ratio for every pair rather than trusting the numbers below.
public enum ConversationBadgePalette {

    /// An sRGB colour held as components so contrast can be computed and
    /// asserted without resolving through UIKit or AppKit.
    public struct RGB: Sendable, Equatable {
        public let red: Double
        public let green: Double
        public let blue: Double

        /// - Parameters are 0 to 255, the form the palette was designed in.
        public init(_ red: Int, _ green: Int, _ blue: Int) {
            self.red = Double(red) / 255
            self.green = Double(green) / 255
            self.blue = Double(blue) / 255
        }

        public var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue)
        }

        /// WCAG 2.2 relative luminance.
        public var relativeLuminance: Double {
            func channel(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
        }

        /// WCAG 2.2 contrast ratio, from 1:1 to 21:1.
        public func contrastRatio(against other: RGB) -> Double {
            let a = relativeLuminance
            let b = other.relativeLuminance
            return (max(a, b) + 0.05) / (min(a, b) + 0.05)
        }
    }

    /// A badge's background with the two foregrounds it can draw.
    public struct Swatch: Sendable, Equatable {
        public let background: RGB
        public let foreground: RGB
        /// Used when the agent has asked the system for increased contrast.
        public let increasedContrastForeground: RGB

        /// - Parameter contrast: the environment's `colorSchemeContrast`.
        public func foreground(for contrast: ColorSchemeContrast) -> RGB {
            contrast == .increased ? increasedContrastForeground : foreground
        }
    }

    public static func swatch(for status: ConversationStatus) -> Swatch {
        switch status {
        case .open:
            return Swatch(
                background: RGB(217, 235, 255),
                foreground: RGB(0, 99, 206),
                increasedContrastForeground: RGB(0, 73, 153)
            )
        case .resolved:
            return Swatch(
                background: RGB(225, 247, 230),
                foreground: RGB(32, 123, 55),
                increasedContrastForeground: RGB(24, 92, 41)
            )
        case .pending:
            return Swatch(
                background: RGB(255, 239, 217),
                foreground: RGB(157, 91, 0),
                increasedContrastForeground: RGB(117, 68, 0)
            )
        case .snoozed:
            return Swatch(
                background: RGB(243, 229, 250),
                foreground: RGB(156, 41, 214),
                increasedContrastForeground: RGB(116, 30, 159)
            )
        }
    }

    public static func swatch(for priority: ConversationPriority) -> Swatch {
        switch priority {
        case .urgent:
            return Swatch(
                background: RGB(255, 226, 224),
                foreground: RGB(205, 11, 0),
                increasedContrastForeground: RGB(153, 8, 0)
            )
        case .high:
            return Swatch(
                background: RGB(255, 239, 217),
                foreground: RGB(157, 91, 0),
                increasedContrastForeground: RGB(117, 68, 0)
            )
        case .medium:
            return Swatch(
                background: RGB(255, 247, 217),
                foreground: RGB(134, 108, 0),
                increasedContrastForeground: RGB(101, 81, 0)
            )
        case .low:
            return Swatch(
                background: RGB(238, 238, 239),
                foreground: RGB(105, 105, 110),
                increasedContrastForeground: RGB(78, 78, 81)
            )
        }
    }

    /// WCAG AA for text below 18pt, which is every badge here.
    public static let minimumContrastForSmallText = 4.5

    /// The bar the palette holds itself to when increased contrast is asked
    /// for. AA is the floor everywhere; asking for more should deliver more.
    public static let minimumContrastWhenIncreased = 7.0
}
