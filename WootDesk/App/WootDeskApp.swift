import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var availabilityState: AgentAvailabilityState

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
        self._availabilityState = State(
            initialValue: AgentAvailabilityState(apiClient: environment.apiClient)
        )
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
            MainAppView(
                appModel: appModel,
                notificationState: notificationState,
                availabilityState: availabilityState
            )
                .environment(\.appEnvironment, environment)
                .task {
                    await appModel.initialize()
                    await notificationState.updateProfileContext(
                        profiles: appModel.profiles,
                        activeProfile: appModel.activeProfile
                    )
                    await availabilityState.load(
                        profile: appModel.activeProfile,
                        token: appModel.activeToken
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
            SettingsView(
                appModel: appModel,
                notificationState: notificationState,
                availabilityState: availabilityState
            )
                .environment(\.appEnvironment, environment)
        }
        #endif
    }
}

/// Root multiplatform container view.
struct MainAppView: View {
    @Bindable var appModel: AppModel
    let notificationState: PushNotificationState
    let availabilityState: AgentAvailabilityState
    @Environment(\.appEnvironment) private var environment

    /// Owned here so that both the conversation list and the detail column read
    /// the same selection on macOS.
    @State private var conversationState = ConversationListState()
    @State private var conversationDetailState = ConversationDetailState()
    @State private var conversationTriageState = ConversationTriageState()
    @State private var routeCoordinator = ConversationRouteCoordinator()

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
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = routeCoordinator.errorMessage {
                notificationRouteBanner(message)
            }
        }
        .sheet(isPresented: $appModel.showAddConnectionSheet) {
            AddConnectionView(
                onSaveSuccess: { displayName, url, token, account, agentID in
                    try await appModel.addConnection(
                        displayName: displayName,
                        baseURL: url,
                        token: token,
                        account: account,
                        agentID: agentID
                    )
                }
            )
            .environment(\.appEnvironment, environment)
        }
        .onChange(of: ActiveProfileDataContext(profile: appModel.activeProfile)) { _, _ in
            if !routeCoordinator.isOpening {
                ConversationWorkspaceReset.clearProfileData(
                    list: conversationState,
                    detail: conversationDetailState,
                    triage: conversationTriageState
                )
            }
            availabilityState.clear()
            Task {
                await notificationState.updateProfileContext(
                    profiles: appModel.profiles,
                    activeProfile: appModel.activeProfile
                )
                await availabilityState.load(
                    profile: appModel.activeProfile,
                    token: appModel.activeToken
                )
            }
        }
        .onChange(of: conversationTriageState.conversation) { _, confirmed in
            guard let confirmed else { return }
            conversationState.applyConfirmedConversation(confirmed)
        }
        .onChange(of: notificationState.pendingRoute) { _, route in
            guard let route else { return }
            Task {
                await openNotificationRoute(route)
            }
        }
    }

    private func notificationRouteBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.badge.slash")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Dismiss") { routeCoordinator.dismissError() }
                .buttonStyle(.borderless)
                .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification could not be opened. \(message)")
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
        await routeCoordinator.open(
            route: route,
            appModel: appModel,
            listState: conversationState,
            detailState: conversationDetailState,
            triageState: conversationTriageState,
            using: environment.apiClient
        )
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
            WorkspaceSidebarView(appModel: appModel, availabilityState: availabilityState)
        } content: {
            workspaceContent
        } detail: {
            workspaceDetail
        }
        .navigationSplitViewStyle(.balanced)
    }
    #endif

    // MARK: - Shared Split-View Columns

    /// The middle column of the Mac and iPad split layouts.
    @ViewBuilder
    private var workspaceContent: some View {
        switch appModel.selectedNavigationItem {
        case .connections:
            ConnectionListView(appModel: appModel)
        case .settings:
            SettingsView(
                appModel: appModel,
                notificationState: notificationState,
                availabilityState: availabilityState
            )
        case .conversations, .none:
            ConversationListView(
                appModel: appModel,
                state: conversationState,
                presentation: .splitViewSelection
            )
        }
    }

    /// The trailing column of the Mac and iPad split layouts.
    @ViewBuilder
    private var workspaceDetail: some View {
        switch appModel.selectedNavigationItem {
        case .conversations, .none:
            ConversationDetailView(
                appModel: appModel,
                state: conversationDetailState,
                triageState: conversationTriageState,
                conversation: conversationState.selectedConversation
            )
        default:
            ConversationDetailView(
                appModel: appModel,
                state: conversationDetailState,
                triageState: conversationTriageState,
                conversation: nil
            )
        }
    }

    // MARK: - iOS and iPadOS Layout

    #if os(iOS)
    /// iPad presents the same three adjacent areas as the Mac. iPhone keeps the
    /// tab layout, because a split view has no second column to show there.
    ///
    /// The choice follows the device idiom rather than the size class, so that
    /// resizing an iPad window does not swap one navigation structure for
    /// another. `NavigationSplitView` collapses itself when the window becomes
    /// too narrow, preserving the selected workspace and conversation.
    @ViewBuilder
    private var iOSLayout: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            WorkspaceSidebarView(appModel: appModel, availabilityState: availabilityState)
        } content: {
            workspaceContent
        } detail: {
            workspaceDetail
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var iPhoneLayout: some View {
        TabView {
            NavigationStack {
                ConversationListView(
                    appModel: appModel,
                    state: conversationState,
                    presentation: .navigationStack
                )
                .navigationDestination(item: $conversationState.selectedConversationID) { id in
                    ConversationDetailView(
                        appModel: appModel,
                        state: conversationDetailState,
                        triageState: conversationTriageState,
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
                SettingsView(
                    appModel: appModel,
                    notificationState: notificationState,
                    availabilityState: availabilityState
                )
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
    #endif
}

struct ActiveProfileDataContext: Equatable {
    let profileID: UUID?
    let baseURL: URL?
    let accountID: Int?
    /// Included because filling in a missing agent identity has to count as a
    /// change. Without it the observer that re-enrols this device with the push
    /// gateway never fires, so the gateway keeps an identity-less registration
    /// and excludes the device from every assigned conversation.
    let agentID: Int?

    init(profile: ServerProfile?) {
        profileID = profile?.id
        baseURL = profile?.baseURL
        accountID = profile?.selectedAccountID
        agentID = profile?.agentID
    }
}
