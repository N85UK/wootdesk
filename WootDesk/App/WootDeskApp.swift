import SwiftUI

@main
struct WootDeskApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(WootDeskApplicationDelegate.self) private var applicationDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(WootDeskApplicationDelegate.self) private var applicationDelegate
    #endif

    @State private var environment: AppEnvironment
    @State private var appModel: AppModel
    @State private var notificationState: PushNotificationState

    init() {
        // `--uitesting` gives UI tests a deterministic first-run state: no saved
        // profiles, no Keychain access, and no network calls.
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("--uitesting")
        let isConversationUITesting = arguments.contains("--uitesting-conversations")
        let environment: AppEnvironment
        if isConversationUITesting {
            let profile = PreviewData.profile
            environment = AppEnvironment.preview(
                profiles: [profile],
                activeProfileID: profile.id,
                tokens: [profile.id: "test"],
                apiClient: StubChatwootAPI()
            )
        } else if isUITesting {
            environment = AppEnvironment.preview()
        } else {
            environment = AppEnvironment.live()
        }
        self._environment = State(initialValue: environment)
        self._appModel = State(initialValue: AppModel(environment: environment))
        let notificationPermissionClient: NotificationPermissionClient = if isUITesting || isConversationUITesting {
            InMemoryNotificationPermissionClient(status: .notDetermined)
        } else {
            SystemNotificationPermissionClient()
        }
        self._notificationState = State(
            initialValue: PushNotificationState(
                permissionClient: notificationPermissionClient,
                gatewayManager: environment.pushGatewayManager
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            MainAppView(appModel: appModel, notificationState: notificationState)
                .environment(\.appEnvironment, environment)
                .task {
                    await appModel.initialize()
                    await notificationState.updateProfileContext(
                        profiles: appModel.profiles,
                        activeProfile: appModel.activeProfile
                    )
                    await applicationDelegate.configureNotifications(using: notificationState)
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
            SettingsView(appModel: appModel, notificationState: notificationState)
                .environment(\.appEnvironment, environment)
        }
        #endif
    }
}

/// Root multiplatform container view.
struct MainAppView: View {
    @Bindable var appModel: AppModel
    let notificationState: PushNotificationState
    @Environment(\.appEnvironment) private var environment

    /// Owned here so that both the conversation list and the detail column read
    /// the same selection on macOS.
    @State private var conversationState = ConversationListState()
    @State private var conversationDetailState = ConversationDetailState()

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
        .onChange(of: ActiveProfileDataContext(profile: appModel.activeProfile)) { _, _ in
            conversationState.clear()
            conversationDetailState.clear()
            Task {
                await notificationState.updateProfileContext(
                    profiles: appModel.profiles,
                    activeProfile: appModel.activeProfile
                )
            }
        }
        .onChange(of: notificationState.pendingRoute) { _, route in
            guard let route else { return }
            Task {
                await openNotificationRoute(route)
            }
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

    private func openNotificationRoute(_ route: PushNotificationRoute) async {
        defer { notificationState.clearPendingRoute() }
        guard await appModel.activateNotificationRoute(route),
              let profile = appModel.activeProfile,
              let token = appModel.activeToken else {
            return
        }

        conversationDetailState.clear()
        conversationState.statusFilter = nil
        await conversationState.loadConversations(
            profile: profile,
            token: token,
            using: environment.apiClient
        )
        if conversationState.conversations.contains(where: { $0.id == route.conversationID }) {
            conversationState.selectedConversationID = route.conversationID
        } else if conversationState.errorMessage == nil {
            conversationState.errorMessage = "The notified conversation was not present in the first loaded page. Refresh or search for conversation #\(route.conversationID)."
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
                SettingsView(appModel: appModel, notificationState: notificationState)
            case .conversations, .none:
                ConversationListView(appModel: appModel, state: conversationState)
            }
        } detail: {
            switch appModel.selectedNavigationItem {
            case .conversations, .none:
                ConversationDetailView(
                    appModel: appModel,
                    state: conversationDetailState,
                    conversation: conversationState.selectedConversation
                )
            default:
                ConversationDetailView(
                    appModel: appModel,
                    state: conversationDetailState,
                    conversation: nil
                )
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
                            appModel: appModel,
                            state: conversationDetailState,
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
                SettingsView(appModel: appModel, notificationState: notificationState)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
    #endif
}

private struct ActiveProfileDataContext: Equatable {
    let profileID: UUID?
    let baseURL: URL?
    let accountID: Int?

    init(profile: ServerProfile?) {
        profileID = profile?.id
        baseURL = profile?.baseURL
        accountID = profile?.selectedAccountID
    }
}
