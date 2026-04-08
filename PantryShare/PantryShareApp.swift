import SwiftUI
import SwiftData
import WidgetKit

@main
struct PantryShareApp: App {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var celebrationManager = CelebrationManager()
    @State private var authManager = AuthManager()
    @State private var syncService = SyncService()
    @State private var communityService = CommunityService()
    @State private var toastManager = PSToastManager()
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var diagnosticsService = DiagnosticsService.shared
    @State private var offlineSyncQueue = OfflineSyncQueue.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    // Step 1: Onboarding (first launch only)
                    OnboardingView {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        withAnimation(PSMotion.springDefault) {
                            hasCompletedOnboarding = true
                        }
                    }
                } else {
                    switch authManager.authState {
                    case .loading:
                        // Brief splash while restoring session
                        launchScreen
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
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .task {
                // Start diagnostics and network monitoring
                diagnosticsService.start()
                networkMonitor.start()

                // Restore auth session
                await authManager.restoreSession()

                // Set up notifications
                let notificationService = NotificationService()
                notificationService.registerCategories()
                await notificationService.requestAuthorization()
            }
            .task(id: authManager.authState) {
                // Listen for auth changes when authenticated
                if authManager.authState == .authenticated {
                    await authManager.listenForAuthChanges()
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
                if let container = try? ModelContainer(for: PantryItem.self, UserProfile.self) {
                    WidgetDataService.updateWidgetData(modelContext: container.mainContext)
                }
            }
        }
        .modelContainer(for: [PantryItem.self, SharedListing.self, UserProfile.self])
    }

    // MARK: - Launch Screen (shown while restoring auth session)

    @State private var launchIconScale: CGFloat = 0.6
    @State private var launchIconOpacity: CGFloat = 0

    private var launchScreen: some View {
        ZStack {
            PSColors.green50.ignoresSafeArea()

            VStack(spacing: PSSpacing.lg) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: PSLayout.scaledFont(56)))
                    .foregroundStyle(PSColors.primaryGreen)
                    .scaleEffect(launchIconScale)
                    .opacity(launchIconOpacity)

                Text("Freshli")
                    .font(.system(size: PSLayout.scaledFont(28), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(PSColors.textPrimary)
                    .opacity(launchIconOpacity)

                ProgressView()
                    .tint(PSColors.primaryGreen)
                    .padding(.top, PSSpacing.sm)
                    .opacity(launchIconOpacity)
            }
        }
        .onAppear {
            withAnimation(PSMotion.springBouncy) {
                launchIconScale = 1.0
                launchIconOpacity = 1.0
            }
        }
    }
}
