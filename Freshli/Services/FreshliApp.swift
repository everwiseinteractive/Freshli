import SwiftUI
import SwiftData

@main
struct FreshliApp: App {
    
    // MARK: - State Objects & Environment
    
    @State private var authManager = AuthManager()
    @State private var celebrationManager = CelebrationManager()
    @State private var syncService = SyncService()
    
    // MARK: - SwiftData Model Container
    
    var modelContainer: ModelContainer = {
        let schema = Schema([
            FreshliItem.self,
            SharedListing.self,
            UserProfile.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Seed initial user profile if needed
            let context = ModelContext(container)
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let existingProfiles = try? context.fetch(profileDescriptor)
            
            if existingProfiles?.isEmpty ?? true {
                let profile = UserProfile()
                context.insert(profile)
                try? context.save()
                PSLogger.app.info("Created initial user profile")
            }
            
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }()
    
    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(authManager)
                .environment(celebrationManager)
                .environment(syncService)
                .task {
                    // Initialize services on app launch
                    await initializeApp()
                }
                .onAppear {
                    // Configure app appearance
                    configureAppearance()
                }
        }
    }
    
    // MARK: - App Initialization
    
    @MainActor
    private func initializeApp() async {
        PSLogger.app.info("🚀 Freshli app launched")
        
        // 1. Request notification permissions
        _ = await NotificationService.shared.requestAuthorization()
        
        // 2. Restore auth session
        await authManager.restoreSession()
        
        // 3. Start network monitoring
        _ = NetworkMonitor.shared
        
        // 4. Listen for auth changes
        Task {
            await authManager.listenForAuthChanges()
        }
        
        PSLogger.app.info("✅ App initialization complete")
    }
    
    // MARK: - UI Configuration
    
    @MainActor
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(PSColors.surfaceCard)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(PSColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = UIColor(PSColors.surfaceCard)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        PSLogger.app.debug("UI appearance configured")
    }
}
