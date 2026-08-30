import SwiftUI

/// View presented when a Chatwoot profile belongs to multiple accounts.
public struct AccountPickerView: View {
    public let accounts: [ChatwootAccount]
    public let onSelect: (ChatwootAccount) -> Void
    public let onCancel: () -> Void
    public let confirmTitle: String
    public let isWorking: Bool

    @State private var selectedAccountID: Int?

    public init(
        accounts: [ChatwootAccount],
        onSelect: @escaping (ChatwootAccount) -> Void,
        onCancel: @escaping () -> Void,
        confirmTitle: String = "Connect Account",
        isWorking: Bool = false
    ) {
        self.accounts = accounts
        self.onSelect = onSelect
        self.onCancel = onCancel
        self.confirmTitle = confirmTitle
        self.isWorking = isWorking
        self._selectedAccountID = State(initialValue: accounts.first?.id)
    }

    public var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Select Chatwoot Account")
                    .font(.title2.bold())

                Text("Your profile has access to multiple accounts on this server. Choose which account you would like WootDesk to manage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top)

            List(accounts, selection: $selectedAccountID) { account in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.headline)
                        if let role = account.role {
                            Text("Role: \(role.capitalized)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if selectedAccountID == account.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Selected")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAccountID = account.id
                }
                .tag(account.id)
            }
            .listStyle(.inset)
            .frame(minHeight: 180, maxHeight: 280)

            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isWorking)

                Button {
                    if let selected = accounts.first(where: { $0.id == selectedAccountID }) {
                        onSelect(selected)
                    }
                } label: {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Saving server profile")
                    } else {
                        Text(confirmTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAccountID == nil || isWorking)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
        }
        .padding()
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 400)
        #endif
    }
}

#Preview("Account Picker: Multiple Accounts") {
    AccountPickerView(
        accounts: PreviewData.multipleAccounts,
        onSelect: { _ in },
        onCancel: {}
    )
}
