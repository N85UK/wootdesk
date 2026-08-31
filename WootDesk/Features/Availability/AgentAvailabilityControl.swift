import SwiftUI

/// Native availability controls shared by Settings and the macOS sidebar.
struct AgentAvailabilityMenu: View {
    @Bindable var state: AgentAvailabilityState
    let profile: ServerProfile?
    let token: String?

    var body: some View {
        Menu {
            ForEach(AgentAvailability.allCases) { option in
                Button {
                    Task {
                        await state.update(option, profile: profile, token: token)
                    }
                } label: {
                    if state.availability == option {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
                .accessibilityLabel("Set availability to \(option.displayName)")
            }

            Divider()

            Button {
                Task {
                    await state.load(profile: profile, token: token, force: true)
                }
            } label: {
                Label("Refresh Availability", systemImage: "arrow.clockwise")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(indicatorColour)
                    .accessibilityHidden(true)

                Text("Availability")
                Spacer()

                if state.isLoading || state.isUpdating {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(state.isUpdating ? "Updating availability" : "Loading availability")
                } else {
                    Text(state.availability?.displayName ?? "Not Reported")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(profile == nil || token?.isEmpty != false || state.isLoading || state.isUpdating)
        .accessibilityLabel("Availability, \(state.availability?.displayName ?? "not reported")")
        .accessibilityHint("Choose Online, Busy, or Offline for the active Chatwoot account")
    }

    private var indicatorColour: Color {
        switch state.availability {
        case .online:
            return .green
        case .busy:
            return .orange
        case .offline, .none:
            return .secondary
        }
    }
}

struct AgentAvailabilitySettingsSection: View {
    @Bindable var state: AgentAvailabilityState
    let profile: ServerProfile?
    let token: String?

    var body: some View {
        Section("Agent Availability") {
            if let profile, token?.isEmpty == false {
                AgentAvailabilityMenu(state: state, profile: profile, token: token)

                Text("Your status applies to \(profile.selectedAccountName) on the active Chatwoot server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = state.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Availability error: \(errorMessage)")

                    Button("Try Again") {
                        Task {
                            await state.load(profile: profile, token: token, force: true)
                        }
                    }
                    .disabled(state.isLoading || state.isUpdating)
                }
            } else {
                Text("Connect to a Chatwoot server to manage your availability.")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: context) {
            await state.load(profile: profile, token: token)
        }
    }

    private var context: Context {
        Context(profileID: profile?.id, accountID: profile?.selectedAccountID)
    }

    private struct Context: Equatable {
        let profileID: UUID?
        let accountID: Int?
    }
}

#Preview("Availability Loaded") {
    let profile = PreviewData.profile
    let api = StubChatwootAPI()
    let state = AgentAvailabilityState(apiClient: api)

    return Form {
        AgentAvailabilitySettingsSection(state: state, profile: profile, token: "test")
    }
    .formStyle(.grouped)
}

#Preview("Availability Error") {
    let profile = PreviewData.profile
    let api = StubChatwootAPI(profileOutcome: .failure(.offline))
    let state = AgentAvailabilityState(apiClient: api)

    return Form {
        AgentAvailabilitySettingsSection(state: state, profile: profile, token: "test")
    }
    .formStyle(.grouped)
}
