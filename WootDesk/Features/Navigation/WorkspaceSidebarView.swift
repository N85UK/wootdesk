import SwiftUI

/// The workspace navigation column shared by the Mac and iPad split layouts.
///
/// Both platforms present the same hierarchy, so the selected workspace, the
/// active server profile, and the availability control stay in one place rather
/// than being duplicated per platform.
public struct WorkspaceSidebarView: View {
    @Bindable var appModel: AppModel
    let availabilityState: AgentAvailabilityState

    public init(appModel: AppModel, availabilityState: AgentAvailabilityState) {
        self.appModel = appModel
        self.availabilityState = availabilityState
    }

    public var body: some View {
        List(selection: $appModel.selectedNavigationItem) {
            Section("Workspace") {
                Label("Conversations", systemImage: "bubble.left.and.bubble.right")
                    .tag(AppModel.NavigationItem.conversations(status: .open))
            }

            Section("Server Profiles") {
                ForEach(appModel.profiles) { profile in
                    profileRow(profile)
                }

                Label("Manage Servers", systemImage: "server.rack")
                    .tag(AppModel.NavigationItem.connections)
            }

            Section("Preferences") {
                Label("Settings", systemImage: "gearshape")
                    .tag(AppModel.NavigationItem.settings)
            }

            Section("Agent") {
                AgentAvailabilityMenu(
                    state: availabilityState,
                    profile: appModel.activeProfile,
                    token: appModel.activeToken
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("WootDesk")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.showAddConnectionSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .help("Add a Chatwoot server connection")
            }
        }
    }

    /// One saved server profile. The active profile is marked with a symbol as
    /// well as its selected state, so the current workspace is explicit without
    /// relying on colour alone.
    private func profileRow(_ profile: ServerProfile) -> some View {
        Button {
            Task { await appModel.selectProfile(profile) }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(profile.selectedAccountName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if profile.id == appModel.activeProfile?.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(appModel.isSwitchingProfile)
        .accessibilityLabel(profile.displayName)
        .accessibilityValue(
            profile.id == appModel.activeProfile?.id
                ? "Active profile, account \(profile.selectedAccountName)"
                : "Account \(profile.selectedAccountName)"
        )
        .accessibilityHint("Switch to this Chatwoot server profile")
    }
}

/// Clears every conversation surface that belongs to one server profile.
///
/// Used both when the agent switches profile and when a notification activates
/// a different profile, so one server's conversations can never be displayed
/// under another.
@MainActor
public enum ConversationWorkspaceReset {
    public static func clearProfileData(
        list: ConversationListState,
        detail: ConversationDetailState,
        triage: ConversationTriageState
    ) {
        list.clear()
        detail.clear()
        triage.clear()
    }
}
