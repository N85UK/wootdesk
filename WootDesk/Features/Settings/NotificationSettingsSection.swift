import SwiftUI

struct NotificationSettingsSection: View {
    @Bindable var state: PushNotificationState

    var body: some View {
        Section("Notifications") {
            LabeledContent("Permission", value: authorisationDescription)
            LabeledContent("Apple Registration", value: registrationDescription)
            LabeledContent("Chatwoot Delivery", value: "Push service required")

            VStack(alignment: .leading, spacing: 6) {
                Label("New Message Alerts", systemImage: "bell.badge")
                    .font(.headline)

                Text("WootDesk can request notification permission and register this device with Apple. Delivery while the app is closed also requires a compatible WootDesk push service to relay new-message events from your Chatwoot server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            if let errorMessage = state.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Notification error: \(errorMessage)")
            }

            notificationActions
        }
        .task {
            await state.refreshAuthorisationStatus()
        }
    }

    @ViewBuilder
    private var notificationActions: some View {
        switch state.authorisationStatus {
        case .unknown, .notDetermined:
            Button("Enable Notifications") {
                Task { await state.requestAuthorisation() }
            }
            .disabled(state.isWorking)
            .accessibilityHint("Requests permission to show alerts, update the badge and play sounds")

        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications are disabled in System Settings. Allow notifications for WootDesk, then check again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Check Again") {
                    Task { await state.refreshAuthorisationStatus() }
                }
                .disabled(state.isWorking)
            }

        case .authorised, .provisional, .ephemeral:
            Button("Send Local Test Notification") {
                Task { await state.sendVerificationNotification() }
            }
            .disabled(state.isWorking)
            .accessibilityHint("Schedules an invented local notification without using Chatwoot data")
        }
    }

    private var authorisationDescription: String {
        switch state.authorisationStatus {
        case .unknown:
            "Checking"
        case .notDetermined:
            "Not requested"
        case .denied:
            "Disabled"
        case .authorised:
            "Enabled"
        case .provisional:
            "Provisional"
        case .ephemeral:
            "Temporary"
        }
    }

    private var registrationDescription: String {
        switch state.registrationStatus {
        case .idle:
            "Not registered"
        case .registering:
            "Registering"
        case .registeredWithApple:
            "Registered"
        case .failed:
            "Failed"
        }
    }
}
