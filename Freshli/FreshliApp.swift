import SwiftUI
import SwiftData
import WidgetKit
import os

@main
struct FreshliApp: App {
    // Built once with cloudKitDatabase: .none — prevents SwiftData from auto-enabling
    // CloudKit sync, which requires all model attributes to be optional/have defaults
    // and injects remote-notification background mode requirements.
    // Supabase (SyncService) is the sync layer; SwiftData is local-only storage.
    private static let modelContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(cloudKitDatabase: .none)
            return try ModelContainer(
                for: FreshliItem.self, SharedListing.self, UserProfile.self,
                configurations: config
            )
        } catch {
            fatalError("SwiftData ModelContainer failed: \(error)")
        }
    }()
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var celebrationManager = CelebrationManager()
    @State private var authManager = AuthManager()
    @State private var syncService = SyncService()
    @State private var communityService = CommunityService()
    @State private var toastManager = FLToastManager()
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var diagnosticsService = DiagnosticsService.shared
    @State private var offlineSyncQueue = OfflineSyncQueue.shared
    @State private var subscriptionService = SubscriptionService()
    @State private var familySyncService = FamilySyncService()
    @State private var shoppingListService = ShoppingListService()

    // MARK: - Splash → Dashboard Transition State
    @Namespace private var splashNamespace
    @State private var showSplash = true
    @State private var splashTransitioning = false
    @State private var dataPrefetched = false
    @State private var sessionValidated = false
    @State private var splashProgress: CGFloat = 0
    /// Enforces a minimum splash display time so the branded loading screen
    /// is always visible even when auth resolves instantly (e.g. no saved session).
    @State private var splashMinimumTimeMet = false

    private let logger = Logger(subsystem: "com.freshli.app", category: "AppLifecycle")

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    // Step 1: Onboarding (first launch only)
                    OnboardingView {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        withAnimation(FLMotion.springDefault) {
                            hasCompletedOnboarding = true
                        }
                    }
                } else if showSplash {
                    // Step 2: Freshli Signature Loading Experience
                    // Shown until BOTH auth resolves AND the minimum time has elapsed.
                    FreshliSplashView(
                        splashNamespace: splashNamespace,
                        onSessionValidated: {
                            sessionValidated = true
                            checkAndTransition()
                        },
                        onDataPrefetched: {
                            dataPrefetched = true
                            checkAndTransition()
                        }
                    )
                    .transition(.opacity)
                } else {
                    // Step 3: Main app content
                    mainAppContent
                        // Solid background prevents any white flash during the
                        // fade-in transition from the splash screen.
                        .background(PSColors.backgroundPrimary.ignoresSafeArea())
                        .splashTransition(
                            isTransitioning: splashTransitioning,
                            namespace: splashNamespace
                        )
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }
            }
            // Dark splash background applied to the root Group so the window
            // is never black while services and SwiftData initialise.
            // FreshliSplashView overlays its own animated content on top of this.
            .background(Color(hex: 0x051A0D).ignoresSafeArea())
            .celebrationOverlay(manager: celebrationManager)
            .toastOverlay(manager: toastManager)
            .environment(celebrationManager)
            .environment(authManager)
            .environment(syncService)
            .environment(communityService)
            .environment(toastManager)
            .environment(networkMonitor)
            .environment(offlineSyncQueue)
            .environment(subscriptionService)
            .environment(familySyncService)
            .environment(shoppingListService)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .task {
                // Start diagnostics and network monitoring
                diagnosticsService.start()
                networkMonitor.start()

                logger.info("FreshliApp: Restoring session...")
                splashProgress = 0.2

                // Enforce minimum splash display time (2.5 s) in parallel with auth restore.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    splashMinimumTimeMet = true
                    checkAndTransition()
                }

                // Restore auth session
                await authManager.restoreSession()

                logger.info("FreshliApp: Session restored, state = \(String(describing: authManager.authState))")
                splashProgress = 0.6
                sessionValidated = true

                // Pre-fetch data during splash if authenticated
                if authManager.authState == .authenticated {
                    logger.info("FreshliApp: Pre-fetching pantry data...")
                    splashProgress = 0.75
                    // Pre-fetch happens in AppTabView.task, but signal readiness
                    splashProgress = 0.95
                }

                // Set up notifications
                let notificationService = NotificationService()
                notificationService.registerCategories()
                await notificationService.requestAuthorization()

                splashProgress = 1.0
                dataPrefetched = true

                // Trigger transition (only fires if minimum time is also met)
                checkAndTransition()
            }
            .task(id: authManager.authState) {
                // Listen for auth changes when authenticated
                if authManager.authState == .authenticated {
                    await authManager.listenForAuthChanges()
                }

                // Re-check transition whenever auth state changes —
                // checkAndTransition also guards on splashMinimumTimeMet so it is safe.
                if authManager.authState != .loading && showSplash {
                    checkAndTransition()
                }
            }
            .onChange(of: networkMonitor.isConnected) { oldValue, newValue in
                // When connectivity is restored, process offline queue
                if !oldValue && newValue {
                    Task {
                        await offlineSyncQueue.processQueue(using: syncService)
                    }
                }
            }
        }
        .modelContainer(Self.modelContainer)
    }

    // MARK: - Main App Content (post-splash)

    @ViewBuilder
    private var mainAppContent: some View {
        switch authManager.authState {
        case .loading:
            // Fallback if splash dismissed early
            ProgressView()
                .tint(FLColors.primaryGreen)
        case .unauthenticated:
            if authManager.hasDeclinedAuth {
                // User previously tapped "Continue without account"
                AppTabView()
            } else {
                // First time after onboarding — offer sign in/up
                AuthView()
            }
        case .authenticated:
            // Authenticated — full app with cloud sync
            AppTabView()
        }
    }

    // MARK: - Splash → Dashboard Transition

    private func checkAndTransition() {
        // Transition only when auth resolved, minimum time elapsed, AND all data/notifications ready
        guard authManager.authState != .loading else { return }
        guard splashMinimumTimeMet else { return }
        guard dataPrefetched else { return }
        guard showSplash else { return }

        logger.info("FreshliApp: Transitioning from splash → main content")

        // Spring unfold animation (stiffness: 120, damping: 20)
        withAnimation(
            .spring(
                Spring(mass: 1.0, stiffness: 120, damping: 20)
            )
        ) {
            splashTransitioning = true
        }

        // After a brief moment, swap views
        withAnimation(
            .spring(
                Spring(mass: 1.0, stiffness: 120, damping: 20)
            ).delay(0.15)
        ) {
            showSplash = false
        }

        // Reset transitioning state
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            splashTransitioning = false
        }
    }
}
