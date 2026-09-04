import Testing
import SwiftUI
@testable import WootDesk

/// N85-14 AC4, the increased contrast half.
///
/// AC4 asks that information stays distinguishable when the agent turns on
/// increased contrast. That is only meaningful if the colours are legible to
/// begin with, and before this suite existed none of them were: every badge in
/// the conversation list failed WCAG AA for small text, the worst being yellow
/// priority at 1.51:1 against 4.5:1 required.
///
/// These tests compute the ratio from the stored components rather than
/// asserting the constants look right, so changing any colour is checked rather
/// than trusted.
@Suite("Conversation Badge Palette Tests")
struct ConversationBadgePaletteTests {

    private let allStatuses: [ConversationStatus] = [.open, .resolved, .pending, .snoozed]
    private let allPriorities: [ConversationPriority] = [.urgent, .high, .medium, .low]

    @Test("Every status badge meets WCAG AA for small text")
    func testStatusBadgesMeetAA() {
        for status in allStatuses {
            let swatch = ConversationBadgePalette.swatch(for: status)
            let ratio = swatch.foreground.contrastRatio(against: swatch.background)
            #expect(
                ratio >= ConversationBadgePalette.minimumContrastForSmallText,
                "\(status) reads at \(ratio):1, below the 4.5:1 caption text needs"
            )
        }
    }

    @Test("Every priority badge meets WCAG AA for small text")
    func testPriorityBadgesMeetAA() {
        for priority in allPriorities {
            let swatch = ConversationBadgePalette.swatch(for: priority)
            let ratio = swatch.foreground.contrastRatio(against: swatch.background)
            #expect(
                ratio >= ConversationBadgePalette.minimumContrastForSmallText,
                "\(priority) reads at \(ratio):1, below the 4.5:1 caption text needs"
            )
        }
    }

    /// Asking for increased contrast has to deliver it, not merely be accepted.
    @Test("Increased contrast raises every badge to 7:1")
    func testIncreasedContrastRaisesEveryBadge() {
        for status in allStatuses {
            let swatch = ConversationBadgePalette.swatch(for: status)
            let ratio = swatch.increasedContrastForeground.contrastRatio(against: swatch.background)
            #expect(
                ratio >= ConversationBadgePalette.minimumContrastWhenIncreased,
                "\(status) reads at \(ratio):1 under increased contrast, below 7:1"
            )
        }
        for priority in allPriorities {
            let swatch = ConversationBadgePalette.swatch(for: priority)
            let ratio = swatch.increasedContrastForeground.contrastRatio(against: swatch.background)
            #expect(
                ratio >= ConversationBadgePalette.minimumContrastWhenIncreased,
                "\(priority) reads at \(ratio):1 under increased contrast, below 7:1"
            )
        }
    }

    /// The environment value has to actually select the darker foreground.
    /// Without this, a palette could hold perfect increased-contrast colours
    /// that nothing ever draws.
    @Test("The increased contrast environment selects the stronger foreground")
    func testEnvironmentSelectsStrongerForeground() {
        for status in allStatuses {
            let swatch = ConversationBadgePalette.swatch(for: status)
            #expect(swatch.foreground(for: .standard) == swatch.foreground)
            #expect(swatch.foreground(for: .increased) == swatch.increasedContrastForeground)

            let standard = swatch.foreground(for: .standard).contrastRatio(against: swatch.background)
            let increased = swatch.foreground(for: .increased).contrastRatio(against: swatch.background)
            #expect(increased > standard, "\(status) does not gain contrast when it is asked for")
        }
    }

    /// A guard on the maths itself. The ratio formula is the thing every
    /// assertion above depends on, so it is checked against the two ratios
    /// WCAG fixes by definition.
    @Test("The contrast formula matches the values WCAG defines")
    func testContrastFormulaIsCorrect() {
        let black = ConversationBadgePalette.RGB(0, 0, 0)
        let white = ConversationBadgePalette.RGB(255, 255, 255)

        #expect(abs(white.contrastRatio(against: black) - 21.0) < 0.01)
        #expect(abs(white.contrastRatio(against: white) - 1.0) < 0.001)
        #expect(abs(black.contrastRatio(against: white) - 21.0) < 0.01)
    }

    /// Status and priority must stay separable without colour, which is the
    /// other half of AC4. Two states rendering the same words would put the
    /// whole weight back on hue.
    @Test("No two states share a display name")
    func testStatesRemainSeparableByWordAlone() {
        let statusNames = allStatuses.map(\.displayName)
        #expect(Set(statusNames).count == statusNames.count)

        let priorityNames = allPriorities.map(\.displayName)
        #expect(Set(priorityNames).count == priorityNames.count)
    }
}
