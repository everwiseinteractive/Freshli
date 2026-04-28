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
                // ── Master safety timeout (FIRST thing we schedule) ──
                //
                // Apple's freeze-detection heuristic for App Review reports
                // "app froze upon launch" when the app appears unresponsive
                // for roughly 5 seconds. Build 19 was rejected with this
                // exact message on iPhone 17 Pro Max / iOS 26.4, so we
                // pull the master ceiling well below that threshold.
                //
                // 3.5 s is comfortably under Apple's threshold AND above
                // the 1.5 s minimum display, the 2 s auth timeout, and the
                // 1 s notification timeout (max sequential = 3 s, still
                // under the master so the master only fires in pathological
                // hangs, e.g. Supabase keychain stuck on a fresh-provisioned
                // device with unpredictable network).
                //
                // CRITICAL: this Task is scheduled BEFORE any other awaited
                // work in the .task body, so even if the very first call
                // below is the one that hangs, this safety net is already
                // armed.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3.5))
                    guard showSplash else { return }
                    logger.warning("FreshliApp: master safety timeout reached — forcing splash exit")
                    // If auth state never resolved, force it to .unauthenticated
                    // so mainAppContent has something concrete to render once
                    // the splash dissolves (instead of the .loading Color.clear).
                    if authManager.authState == .loading {
                        logger.warning("FreshliApp: master timeout firing with authState=.loading — forcing .unauthenticated")
                        authManager.authState = .unauthenticated
                    }
                    splashMinimumTimeMet = true
                    authResolved = true
                    dataPrefetched = true
                    appContentReady = true
                    splashProgress = 1.0
                    shouldExitSplash = true
                }

                // ── Minimum display time (1.5 s) — runs in parallel ──
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    splashMinimumTimeMet = true
                    checkAllGates()
                }

                // ── Non-critical service startup (deferred off-main, fire-and-forget) ──
                //
                // TipKit configure does disk I/O, MetricKit registration touches
                // a system framework, NWPathMonitor.start schedules a queue,
                // brightness polling sets up a Timer. None of these are needed
                // for the splash to dissolve — defer them so a slow init in any
                // of these can't block the launch path.
                Task { @MainActor in
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
                }

                // Gaze tracking (ARKit face tracking) — started in the
                // .onChange(of: showSplash) handler below, never on the
                // launch path. ARSession.run can take 100–500ms and may
                // contend with TrueDepth in iPad Stage Manager.

                // ── Auth restore (2 s internal timeout) ──
                logger.info("FreshliApp: Restoring session...")
                splashProgress = 0.15

                await authManager.restoreSession(timeout: 2.0)

                logger.info("FreshliApp: Session restored, state = \(String(describing: authManager.authState))")
                authResolved = true
                splashProgress = 0.50
                checkAllGates()

                // ── Notifications (1 s internal timeout) ──
                // Permission prompt is fire-and-forget; if iOS hasn't
                // returned a decision in 1 second we proceed without it
                // and re-request later when actually scheduling alerts.
                let notificationService = NotificationService()
                notificationService.registerCategories()
                await notificationService.requestAuthorization(timeout: 1.0)

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
            // ── Onboarding → main-app transition ──
            // .onChange(of: shouldExit) on FreshliSplashView only fires when the
            // value *changes*; it does not fire for the initial value the view
            // receives on first appearance.  On a first install the user goes
            // through OnboardingView while the .task above runs in parallel —
            // all splash gates pass (shouldExitSplash = true) *before* the
            // ZStack with FreshliSplashView is ever inserted into the hierarchy.
            // When hasCompletedOnboarding flips true, FreshliSplashView sees
            // shouldExit = true from its very first render, so .onChange never
            // fires and the splash loops forever.
            //
            // Fix: the moment onboarding completes AND all gates have already
            // passed, skip the splash entirely by collapsing showSplash → false
            // immediately, before the ZStack even renders.
            .onChange(of: hasCompletedOnboarding) { _, completed in
                guard completed, shouldExitSplash else { return }
                logger.info("FreshliApp: onboarding completed after gates passed — skipping splash")
                withAnimation(.easeOut(duration: 0.15)) {
                    showSplash = false
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
