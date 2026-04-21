import SwiftUI
import SwiftData
import WidgetKit
import TipKit
import os

@main
struct FreshliApp: App {
    // Built once with cloudKitDatabase: .none — prevents SwiftData from auto-enabling
    // CloudKit sync, which requires all model attributes to be optional/have defaults
    // and injects remote-notification background mode requirements.
    // Supabase (SyncService) is the sync layer; SwiftData is local-only storage.
    private static let modelContainer: ModelContainer = {
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            return try ModelContainer(
                for: FreshliItem.self, SharedListing.self, UserProfile.self,
                configurations: config
            )
        } catch {
            Logger(subsystem: "com.freshli.app", category: "AppLifecycle")
                .error("SwiftData ModelContainer failed, falling back to in-memory: \(error.localizedDescription, privacy: .public)")
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(
                    for: FreshliItem.self, SharedListing.self, UserProfile.self,
                    configurations: memoryConfig
                )
            } catch {
                fatalError("SwiftData ModelContainer unrecoverable: \(error)")
            }
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
    @State private var renderPerformance = RenderPerformanceService.shared
    @State private var shaderResolution = DynamicShaderResolutionService.shared
    @State private var dataStore = FreshliDataStore.shared
    @State private var prefetchCoordinator = PrefetchCoordinator.shared
    @State private var ambientLight = AmbientLightService.shared

    // MARK: - Splash State Machine

    /// True while the splash overlay is visible.
    @State private var showSplash = true

    /// Drives the splash progress ring (0…1).
    @State private var splashProgress: CGFloat = 0

    /// Set to true when the splash should begin its exit dissolve.
    @State private var shouldExitSplash = false

    // Gate flags — all must be true before the splash exits.
    @State private var splashMinimumTimeMet = false
    @State private var authResolved = false
    @State private var dataPrefetched = false
    @State private var appContentReady = false

    private let logger = Logger(subsystem: "com.freshli.app", category: "AppLifecycle")

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    // ── Step 1: Onboarding (first launch only) ──
                    OnboardingView {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        withAnimation(FLMotion.springDefault) {
                            hasCompletedOnboarding = true
                        }
                    }
                } else {
                    // ── Step 2+3: Splash OVER main content ──
                    // The main app renders from the very first frame so it can
                    // warm up tabs, configure data stores, and reach an interactive
                    // state while the splash is still visible. When all loading
                    // gates pass, the splash dissolves to reveal what is already
                    // rendered underneath — zero view swaps, zero jarring cuts.
                    ZStack {
                        // Bottom layer: main app (loads immediately)
                        mainAppContent
                            .background(PSColors.backgroundPrimary.ignoresSafeArea())

                        // Top layer: splash (dissolves when ready)
                        if showSplash {
                            FreshliSplashView(
                                progress: splashProgress,
                                shouldExit: shouldExitSplash,
                                onExitComplete: {
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        showSplash = false
                                    }
                                }
                            )
                            .zIndex(100)
                            .allowsHitTesting(true)
                        }
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
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
            .environment(\.shaderQuality, renderPerformance.currentTier)
            .environment(\.shaderResolution, shaderResolution.scaleFactor)
            .environment(\.ambientBrightness, ambientLight.ambientBrightness)
            .environment(\.ambientGlowMode, ambientLight.glowMode)
            .environment(\.lightDirection, ambientLight.lightDirection)
            .overlay(alignment: .topLeading) {
                if renderPerformance.showPerformanceHUD {
                    MetalPerformanceHUD(service: renderPerformance)
                        .padding(.top, 60)
                        .padding(.leading, 8)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : nil)
            .onContinueUserActivity("com.freshli.viewItem") { activity in
                if let itemIdString = activity.userInfo?["itemId"] as? String {
                    logger.info("Handoff: Restoring item \(itemIdString, privacy: .public)")
                    UserDefaults.standard.set(itemIdString, forKey: "handoffItemId")
                    UserDefaults.standard.set("pantry", forKey: "lastSelectedTab")
                }
            }
            .task {
                // ── Services that start during splash ──
                do {
                    try Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                } catch {
                    logger.error("TipKit configure failed: \(error.localizedDescription, privacy: .public)")
                }

                diagnosticsService.start()
                networkMonitor.start()
                ambientLight.startMonitoring()

                // Gaze tracking (ARKit face tracking) is an accessibility extra —
                // it MUST NOT run on the launch/splash critical path because
                // ARSession.run can take 100–500ms to initialize and, if the
                // TrueDepth camera is contended (Stage Manager on iPadOS),
                // can stall long enough for App Review to report a hang.
                // We start it after the splash dissolves via `.task(id:)` below.

                ShaderWarmUpService.warmUpAll()

                // ── Master safety timeout ──
                // Guarantees the splash never hangs past this deadline, no matter
                // what happens to any individual gate. App Review's device is
                // fresh-provisioned with unpredictable network/keychain latency;
                // a hard ceiling is the only way to ensure "failed to load past
                // the splash screen" cannot happen. 6 seconds is well above the
                // soft per-gate timeouts (3s) and the 2s minimum display, so
                // under normal conditions this never fires.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(6.0))
                    guard showSplash else { return }
                    logger.warning("FreshliApp: master safety timeout reached — forcing splash exit")
                    splashMinimumTimeMet = true
                    authResolved = true
                    dataPrefetched = true
                    appContentReady = true
                    splashProgress = 1.0
                    shouldExitSplash = true
                }

                // ── Minimum display time (2.0 s) — runs in parallel ──
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.0))
                    splashMinimumTimeMet = true
                    checkAllGates()
                }

                // ── Auth restore (3s internal timeout — see AuthManager.restoreSession) ──
                logger.info("FreshliApp: Restoring session...")
                splashProgress = 0.15

                await authManager.restoreSession()

                logger.info("FreshliApp: Session restored, state = \(String(describing: authManager.authState))")
                authResolved = true
                splashProgress = 0.50
                checkAllGates()

                // ── Notifications (3s internal timeout — see requestAuthorization) ──
                let notificationService = NotificationService()
                notificationService.registerCategories()
                await notificationService.requestAuthorization()

                dataPrefetched = true
                splashProgress = 0.75
                checkAllGates()
            }
            .task(id: authManager.authState) {
                if authManager.authState == .authenticated {
                    await authManager.listenForAuthChanges()
                }

                // Auth state change can resolve a pending gate
                if authManager.authState != .loading && showSplash {
                    authResolved = true
                    checkAllGates()
                }
            }
            .onChange(of: networkMonitor.isConnected) { oldValue, newValue in
                if !oldValue && newValue {
                    Task {
                        await offlineSyncQueue.processQueue(using: syncService)
                    }
                }
            }
            .onChange(of: showSplash) { _, splashVisible in
                // Start ARKit gaze tracking AFTER the splash dissolves. Doing
                // this on the splash/launch path can stall first render on
                // some devices (see FreshliApp.task comment). Gaze is an
                // opt-in accessibility feature — delaying its start by a
                // second is imperceptible.
                if !splashVisible, GazeTrackingService.shared.isEnabled {
                    GazeTrackingService.shared.startTracking()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                // Pause ARKit gaze tracking to save battery when backgrounded
                GazeTrackingService.shared.pause()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                GazeTrackingService.shared.resume()
            }
        }
        .modelContainer(Self.modelContainer)
    }

    // MARK: - Main App Content

    @ViewBuilder
    private var mainAppContent: some View {
        switch authManager.authState {
        case .loading:
            // Brief fallback while auth resolves — hidden behind splash anyway
            Color.clear
        case .unauthenticated:
            if authManager.hasDeclinedAuth {
                AppTabView(onReady: handleAppReady)
            } else {
                AuthView()
                    .onAppear { handleAppReady() }
            }
        case .authenticated:
            AppTabView(onReady: handleAppReady)
        }
    }

    // MARK: - Gate Logic

    /// Called by AppTabView (or AuthView) once essential warm-up completes.
    private func handleAppReady() {
        guard !appContentReady else { return }
        appContentReady = true
        splashProgress = 1.0
        checkAllGates()
    }

    /// Checks ALL four gates and triggers the splash exit when they pass.
    private func checkAllGates() {
        guard showSplash else { return }
        guard splashMinimumTimeMet else { return }
        guard authResolved else { return }
        guard dataPrefetched else { return }

        // AppTabView readiness gate — only required when showing AppTabView.
        // AuthView doesn't need tab warm-up so skip this gate for it.
        let needsTabReady = authManager.authState == .authenticated ||
            (authManager.authState == .unauthenticated && authManager.hasDeclinedAuth)

        if needsTabReady {
            guard appContentReady else { return }
        }

        logger.info("FreshliApp: All gates passed — triggering splash exit")
        shouldExitSplash = true
    }
}
