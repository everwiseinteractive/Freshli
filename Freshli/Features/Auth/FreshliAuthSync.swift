import AuthenticationServices
import SwiftUI
import Supabase
import os

// MARK: - Freshli Auth & Sync Layer (Swift 6.3)
// Backend Integration Specialist implementation.
// Sign in with Apple via Supabase, guest-to-authenticated migration,
// Supabase Realtime cross-device sync, and premium offline-mode UI.

private let logger = Logger(subsystem: "com.freshli.app", category: "AuthSync")

// MARK: - 1. Supabase Auth — Sign in with Apple

/// Manages the full Sign-in-with-Apple → Supabase session flow,
/// enforcing Strict Concurrency (`Sendable` boundaries) during the handoff.
@Observable
final class FreshliAuthService: @unchecked Sendable {
    var isAuthenticating = false
    var authError: String?
    var currentSession: Session?

    private let coordinator = AppleSignInCoordinator()
    private let client = AppSupabase.client

    /// Kick off the Sign in with Apple sheet and exchange the identity token
    /// with Supabase Auth for a server-side session.
    @MainActor
    func signInWithApple() async {
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        do {
            // 1. Native Apple ID flow (nonce-protected)
            let appleResult = try await coordinator.signIn()
            logger.info("Apple Sign-In succeeded; exchanging token with Supabase…")

            // 2. Hand the identity token + nonce to Supabase
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: appleResult.identityToken,
                    nonce: appleResult.nonce
                )
            )

            currentSession = session
            logger.info("Supabase session active for user \(session.user.id)")

            // 3. Migrate any guest-mode data (see §2)
            await migrateGuestDataIfNeeded(userId: session.user.id)

        } catch {
            authError = error.localizedDescription
            logger.error("Sign-in failed: \(error)")
        }
    }

    /// Observe session changes and keep `currentSession` up to date.
    func observeAuthState() async {
        for await (event, session) in client.auth.authStateChanges {
            await MainActor.run {
                switch event {
                case .signedIn:
                    currentSession = session
                case .signedOut, .tokenRefreshed:
                    currentSession = session
                default:
                    break
                }
            }
        }
    }
}

// MARK: - 2. Guest → Authenticated Data Migration

extension FreshliAuthService {

    /// If the user started in Guest Mode, seamlessly migrate their local pantry
    /// items to Supabase under the newly authenticated user ID.
    func migrateGuestDataIfNeeded(userId: UUID) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "freshli_has_guest_data") else {
            logger.info("No guest data to migrate.")
            return
        }

        logger.info("Migrating guest data for user \(userId)…")

        do {
            // Read guest items from local storage (UserDefaults or SwiftData)
            let guestItems = loadGuestItems()
            guard !guestItems.isEmpty else {
                defaults.set(false, forKey: "freshli_has_guest_data")
                return
            }

            // Batch upsert to Supabase
            let dtos: [[String: AnyJSON]] = guestItems.map { item in
                [
                    "id": .string(item.id.uuidString),
                    "user_id": .string(userId.uuidString),
                    "name": .string(item.name),
                    "category": .string(item.category),
                    "quantity": .double(item.quantity),
                    "unit": .string(item.unit),
                    "expiry_date": .string(ISO8601DateFormatter().string(from: item.expiryDate)),
                    "is_consumed": .bool(item.isConsumed),
                    "is_shared": .bool(item.isShared),
                    "created_at": .string(ISO8601DateFormatter().string(from: item.dateAdded))
                ]
            }

            try await client
                .from("pantry_items")
                .upsert(dtos)
                .execute()

            // Clear the guest flag
            defaults.set(false, forKey: "freshli_has_guest_data")
            clearGuestItems()
            logger.info("Successfully migrated \(guestItems.count) guest items.")

        } catch {
            logger.error("Guest migration failed: \(error)")
            // Keep flag so we retry on next sign-in
        }
    }

    /// Load guest items from local UserDefaults-based storage.
    private func loadGuestItems() -> [SupabaseFreshliItem] {
        guard let data = UserDefaults.standard.data(forKey: "freshli_guest_items"),
              let items = try? JSONDecoder().decode([SupabaseFreshliItem].self, from: data) else {
            return []
        }
        return items
    }

    /// Remove guest items from local storage after successful migration.
    private func clearGuestItems() {
        UserDefaults.standard.removeObject(forKey: "freshli_guest_items")
    }
}

// MARK: - 3. Real-time Sync — Supabase Realtime

/// Observes Supabase Realtime changes on the `pantry_items` table so that
/// marking an item as "Consumed" on iPad instantly updates the iPhone UI.
@Observable
final class FreshliRealtimeSync {
    var realtimeConnected = false
    var lastRealtimeEvent: String?

    private let client = AppSupabase.client
    private var channel: RealtimeChannelV2?
    private let userId: UUID

    /// Callback invoked on the main actor when a remote change arrives.
    @ObservationIgnored
    var onItemChanged: ((RealtimeAction) async -> Void)?

    enum RealtimeAction: Sendable {
        case inserted(itemId: String, name: String)
        case updated(itemId: String, name: String)
        case deleted(itemId: String)
    }

    init(userId: UUID) {
        self.userId = userId
    }

    /// Subscribe to real-time changes for the current user's pantry.
    func subscribe() async {
        let channel = client.realtimeV2.channel("pantry-\(userId.uuidString.prefix(8))")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "pantry_items",
            filter: "user_id=eq.\(userId.uuidString)"
        )

        await channel.subscribe()
        self.channel = channel
        realtimeConnected = true
        logger.info("Realtime subscribed for user \(self.userId)")

        // Listen for changes
        for await change in changes {
            let action = Self.parseAction(change)
            if let action {
                lastRealtimeEvent = "\(action)"
                await onItemChanged?(action)
            }
        }
    }

    /// Unsubscribe and clean up the channel.
    func unsubscribe() async {
        if let channel {
            await channel.unsubscribe()
        }
        channel = nil
        realtimeConnected = false
        logger.info("Realtime unsubscribed")
    }

    // MARK: Helpers

    private static func parseAction(_ change: AnyAction) -> RealtimeAction? {
        switch change {
        case .insert(let action):
            let id = action.record["id"]?.stringValue ?? "unknown"
            let name = action.record["name"]?.stringValue ?? "Item"
            return .inserted(itemId: id, name: name)
        case .update(let action):
            let id = action.record["id"]?.stringValue ?? "unknown"
            let name = action.record["name"]?.stringValue ?? "Item"
            return .updated(itemId: id, name: name)
        case .delete(let action):
            let id = action.oldRecord["id"]?.stringValue ?? "unknown"
            return .deleted(itemId: id)
        default:
            return nil
        }
    }
}

// MARK: - 4. Offline Mode — Premium ContentUnavailableView

/// A polished offline-mode view using `ContentUnavailableView` that explains
/// the app is waiting for a connection while still allowing local pantry browsing.
struct FreshliOfflineView: View {
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("You're Offline", systemImage: "wifi.slash")
                .symbolRenderingMode(.hierarchical)
        } description: {
            Text("Freshli is waiting for a connection to sync your pantry. You can still browse and edit your local inventory below.")
                .font(.freshliSubheadline)
        } actions: {
            Button("Try Again") {
                PSHaptics.shared.lightTap()
                onRetry()
            }
            .buttonStyle(FreshliPrimaryButtonStyle())
            .controlSize(.regular)
            .frame(maxWidth: 200)
        }
        .background(offlineGradient)
    }

    private var offlineGradient: some View {
        LinearGradient(
            colors: [
                PSColors.backgroundPrimary,
                PSColors.backgroundSecondary.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// A compact offline banner that sits at the top of any view.
struct FreshliOfflineBanner: View {
    var body: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Offline — changes will sync when you reconnect")
                .font(.freshliCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Previews

#Preview("Offline View") {
    FreshliOfflineView(onRetry: {})
}

#Preview("Offline Banner") {
    VStack {
        FreshliOfflineBanner()
        Spacer()
    }
}
