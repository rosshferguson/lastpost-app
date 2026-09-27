//
//  FinalFarewellApp.swift
//  FinalFarewell
//
//  Added:
//  - AppLockManager injected as @StateObject
//  - App shows AppLockView when isLocked == true
//  - scenePhase observer locks app on background if enabled, and refreshes
//    designations when app returns to foreground
//  - SubscriptionService injected as @StateObject
//  - IssueReporters.current replaced at launch to prevent Supabase SDK
//    debug-mode crash (xctest-dynamic-overlay / IssueReporting)
//

import SwiftUI
import SwiftData
import IssueReporting

// MARK: - Custom issue reporter (print-only, no preconditionFailure)

private struct LoggingIssueReporter: IssueReporter {
    func reportIssue(
        _ message: @autoclosure () -> String?,
        severity: IssueSeverity,
        fileID: StaticString,
        filePath: StaticString,
        line: UInt,
        column: UInt
    ) {
        print("[IssueReporting] \(message() ?? "(no message)") (\(fileID):\(line))")
    }
}

@main
struct FinalFarewellApp: App {
    let modelContainer: ModelContainer
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var deepLinkService = DeepLinkService()
    @StateObject private var lockManager = AppLockManager()
    @StateObject private var subscriptionService = SubscriptionService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Replace the default _DefaultReporter (which calls preconditionFailure
        // in debug builds) with our logging-only reporter. This must happen
        // before SupabaseClient is initialised so it is in place when
        // AuthClient.authStateChanges fires the initial-session event.
        IssueReporters.current = [LoggingIssueReporter()]

        do {
            let schema = Schema([
                User.self, Contact.self, DesignatedPerson.self,
                DeathNotification.self, SharedMedia.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialise ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(userViewModel)
                    .environmentObject(deepLinkService)
                    .environmentObject(lockManager)
                    .environmentObject(subscriptionService)
                    .onOpenURL { url in deepLinkService.handleDeepLink(url) }

                if lockManager.isLocked {
                    AppLockView(lockManager: lockManager)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: lockManager.isLocked)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                lockManager.lockIfNeeded()
            }
            if phase == .active {
                // Refresh designation state so the designated person list stays
                // current without requiring a sign-out / sign-in cycle.
                Task { await userViewModel.refreshDesignations() }
            }
        }
    }
}

// MARK: - Content view router

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var deepLinkService: DeepLinkService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenAuthPrompt") private var hasSeenAuthPrompt = false
    @AppStorage("isInDesignatedMode") private var isInDesignatedMode = false

    private var isPasswordReset: Bool {
        if case .passwordReset = deepLinkService.pendingDeepLink { return true }
        return false
    }

    private var isEmailConfirmed: Bool {
        deepLinkService.pendingDeepLink == .emailConfirmed
    }

    private var isEmailConfirmError: Bool {
        deepLinkService.pendingDeepLink == .emailConfirmError
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if !hasSeenAuthPrompt && !userViewModel.isAuthenticated {
                // Show auth screen after onboarding; user can skip to use app without account
                AuthView(onSkip: { hasSeenAuthPrompt = true })
                    .environmentObject(userViewModel)
                    .onAppear {
                        // Ensure currentUser is loaded so sign-in can link to local profile
                        if userViewModel.currentUser == nil {
                            userViewModel.setModelContext(modelContext)
                        }
                    }
            } else if isInDesignatedMode {
                DesignatedModeHostView()
            } else {
                MainTabView()
            }
        }
        .sheet(isPresented: Binding(
            get: { isPasswordReset },
            set: { if !$0 { deepLinkService.clearPendingLink() } }
        )) {
            if case .passwordReset(let url) = deepLinkService.pendingDeepLink {
                ChangePasswordView(resetURL: url)
            }
        }
        .alert("Email verified", isPresented: Binding(
            get: { isEmailConfirmed },
            set: { if !$0 { deepLinkService.clearPendingLink() } }
        )) {
            Button("Continue") { deepLinkService.clearPendingLink() }
        } message: {
            Text("Your email address has been confirmed. Last Post is ready to use.")
        }
        .alert("Verification failed", isPresented: Binding(
            get: { isEmailConfirmError },
            set: { if !$0 { deepLinkService.clearPendingLink() } }
        )) {
            Button("OK") { deepLinkService.clearPendingLink() }
        } message: {
            Text("The confirmation link may have expired. Sign in and request a new one from Settings.")
        }
    }
}

// MARK: - Designated mode host

struct DesignatedModeHostView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userViewModel: UserViewModel
    @StateObject private var notificationViewModel = NotificationViewModel()

    var body: some View {
        DesignatedModeView()
            .environmentObject(notificationViewModel)
            .onAppear {
                userViewModel.setModelContext(modelContext)
                notificationViewModel.setModelContext(modelContext)
            }
            .task {
                // Ensure the list of owners is up to date when entering designated mode
                await userViewModel.refreshDesignations()
            }
    }
}
