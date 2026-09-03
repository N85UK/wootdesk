import SwiftUI

/// Lets the agent choose whether WootDesk keeps drafts and previously loaded
/// messages on the device.
///
/// Switching the setting off deletes what is already stored, so the control is
/// a deletion as well as a preference.
public struct OfflineStorageSettingsSection: View {
    private let store: ToggleableOfflineStore
    private let knownProfileIDs: [UUID]

    @State private var isEnabled: Bool
    @State private var isApplying = false
    @State private var errorMessage: String?

    public init(store: ToggleableOfflineStore, knownProfileIDs: [UUID]) {
        self.store = store
        self.knownProfileIDs = knownProfileIDs
        self._isEnabled = State(initialValue: store.isPersisting)
    }

    public var body: some View {
        Section("Offline Storage") {
            Toggle("Keep Drafts and Recent Messages", isOn: $isEnabled)
                .disabled(isApplying)
                .accessibilityIdentifier("offline-storage-toggle")
                .accessibilityHint("Saves unsent drafts and recently loaded messages on this device")
                .onChange(of: isEnabled) { _, newValue in
                    apply(newValue)
                }

            Text("When this is on, unsent drafts and the messages you have already loaded are saved on this device so you can keep working through a lost connection. They are stored per server profile, protected at rest, excluded from device backups, and deleted when you remove the profile. Chatwoot access tokens are never stored here; they stay in the Apple Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("When this is off, WootDesk keeps nothing on the device and deletes anything it had already saved. Connecting, browsing conversations and replying all continue to work while you are online.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func apply(_ newValue: Bool) {
        isApplying = true
        errorMessage = nil
        Task {
            do {
                try await store.apply(enabled: newValue, knownProfileIDs: knownProfileIDs)
            } catch {
                // The preference itself was already recorded, so only the purge
                // can have failed. The agent is told rather than being left to
                // assume the stored content is gone.
                errorMessage = String(
                    localized: "The setting was saved, but the content already stored could not be deleted. Removing the server profile will delete it.",
                    comment: "Shown when purging stored offline content fails"
                )
            }
            isApplying = false
        }
    }
}
