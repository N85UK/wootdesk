import XCTest
@testable import WootDesk

/// Performance regression checks for the conversation surfaces.
///
/// Every input is generated invented data. No real server, customer, or message
/// content is used, and nothing here contacts a network.
///
/// The thresholds are deliberate ceilings rather than tight targets. They are
/// sized to catch an algorithmic regression, such as an accidental quadratic
/// scan, without failing because a machine is momentarily busy. The baseline and
/// the reasoning behind each threshold are recorded in
/// `docs/PERFORMANCE_BASELINE.md`.
final class ConversationPerformanceTests: XCTestCase {

    // MARK: - Documented Thresholds

    /// Normalising one large timeline page: deduplicate by identifier and sort.
    private static let timelineNormalisationCeiling: TimeInterval = 2.0
    /// Filtering a large conversation list by a search term, over 50 reads.
    ///
    /// The observed time on the reference machine is roughly a third of this
    /// ceiling. The remaining headroom is deliberate: the filter recomputes on
    /// every render, so a busy machine must not fail the check, while a
    /// quadratic regression would exceed it many times over.
    private static let listFilterCeiling: TimeInterval = 3.0
    /// Converting processed message bodies to displayable text.
    private static let messageFormattingCeiling: TimeInterval = 3.0
    /// The most a workload may grow when its input doubles before it is treated
    /// as scaling worse than linearithmically.
    private static let doublingRatioCeiling: Double = 3.0

    private static let largeTimelineMessageCount = 5_000
    private static let largeConversationCount = 5_000

    // MARK: - Invented Data

    private func inventedProfile() -> ServerProfile {
        ServerProfile(
            id: UUID(uuidString: "0F5C7A26-9C36-4E3B-95A2-2A6C1D3F4B10")!,
            displayName: "Sample Performance Server",
            baseURL: URL(string: "https://performance.example.com")!,
            selectedAccountID: 1,
            selectedAccountName: "Sample Performance Account"
        )
    }

    private func inventedConversation(id: Int = 1_041) -> Conversation {
        Conversation(
            id: id,
            accountID: 1,
            inboxID: 1,
            status: .open,
            contact: Contact(id: id, name: "Sample Contact \(id)"),
            inboxName: "Sample Inbox \(id % 7)",
            lastActivityAt: Date(timeIntervalSince1970: 1_735_737_000),
            lastMessagePreview: "An invented preview for conversation \(id)."
        )
    }

    /// Builds an invented timeline page, shuffled deterministically so the sort
    /// does real work rather than confirming an already ordered input.
    private func inventedMessages(count: Int) -> [ConversationMessage] {
        let messages = (0..<count).map { index in
            ConversationMessage(
                id: index + 1,
                content: "Invented performance message \(index) with **bold** text and a <b>processed</b> fragment.",
                processedContent: "<p>Invented performance message \(index) with <b>processed</b> markup.</p>",
                kind: index.isMultiple(of: 2) ? .incoming : .outgoing,
                createdAt: Date(timeIntervalSince1970: TimeInterval(1_735_700_000 + index)),
                senderName: index.isMultiple(of: 2) ? "Sample Contact" : "Sample Agent",
                contentType: "text"
            )
        }
        // A fixed stride rather than a random shuffle keeps the run repeatable.
        return stride(from: 0, to: 7, by: 1).flatMap { offset in
            messages.enumerated()
                .filter { $0.offset % 7 == offset }
                .map(\.element)
        }
    }

    private func inventedConversations(count: Int) -> [Conversation] {
        (0..<count).map { inventedConversation(id: 1_000 + $0) }
    }

    private func elapsed(_ work: () throws -> Void) rethrows -> TimeInterval {
        let start = Date()
        try work()
        return Date().timeIntervalSince(start)
    }

    // MARK: - Timeline

    @MainActor
    func testLargeTimelineNormalisationStaysWithinThreshold() async {
        let profile = inventedProfile()
        let conversation = inventedConversation()
        let page = ConversationMessagePage(
            messages: inventedMessages(count: Self.largeTimelineMessageCount),
            hasOlderMessages: false
        )
        let api = StubChatwootAPI(messagesOutcome: .success(page))

        // The real load path is exercised, not a private helper, so the check
        // fails if any part of loading a large timeline regresses.
        let state = ConversationDetailState()
        let start = Date()
        await state.loadMessages(
            profile: profile,
            conversation: conversation,
            token: "token",
            using: api
        )
        let duration = Date().timeIntervalSince(start)

        XCTAssertEqual(state.messages.count, Self.largeTimelineMessageCount)
        XCTAssertTrue(
            state.messages[0].createdAt <= state.messages[1].createdAt,
            "The timeline must be ordered oldest first."
        )
        XCTAssertLessThan(
            duration,
            Self.timelineNormalisationCeiling,
            "Loading \(Self.largeTimelineMessageCount) invented messages took \(duration)s, over the documented \(Self.timelineNormalisationCeiling)s ceiling."
        )
    }

    @MainActor
    func testTimelineNormalisationScalesWithoutQuadraticGrowth() async {
        let profile = inventedProfile()
        let conversation = inventedConversation()

        func load(_ count: Int) async -> TimeInterval {
            let api = StubChatwootAPI(
                messagesOutcome: .success(
                    ConversationMessagePage(messages: inventedMessages(count: count), hasOlderMessages: false)
                )
            )
            let state = ConversationDetailState()
            let start = Date()
            await state.loadMessages(
                profile: profile,
                conversation: conversation,
                token: "token",
                using: api
            )
            return Date().timeIntervalSince(start)
        }

        // A warm run first, so the measured pair is not paying one-off costs.
        _ = await load(2_000)
        let single = await load(4_000)
        let double = await load(8_000)

        let ratio = double / max(single, 0.000_1)
        XCTAssertLessThan(
            ratio,
            Self.doublingRatioCeiling,
            "Doubling the timeline multiplied the time by \(ratio), which suggests worse than linearithmic scaling."
        )
    }

    // MARK: - Conversation List

    @MainActor
    func testLargeListFilterStaysWithinThreshold() throws {
        let state = ConversationListState()
        state.conversations = inventedConversations(count: Self.largeConversationCount)
        state.searchQuery = "Sample Contact 4321"

        var matches = 0
        let duration = elapsed {
            // The filter is recomputed on every render, so it is measured over
            // repeated reads rather than once.
            for _ in 0..<50 {
                matches = state.filteredConversations.count
            }
        }

        XCTAssertGreaterThan(matches, 0, "The invented search term must match at least one conversation.")
        XCTAssertLessThan(
            duration,
            Self.listFilterCeiling,
            "Filtering \(Self.largeConversationCount) invented conversations 50 times took \(duration)s, over the documented \(Self.listFilterCeiling)s ceiling."
        )
    }

    // MARK: - Message Presentation

    func testMessageFormattingStaysWithinThreshold() throws {
        let messages = inventedMessages(count: Self.largeTimelineMessageCount)

        let duration = elapsed {
            for message in messages {
                let plain = MessageTextFormatter.plainText(from: message.processedContent ?? message.content)
                _ = MessageTextFormatter.attributedText(from: plain)
            }
        }

        XCTAssertLessThan(
            duration,
            Self.messageFormattingCeiling,
            "Formatting \(Self.largeTimelineMessageCount) invented messages took \(duration)s, over the documented \(Self.messageFormattingCeiling)s ceiling."
        )
    }
}
