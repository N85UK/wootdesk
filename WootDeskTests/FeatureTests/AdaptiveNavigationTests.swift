import Foundation
import SwiftUI
import Testing
@testable import WootDesk

@Suite("Adaptive Navigation Tests")
struct AdaptiveNavigationTests {
    private func profile(id: UUID = UUID(), accountID: Int = 1) -> ServerProfile {
        ServerProfile(
            id: id,
            displayName: "Sample Server",
            baseURL: URL(string: "https://messages.example.com")!,
            selectedAccountID: accountID,
            selectedAccountName: "Sample Account"
        )
    }

    private func conversation(id: Int, accountID: Int = 1) -> Conversation {
        Conversation(
            id: id,
            accountID: accountID,
            inboxID: 1,
            status: .open,
            lastActivityAt: Date(timeIntervalSince1970: 1_735_737_000)
        )
    }

    // MARK: - AC4 Isolate data when switching workspaces

    @Test("Switching workspace clears the previous profile's conversation and detail data")
    @MainActor
    func testWorkspaceSwitchClearsProfileData() async {
        let saved = profile()
        let listState = ConversationListState()
        let detailState = ConversationDetailState()
        let triageState = ConversationTriageState()

        listState.adoptRoutedConversation(conversation(id: 1_041))
        listState.searchQuery = "invented search"
        listState.errorMessage = "an invented error"
        detailState.draft = "an invented draft"
        triageState.adopt(conversation(id: 1_041), profile: saved)

        #expect(listState.selectedConversationID == 1_041)
        #expect(triageState.conversation != nil)

        ConversationWorkspaceReset.clearProfileData(
            list: listState,
            detail: detailState,
            triage: triageState
        )

        #expect(listState.conversations.isEmpty)
        #expect(listState.selectedConversationID == nil)
        #expect(listState.errorMessage == nil)
        #expect(detailState.messages.isEmpty)
        #expect(detailState.draft.isEmpty)
        #expect(triageState.conversation == nil)
    }

    @Test("A cleared workspace does not carry a draft between server profiles")
    @MainActor
    func testDraftIsNotCarriedBetweenProfiles() async {
        let detailState = ConversationDetailState()
        detailState.draft = "An invented reply for the first server"

        ConversationWorkspaceReset.clearProfileData(
            list: ConversationListState(),
            detail: detailState,
            triage: ConversationTriageState()
        )

        #expect(detailState.draft.isEmpty)
        #expect(detailState.pendingAttachments.isEmpty)
    }

    // MARK: - AC2 Retain the selection when the layout collapses

    @Test("The selected conversation survives a refresh that returns the same page")
    @MainActor
    func testSelectionSurvivesRefresh() async {
        let saved = profile()
        let listed = [conversation(id: 1_041), conversation(id: 1_042)]
        let api = StubChatwootAPI(conversationsOutcome: .success(listed))
        let listState = ConversationListState()

        await listState.loadConversations(profile: saved, token: "token", using: api)
        listState.selectedConversationID = 1_042
        await listState.refresh(profile: saved, token: "token", using: api)

        // The split layout reads its detail column from this selection, so the
        // selection must outlive a reload for the collapsed layout to return to
        // the same conversation.
        #expect(listState.selectedConversationID == 1_042)
        #expect(listState.selectedConversation?.id == 1_042)
    }

    // MARK: - AC5 Use filters at larger text sizes

    @Test(
        "The status filter stays a segmented control at standard text sizes",
        arguments: [
            DynamicTypeSize.xSmall,
            .small,
            .medium,
            .large,
            .xLarge,
            .xxLarge,
            .xxxLarge
        ]
    )
    func testSegmentedFilterAtStandardSizes(size: DynamicTypeSize) {
        #expect(ConversationFilterPickerLayout.preferred(for: size) == .segmented)
    }

    @Test(
        "The status filter becomes a menu at accessibility text sizes",
        arguments: [
            DynamicTypeSize.accessibility1,
            .accessibility2,
            .accessibility3,
            .accessibility4,
            .accessibility5
        ]
    )
    func testMenuFilterAtAccessibilitySizes(size: DynamicTypeSize) {
        // A segmented control cannot lay out five readable labels at these
        // sizes without clipping, so the control changes rather than the text.
        #expect(ConversationFilterPickerLayout.preferred(for: size) == .menu)
    }
}
