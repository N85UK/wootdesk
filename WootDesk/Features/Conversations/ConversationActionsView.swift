import SwiftUI

/// The triage controls for the selected conversation.
///
/// The controls sit above the message timeline rather than over it, so the
/// conversation stays readable while an action is chosen. The same controls are
/// used on iPhone, iPad and Mac; the row scrolls horizontally when the window or
/// text size leaves too little room.
public struct ConversationActionsView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var state: ConversationTriageState
    let profile: ServerProfile?
    let token: String?

    @State private var isChoosingSnoozeTime = false
    @State private var customSnoozeDate = Date().addingTimeInterval(3_600)

    public init(
        state: ConversationTriageState,
        profile: ServerProfile?,
        token: String?
    ) {
        self.state = state
        self.profile = profile
        self.token = token
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            controlRow
            appliedLabels
            if let message = state.errorMessage {
                errorBanner(message)
            }
            if let message = state.optionsErrorMessage {
                optionsErrorBanner(message)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state.errorMessage)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state.pendingAction)
        .task(id: OptionsLoadContext(profile: profile)) {
            guard let profile, let token else { return }
            await state.loadOptions(profile: profile, token: token, using: environment.apiClient)
        }
    }

    // MARK: - Control Row

    private var controlRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                statusMenu
                priorityMenu
                assignmentMenu
                labelMenu
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.automatic)
        .accessibilityLabel("Conversation actions")
    }

    private var statusMenu: some View {
        Menu {
            ForEach(ConversationStatus.directlySelectable, id: \.self) { status in
                Button {
                    submitStatus(status)
                } label: {
                    Label(status.displayName, systemImage: checkmarkSymbol(isSelected: status == currentStatus))
                }
                .keyboardShortcut(Self.shortcutKey(for: status), modifiers: [.command, .option])
                .disabled(status == currentStatus)
            }

            Divider()

            Menu("Snooze") {
                ForEach(ConversationSnoozeOption.allCases) { option in
                    Button(option.displayName) { submitSnooze(option) }
                }
                Divider()
                Button("Choose Time...") { isChoosingSnoozeTime = true }
            }
        } label: {
            actionLabel(
                title: "Status",
                value: statusValueDescription,
                systemImage: "tray.full",
                isPending: isPending(.status)
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel("Status")
        .accessibilityValue(accessibilityValue(statusValueDescription, isPending: isPending(.status)))
        .accessibilityHint("Set the conversation status, or snooze it until a chosen time")
        .popover(isPresented: $isChoosingSnoozeTime) {
            snoozeTimePicker
        }
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(ConversationPriority.allCases, id: \.self) { priority in
                Button {
                    submitPriority(priority)
                } label: {
                    Label(
                        priority.displayName,
                        systemImage: checkmarkSymbol(isSelected: priority == state.conversation?.priority)
                    )
                }
                .disabled(priority == state.conversation?.priority)
            }
            Divider()
            Button("No Priority") { submitPriority(nil) }
                .disabled(state.conversation?.priority == nil)
        } label: {
            actionLabel(
                title: "Priority",
                value: state.conversation?.priority?.displayName ?? "None",
                systemImage: "exclamationmark.triangle",
                isPending: isPending(.priority)
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel("Priority")
        .accessibilityValue(
            accessibilityValue(
                state.conversation?.priority?.displayName ?? "None",
                isPending: isPending(.priority)
            )
        )
        .accessibilityHint("Set or clear the conversation priority")
    }

    private var assignmentMenu: some View {
        Menu {
            if state.assignmentOptions.isEmpty {
                Text(
                    state.isLoadingOptions
                        ? "Loading assignment options..."
                        : "This account offers no agents or teams for assignment."
                )
            } else {
                if !state.assignmentOptions.agents.isEmpty {
                    Section("Agents") {
                        ForEach(state.assignmentOptions.agents) { agent in
                            Button {
                                submitAssignment(.agent(id: agent.id))
                            } label: {
                                Label(
                                    agentTitle(agent),
                                    systemImage: checkmarkSymbol(
                                        isSelected: agent.id == state.conversation?.assignee?.id
                                    )
                                )
                            }
                            .disabled(agent.id == state.conversation?.assignee?.id)
                        }
                        Button("Unassign Agent") { submitAssignment(.unassignAgent) }
                            .disabled(state.conversation?.assignee == nil)
                    }
                }

                if !state.assignmentOptions.teams.isEmpty {
                    Section("Teams") {
                        ForEach(state.assignmentOptions.teams) { team in
                            Button {
                                submitAssignment(.team(id: team.id))
                            } label: {
                                Label(
                                    team.name,
                                    systemImage: checkmarkSymbol(
                                        isSelected: team.id == state.conversation?.team?.id
                                    )
                                )
                            }
                            .disabled(team.id == state.conversation?.team?.id)
                        }
                        Button("Unassign Team") { submitAssignment(.unassignTeam) }
                            .disabled(state.conversation?.team == nil)
                    }
                }
            }
        } label: {
            actionLabel(
                title: "Assignee",
                value: assignmentValueDescription,
                systemImage: "person.crop.circle",
                isPending: isPending(.assignment)
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel("Assignee")
        .accessibilityValue(
            accessibilityValue(assignmentValueDescription, isPending: isPending(.assignment))
        )
        .accessibilityHint("Assign this conversation to an agent or team")
    }

    private var labelMenu: some View {
        Menu {
            let applied = state.conversation?.labels ?? []
            if !applied.isEmpty {
                Section("Applied") {
                    ForEach(applied, id: \.self) { title in
                        Button {
                            submitLabel(title, isAdding: false)
                        } label: {
                            Label("Remove \(title)", systemImage: "checkmark")
                        }
                    }
                }
            }

            let available = state.availableLabelsToAdd
            if !available.isEmpty {
                Section("Available") {
                    ForEach(available, id: \.self) { title in
                        Button(title) { submitLabel(title, isAdding: true) }
                    }
                }
            }

            if applied.isEmpty && available.isEmpty {
                Text(
                    state.isLoadingOptions
                        ? "Loading labels..."
                        : "This account defines no labels."
                )
            }
        } label: {
            actionLabel(
                title: "Labels",
                value: labelValueDescription,
                systemImage: "tag",
                isPending: isPendingLabel
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel("Labels")
        .accessibilityValue(accessibilityValue(labelValueDescription, isPending: isPendingLabel))
        .accessibilityHint("Add or remove a conversation label")
    }

    /// The confirmed labels, shown as text so that they are readable without
    /// opening the menu and are not conveyed by colour alone.
    @ViewBuilder
    private var appliedLabels: some View {
        let labels = state.conversation?.labels ?? []
        if !labels.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(labels, id: \.self) { title in
                        Text(title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .padding(.horizontal)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Applied labels: \(labels.joined(separator: ", "))")
        }
    }

    // MARK: - Snooze Time

    private var snoozeTimePicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Snooze Until")
                .font(.headline)
            DatePicker(
                "Return time",
                selection: $customSnoozeDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()

            HStack {
                Button("Cancel") { isChoosingSnoozeTime = false }
                Spacer()
                Button("Snooze") {
                    isChoosingSnoozeTime = false
                    submitStatus(.snoozed, snoozedUntil: customSnoozeDate)
                }
                .buttonStyle(.borderedProminent)
                .disabled(customSnoozeDate.timeIntervalSinceNow <= 0)
            }
        }
        .padding()
        .frame(minWidth: 280)
    }

    // MARK: - Presentation Helpers

    private func actionLabel(
        title: String,
        value: String,
        systemImage: String,
        isPending: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            if isPending {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Dismiss") { state.dismissError() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Conversation action failed. \(message)")
    }

    private func optionsErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Assignment options and labels are unavailable. \(message)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Retry") { reloadOptions() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private var currentStatus: ConversationStatus? { state.conversation?.status }

    private var statusValueDescription: String {
        guard let conversation = state.conversation else { return "Unknown" }
        guard conversation.status == .snoozed, let until = conversation.snoozedUntil else {
            return conversation.status.displayName
        }
        return "Snoozed until \(until.formatted(date: .abbreviated, time: .shortened))"
    }

    private var assignmentValueDescription: String {
        let assignee = state.conversation?.assignee?.name
        let team = state.conversation?.team?.name
        switch (assignee, team) {
        case let (.some(assignee), .some(team)): return "\(assignee), \(team)"
        case let (.some(assignee), .none): return assignee
        case let (.none, .some(team)): return team
        case (.none, .none): return "Unassigned"
        }
    }

    private var labelValueDescription: String {
        let labels = state.conversation?.labels ?? []
        if labels.isEmpty { return "None" }
        return labels.count == 1 ? labels[0] : "\(labels.count) labels"
    }

    private func agentTitle(_ agent: AssignableAgent) -> String {
        guard let availability = agent.availability else { return agent.name }
        return "\(agent.name) (\(availability.displayName))"
    }

    /// Menu rows use a checkmark, or a blank slot of the same width, so the
    /// current value is conveyed by a symbol and by the disabled state rather
    /// than by colour alone.
    private func checkmarkSymbol(isSelected: Bool) -> String {
        isSelected ? "checkmark" : "circle.dotted"
    }

    private func accessibilityValue(_ value: String, isPending: Bool) -> String {
        isPending ? "\(value), updating" : value
    }

    private var isDisabled: Bool {
        state.conversation == nil || profile == nil || token == nil || state.isSubmitting
    }

    private var isPendingLabel: Bool {
        if case .label = state.pendingAction { return true }
        return false
    }

    private func isPending(_ kind: PendingKind) -> Bool {
        switch (kind, state.pendingAction) {
        case (.status, .status): return true
        case (.priority, .priority): return true
        case (.assignment, .assignment): return true
        default: return false
        }
    }

    private enum PendingKind {
        case status
        case priority
        case assignment
    }

    private static func shortcutKey(for status: ConversationStatus) -> KeyEquivalent {
        switch status {
        case .open: return "o"
        case .pending: return "p"
        case .resolved: return "r"
        case .snoozed: return "s"
        }
    }

    // MARK: - Submission

    private func submitStatus(_ status: ConversationStatus, snoozedUntil: Date? = nil) {
        guard let profile, let token else { return }
        Task {
            await state.setStatus(
                status,
                snoozedUntil: snoozedUntil,
                profile: profile,
                token: token,
                using: environment.apiClient
            )
        }
    }

    private func submitSnooze(_ option: ConversationSnoozeOption) {
        guard let returnDate = option.returnDate(from: Date()) else {
            // The calendar could not produce the time, so nothing is submitted
            // and no substitute time is invented.
            return
        }
        submitStatus(.snoozed, snoozedUntil: returnDate)
    }

    private func submitPriority(_ priority: ConversationPriority?) {
        guard let profile, let token else { return }
        Task {
            await state.setPriority(
                priority,
                profile: profile,
                token: token,
                using: environment.apiClient
            )
        }
    }

    private func submitAssignment(_ target: ConversationAssignmentTarget) {
        guard let profile, let token else { return }
        Task {
            await state.assign(
                to: target,
                profile: profile,
                token: token,
                using: environment.apiClient
            )
        }
    }

    private func submitLabel(_ title: String, isAdding: Bool) {
        guard let profile, let token else { return }
        Task {
            if isAdding {
                await state.addLabel(title, profile: profile, token: token, using: environment.apiClient)
            } else {
                await state.removeLabel(title, profile: profile, token: token, using: environment.apiClient)
            }
        }
    }

    private func reloadOptions() {
        guard let profile, let token else { return }
        Task {
            await state.loadOptions(
                profile: profile,
                token: token,
                using: environment.apiClient,
                forceReload: true
            )
        }
    }
}

private struct OptionsLoadContext: Equatable {
    let profileID: UUID?
    let accountID: Int?

    init(profile: ServerProfile?) {
        profileID = profile?.id
        accountID = profile?.selectedAccountID
    }
}

@MainActor
private func previewActions(
    conversation: Conversation,
    api: StubChatwootAPI = StubChatwootAPI()
) -> some View {
    let profile = PreviewData.profile
    let environment = AppEnvironment.preview(
        profiles: [profile],
        activeProfileID: profile.id,
        tokens: [profile.id: "test"],
        apiClient: api
    )
    let state = ConversationTriageState()
    state.adopt(conversation, profile: profile)

    return ConversationActionsView(state: state, profile: profile, token: "test")
        .environment(\.appEnvironment, environment)
        .padding(.vertical)
        .frame(width: 560)
}

#Preview("Conversation Actions: Assigned and Labelled") {
    previewActions(conversation: PreviewData.conversations[0])
}

#Preview("Conversation Actions: Unassigned") {
    previewActions(conversation: PreviewData.conversations[1])
}

#Preview("Conversation Actions: Options Unavailable") {
    previewActions(
        conversation: PreviewData.conversations[1],
        api: StubChatwootAPI(assignmentOptionsOutcome: .failure(.offline))
    )
}
