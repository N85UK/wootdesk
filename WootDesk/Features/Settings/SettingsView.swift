import SwiftUI

/// Settings and diagnostics view for WootDesk.
public struct SettingsView: View {
    @Bindable var appModel: AppModel

    public init(appModel: AppModel) {
        self.appModel = appModel
    }

    public var body: some View {
        Form {
            Section("Active Server") {
                if let active = appModel.activeProfile {
                    LabeledContent("Display Name", value: active.displayName)
                    LabeledContent("Server Address", value: active.baseURL.absoluteString)
                    LabeledContent("Account", value: "\(active.selectedAccountName) (#\(active.selectedAccountID))")
                    LabeledContent("Connected Since", value: active.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Last Used", value: active.lastUsedAt.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text("No server currently connected.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Security & Privacy") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Apple Keychain Storage", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Chatwoot access tokens are stored in Apple Keychain and are never written to the server-profile file. Distributed builds use a device-only protection class. A token is sent only to its selected Chatwoot server for authenticated requests.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Enforced Transport Security", systemImage: "network.badge.shield.half.filled")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("All network communication mandates TLS/HTTPS encryption with system-trusted certificates. Plain HTTP is only permitted on localhost during debug sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("AI Research & Intelligence") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("WootDesk AI Gateway", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Advanced AI features (conversation summarisation, smart draft replies, and deep cited research) are designed to route through an authenticated, privacy-preserving server gateway. No raw OpenAI keys or Chatwoot tokens are exposed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("About WootDesk") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WootDesk is an independent native client for Chatwoot. It is not affiliated with, maintained by, or endorsed by Chatwoot. The Chatwoot name and marks belong to their respective owners.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionText)
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 400)
        #endif
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

#Preview("Settings") {
    let profile = PreviewData.profile
    let environment = AppEnvironment.preview(
        profiles: [profile],
        activeProfileID: profile.id,
        tokens: [profile.id: "test"]
    )
    let appModel = AppModel(environment: environment)
    appModel.applyPreviewState(profiles: [profile], activeProfile: profile, token: "test")

    return NavigationStack {
        SettingsView(appModel: appModel)
    }
    .environment(\.appEnvironment, environment)
}
