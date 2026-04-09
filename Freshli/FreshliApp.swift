import SwiftUI
import SwiftData
import WidgetKit
import os

@main
struct FreshliApp: App {
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
                } else if showSplash && authManager.authState == .loading {
                    // Step 2: Freshli Signature Loading Experience
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

                // Trigger transition
                checkAndTransition()
            }
            .task(id: authManager.authState) {
                // Listen for auth changes when authenticated
                if authManager.authState == .authenticated {
                    await authManager.listenForAuthChanges()
                }

                // Auto-dismiss splash when auth state resolves
                if authManager.authState != .loading && showSplash {
                    // Small delay to let animation complete
                    try? await Task.sleep(for: .milliseconds(600))
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                // Update widget data when app goes to background
                if let container = try? ModelContainer(for: FreshliItem.self, UserProfile.self) {
                    WidgetDataService.updateWidgetData(modelContext: container.mainContext)
                }
            }
        }
        .modelContainer(for: [FreshliItem.self, SharedListing.self, UserProfile.self])
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
        // Only transition when auth state has resolved
        guard authManager.authState != .loading else { return }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            splashTransitioning = false
        }
    }
}
