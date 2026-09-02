import SwiftUI

/// First-run and add-server connection sheet.
public struct AddConnectionView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    var onSaveSuccess: ((String, URL, String, ChatwootAccount, Int?) async throws -> Void)?

    @State private var state = ConnectionViewState()
    @State private var operationTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    /// Runs validation as soon as the view appears. Used by previews so they show
    /// the genuine in-progress, error, and account-picker states.
    private let validatesOnAppear: Bool
    private let mode: ConnectionEditorMode

    private enum Field: Hashable {
        case displayName
        case serverURL
        case token
    }

    public init(
        initialURL: String = "",
        initialToken: String = "",
        initialDisplayName: String = "",
        mode: ConnectionEditorMode = .add,
        validatesOnAppear: Bool = false,
        onSaveSuccess: ((String, URL, String, ChatwootAccount, Int?) async throws -> Void)? = nil
    ) {
        self._state = State(initialValue: ConnectionViewState(
            initialURL: initialURL,
            initialToken: initialToken,
            initialDisplayName: initialDisplayName
        ))
        self.validatesOnAppear = validatesOnAppear
        self.mode = mode
        self.onSaveSuccess = onSaveSuccess
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    if state.isSelectingAccount {
                        AccountPickerView(
                            accounts: state.discoveredAccounts,
                            onSelect: { selectedAccount in
                                startOperation {
                                    await saveAndDismiss(account: selectedAccount)
                                }
                            },
                            onCancel: {
                                state.isSelectingAccount = false
                            },
                            confirmTitle: mode == .add ? "Connect Account" : "Save Account",
                            isWorking: state.isSaving
                        )
                    } else {
                        formSection
                    }
                }
                .padding()
            }
            .navigationTitle(mode == .add ? "Add Chatwoot Server" : "Edit Chatwoot Server")
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 480)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        operationTask?.cancel()
                        dismiss()
                    }
                    .disabled(state.isValidating || state.isSaving)
                }

                if !state.isSelectingAccount {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(mode == .add ? "Connect" : "Validate and Save") {
                            startOperation {
                                await validateAndProceed()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            state.serverURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || state.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || state.isValidating
                                || state.isSaving
                        )
                    }
                }
            }
        }
        .onAppear {
            if state.serverURLString.isEmpty {
                focusedField = .serverURL
            }
        }
        .task {
            guard validatesOnAppear else { return }
            await validateAndProceed()
        }
        .onDisappear {
            operationTask?.cancel()
        }
        .interactiveDismissDisabled(state.isValidating || state.isSaving)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(mode == .add ? "Connect to Chatwoot" : "Revalidate Chatwoot Connection")
                .font(.title2.bold())

            Text("Enter the address of your Chatwoot instance and your personal API access token to connect WootDesk.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Server Address")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                TextField("https://chatwoot.example.com", text: $state.serverURLString)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .focused($focusedField, equals: .serverURL)
                    .accessibilityLabel("Chatwoot Server URL")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Personal Access Token")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                SecureField("Paste your API access token", text: $state.token)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .focused($focusedField, equals: .token)
                    .accessibilityLabel("Personal Access Token")

                Link(
                    "How to find your personal access token",
                    destination: URL(string: "https://www.chatwoot.com/hc/user-guide/articles/1757445004-how-to-find-your-personal-access-token-in-chatwoot")!
                )
                .font(.caption)
                .accessibilityHint("Opens Chatwoot's token help in your browser")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name (Optional)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                TextField("e.g. Acme Support", text: $state.displayName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .displayName)
                    .accessibilityLabel("Optional Display Name")
            }

            if let errorMessage = state.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if state.isValidating {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Validating connection to Chatwoot...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
    }

    private func validateAndProceed() async {
        let outcome = await state.validate(using: environment.apiClient, isDebug: environment.isDebug)
        switch outcome {
        case .singleAccount(let account, _, _, _, _):
            await saveAndDismiss(account: account)
        case .multipleAccounts:
            // State automatically switches to account selection
            break
        case .failure:
            // Error displayed inline
            break
        }
    }

    private func startOperation(_ operation: @escaping @MainActor () async -> Void) {
        operationTask?.cancel()
        operationTask = Task { @MainActor in
            await operation()
        }
    }

    private func saveAndDismiss(account: ChatwootAccount) async {
        guard let url = state.validatedURL else { return }
        state.isSaving = true
        defer { state.isSaving = false }
        do {
            if let onSaveSuccess {
                try await onSaveSuccess(
                    state.displayName,
                    url,
                    state.validatedToken,
                    account,
                    state.validatedAgentID
                )
            }
            dismiss()
        } catch {
            state.errorMessage = "Failed to save the server profile: \(error.localizedDescription)"
        }
    }
}

public enum ConnectionEditorMode: Sendable, Equatable {
    case add
    case edit
}

// MARK: - Previews

/// Drives the setup sheet against a stubbed API so each preview reaches the real
/// state it is named for.
@MainActor
private func previewSetup(
    profile: StubChatwootAPI.Outcome<StubChatwootAPI.ProfileResult>,
    validatesOnAppear: Bool
) -> some View {
    AddConnectionView(
        initialURL: validatesOnAppear ? "https://chatwoot.example.com" : "",
        initialToken: validatesOnAppear ? "preview-token" : "",
        validatesOnAppear: validatesOnAppear
    )
    .environment(\.appEnvironment, .preview(apiClient: StubChatwootAPI(profileOutcome: profile)))
}

#Preview("Setup: First Run") {
    previewSetup(
        profile: .success(.init(name: "Sample Agent", accounts: [PreviewData.singleAccount])),
        validatesOnAppear: false
    )
}

#Preview("Setup: Validating") {
    previewSetup(profile: .pending, validatesOnAppear: true)
}

#Preview("Setup: Invalid Token") {
    previewSetup(profile: .failure(.unauthorized), validatesOnAppear: true)
}

#Preview("Setup: Multiple Accounts") {
    previewSetup(
        profile: .success(.init(name: "Sample Agent", accounts: PreviewData.multipleAccounts)),
        validatesOnAppear: true
    )
}
