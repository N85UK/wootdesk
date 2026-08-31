import SwiftUI

struct NotificationSettingsSection: View {
    @Bindable var state: PushNotificationState
    @State private var gatewayAddress = ""
    @State private var gatewayAPIToken = ""
    @State private var showingRemoveConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case gatewayAddress
        case gatewayAPIToken
    }

    var body: some View {
        Section("Notifications") {
            LabeledContent("Permission", value: authorisationDescription)
            LabeledContent("Apple Registration", value: registrationDescription)
            LabeledContent("Remote Delivery", value: gatewayDescription)

            VStack(alignment: .leading, spacing: 6) {
                Label("New Message Alerts", systemImage: "bell.badge")
                    .font(.headline)

                Text("WootDesk registers with Apple and can enrol this saved server profile with an authenticated WootDesk Push Gateway. The gateway receives no Chatwoot personal access token.")
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

            if let errorMessage = state.gatewayErrorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Push gateway error: \(errorMessage)")
            }

            notificationActions

            gatewayConfiguration
        }
        .task {
            await state.refreshAuthorisationStatus()
            populateGatewayAddress()
        }
        .onChange(of: state.gatewaySummary) { _, _ in
            populateGatewayAddress()
        }
        .confirmationDialog(
            "Disable Remote Notifications?",
            isPresented: $showingRemoveConfirmation
        ) {
            Button("Disable Remote Notifications", role: .destructive) {
                Task {
                    await state.removeGatewayRegistration()
                    if state.gatewaySummary == nil {
                        gatewayAddress = ""
                        gatewayAPIToken = ""
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("WootDesk will ask the push gateway to remove this device registration, then delete the gateway credential for the active profile from Apple Keychain.")
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

    @ViewBuilder
    private var gatewayConfiguration: some View {
        if state.authorisationStatus.allowsNotifications {
            Divider()

            TextField("Push Gateway Address", text: $gatewayAddress, prompt: Text("https://push.example.com"))
                .textContentType(.URL)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
                .focused($focusedField, equals: .gatewayAddress)
                .accessibilityLabel("WootDesk Push Gateway address")
                .onSubmit { focusedField = .gatewayAPIToken }

            SecureField("Device API Token", text: $gatewayAPIToken)
                .textContentType(.password)
                .focused($focusedField, equals: .gatewayAPIToken)
                .accessibilityLabel("WootDesk Push Gateway device API token")
                .onSubmit { enrolDeviceIfPossible() }

            Text("Use the HTTPS address and device API token issued by your gateway administrator. Do not enter a Chatwoot personal access token here. The token is saved only in Apple Keychain for this server profile.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(state.gatewaySummary == nil ? "Enrol This Device" : "Update Enrolment") {
                    enrolDeviceIfPossible()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canEnrolDevice)
                .accessibilityHint("Sends this app's APNs device token and opaque profile routing identifiers to the configured push gateway")

                if state.isGatewayWorking {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Updating push gateway enrolment")
                }

                Spacer()

                if state.gatewaySummary != nil {
                    Button("Disable Remote Notifications", role: .destructive) {
                        showingRemoveConfirmation = true
                    }
                    .disabled(state.isGatewayWorking)
                }
            }

            if !state.hasCurrentDeviceToken {
                Text("Waiting for Apple Push Notification service to register this signed app. A development or distribution build with the Push Notifications capability is required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canEnrolDevice: Bool {
        state.hasCurrentDeviceToken
            && !state.isGatewayWorking
            && !gatewayAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !gatewayAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func enrolDeviceIfPossible() {
        guard canEnrolDevice else { return }
        focusedField = nil
        Task {
            await state.configureGateway(
                baseURL: gatewayAddress,
                apiToken: gatewayAPIToken
            )
            if state.gatewaySummary != nil {
                gatewayAPIToken = ""
            }
        }
    }

    private func populateGatewayAddress() {
        guard gatewayAddress.isEmpty, let summary = state.gatewaySummary else { return }
        gatewayAddress = summary.baseURL.absoluteString
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

    private var gatewayDescription: String {
        switch state.gatewayStatus {
        case .notConfigured:
            "Not configured"
        case .awaitingAppleRegistration:
            "Waiting for Apple registration"
        case .enrolling:
            "Updating"
        case .enrolled(let host):
            "Enabled via \(host)"
        case .failed:
            "Needs attention"
        }
    }
}
