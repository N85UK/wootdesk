import SwiftUI

/// Manages saved Chatwoot server connections.
public struct ConnectionListView: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var appModel: AppModel

    @State private var profileToDelete: ServerProfile?
    @State private var editContext: EditContext?

    public init(appModel: AppModel) {
        self.appModel = appModel
    }

    public var body: some View {
        List {
            if let error = appModel.lastError {
                Section("Connection Status") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section(header: Text("Saved Servers")) {
                if appModel.profiles.isEmpty {
                    Text("No Chatwoot servers configured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.profiles) { profile in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(profile.displayName)
                                        .font(.headline)
                                    if profile.id == appModel.activeProfile?.id {
                                        Text("Active")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.2))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(profile.baseURL.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("Account: \(profile.selectedAccountName) (#\(profile.selectedAccountID))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if profile.id != appModel.activeProfile?.id {
                                Button("Switch") {
                                    Task {
                                        await appModel.selectProfile(profile)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(appModel.isSwitchingProfile)
                            }

                            Menu {
                                Button {
                                    prepareEditor(for: profile)
                                } label: {
                                    Label("Edit and Revalidate", systemImage: "checkmark.shield")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    profileToDelete = profile
                                } label: {
                                    Label("Remove Server", systemImage: "trash")
                                }
                            } label: {
                                Label("Server Actions", systemImage: "ellipsis.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .accessibilityLabel("Actions for \(profile.displayName)")
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button {
                                prepareEditor(for: profile)
                            } label: {
                                Label("Edit and Revalidate", systemImage: "checkmark.shield")
                            }

                            Button(role: .destructive) {
                                profileToDelete = profile
                            } label: {
                                Label("Delete Server", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        if let firstIndex = indexSet.first {
                            profileToDelete = appModel.profiles[firstIndex]
                        }
                    }
                }
            }
        }
        .sheet(item: $editContext) { context in
            AddConnectionView(
                initialURL: context.profile.baseURL.absoluteString,
                initialToken: context.token,
                initialDisplayName: context.profile.displayName,
                mode: .edit,
                onSaveSuccess: { displayName, url, token, account in
                    try await appModel.updateConnection(
                        profileID: context.profile.id,
                        displayName: displayName,
                        baseURL: url,
                        token: token,
                        account: account
                    )
                }
            )
            .environment(\.appEnvironment, environment)
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.showAddConnectionSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }
        }
        .confirmationDialog(
            "Remove Server Profile?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            presenting: profileToDelete
        ) { profile in
            Button("Remove \(profile.displayName)", role: .destructive) {
                Task {
                    await appModel.deleteProfile(id: profile.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { profile in
            Text("Are you sure you want to remove \(profile.displayName)? Saved credentials for this server will be deleted from your Keychain.")
        }
    }

    private func prepareEditor(for profile: ServerProfile) {
        guard let token = appModel.credentialForEditing(profile) else { return }
        editContext = EditContext(profile: profile, token: token)
    }

    private struct EditContext: Identifiable {
        let profile: ServerProfile
        let token: String

        var id: UUID { profile.id }
    }
}

#Preview("Servers: Saved Profiles") {
    let second = ServerProfile(
        displayName: "Sample Sales Desk",
        baseURL: URL(string: "https://sales.chatwoot.example.com")!,
        selectedAccountID: 2,
        selectedAccountName: "Sample Sales Team"
    )
    let profiles = [PreviewData.profile, second]
    let environment = AppEnvironment.preview(
        profiles: profiles,
        activeProfileID: PreviewData.profile.id,
        tokens: [PreviewData.profile.id: "test", second.id: "test-2"]
    )
    let appModel = AppModel(environment: environment)
    appModel.applyPreviewState(
        profiles: profiles,
        activeProfile: PreviewData.profile,
        token: "test"
    )

    return NavigationStack {
        ConnectionListView(appModel: appModel)
    }
    .environment(\.appEnvironment, environment)
}
