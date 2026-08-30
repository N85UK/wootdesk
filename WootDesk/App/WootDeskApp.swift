import SwiftUI

@main
struct WootDeskApp: App {
    @State private var environment: AppEnvironment
    @State private var appModel: AppModel

    init() {
        // `--uitesting` gives UI tests a deterministic first-run state: no saved
        // profiles, no Keychain access, and no network calls.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let environment = isUITesting ? AppEnvironment.preview() : AppEnvironment.live()
        self._environment = State(initialValue: environment)
        self._appModel = State(initialValue: AppModel(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            MainAppView(appModel: appModel)
                .environment(\.appEnvironment, environment)
                .task {
                    await appModel.initialize()
                }
        }
        .commands {
            SidebarCommands()
            CommandGroup(after: .newItem) {
                Button("Add Server Connection...") {
                    appModel.showAddConnectionSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView(appModel: appModel)
                .environment(\.appEnvironment, environment)
        }
        #endif
    }
}

/// Root multiplatform container view.
struct MainAppView: View {
    @Bindable var appModel: AppModel
    @Environment(\.appEnvironment) private var environment

    /// Owned here so that both the conversation list and the detail column read
    /// the same selection on macOS.
    @State private var conversationState = ConversationListState()

    var body: some View {
        Group {
            if appModel.isInitializing {
                launchingView
            } else if appModel.profiles.isEmpty {
                firstRunEmptyState
            } else if appModel.activeProfile == nil {
                profileRecoveryState
            } else {
                #if os(macOS)
                macOSLayout
                #else
                iOSLayout
                #endif
            }
        }
        .sheet(isPresented: $appModel.showAddConnectionSheet) {
            AddConnectionView(
                onSaveSuccess: { displayName, url, token, account in
                    try await appModel.addConnection(
                        displayName: displayName,
                        baseURL: url,
                        token: token,
                        account: account
                    )
                }
            )
            .environment(\.appEnvironment, environment)
        }
    }

    private var profileRecoveryState: some View {
        NavigationStack {
            ConnectionListView(appModel: appModel)
                .safeAreaInset(edge: .top) {
                    if let error = appModel.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial)
                            .accessibilityLabel("Connection error: \(error)")
                    }
                }
        }
    }

    private var launchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading WootDesk...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - First Run Empty State

    private var firstRunEmptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Welcome to WootDesk")
                    .font(.largeTitle.bold())

                Text("A native client for the Chatwoot servers you control.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                appModel.showAddConnectionSheet = true
            } label: {
                Label("Add Chatwoot Server", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            if let error = appModel.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - macOS Three-Column Layout

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            macOSSidebar
        } content: {
            switch appModel.selectedNavigationItem {
            case .connections:
                ConnectionListView(appModel: appModel)
            case .settings:
                SettingsView(appModel: appModel)
            case .conversations, .none:
                ConversationListView(appModel: appModel, state: conversationState)
            }
        } detail: {
            switch appModel.selectedNavigationItem {
            case .conversations, .none:
                ConversationDetailView(conversation: conversationState.selectedConversation)
            default:
                ConversationDetailView(conversation: nil)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var macOSSidebar: some View {
        List(selection: $appModel.selectedNavigationItem) {
            Section("Workspace") {
                Label("Conversations", systemImage: "bubble.left.and.bubble.right")
                    .tag(AppModel.NavigationItem.conversations(status: .open))
            }

            Section("Server Profiles") {
                ForEach(appModel.profiles) { profile in
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
                                    .accessibilityLabel("Active profile")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(appModel.isSwitchingProfile)
                    .accessibilityHint("Switch to this Chatwoot server profile")
                }

                Label("Manage Servers", systemImage: "server.rack")
                    .tag(AppModel.NavigationItem.connections)
            }

            Section("Preferences") {
                Label("Settings", systemImage: "gearshape")
                    .tag(AppModel.NavigationItem.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        .toolbar {
            ToolbarItem {
                Button {
                    appModel.showAddConnectionSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .help("Add a Chatwoot server connection")
            }
        }
    }
    #endif

    // MARK: - iOS and iPadOS Layout

    #if os(iOS)
    private var iOSLayout: some View {
        TabView {
            NavigationStack {
                ConversationListView(appModel: appModel, state: conversationState)
                    .navigationDestination(item: $conversationState.selectedConversationID) { id in
                        ConversationDetailView(
                            conversation: conversationState.conversations.first { $0.id == id }
                        )
                    }
            }
            .tabItem {
                Label("Conversations", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationStack {
                ConnectionListView(appModel: appModel)
            }
            .tabItem {
                Label("Servers", systemImage: "server.rack")
            }

            NavigationStack {
                SettingsView(appModel: appModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
    #endif
}
