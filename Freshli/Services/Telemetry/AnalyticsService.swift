import Foundation
import Supabase
import os

// MARK: - Analytics Service
//
// Internal product instrumentation for the Freshli core-loop verbs.
// Writes to the `public.analytics_events` Supabase table (see
// migration `analytics_events`) with RLS policies that scope every
// row to the authenticated user or an anonymous session.
//
// Design principles:
//
//   • **Fire-and-forget.** Every track() call is async void and never
//     blocks the caller. Failures are logged but never raised.
//   • **Offline-tolerant.** If the insert fails (offline, no session,
//     network error), the error is swallowed silently. No queue for
//     now — analytics is best-effort, not contractually durable.
//   • **No PII in properties.** Events carry enums, counts, durations,
//     version strings — never raw food names, locations, or user
//     identifiers other than the already-authenticated `user_id`.
//   • **Enum-driven event names.** `AnalyticsEvent` is a closed enum so
//     typos at call sites become compile errors, and the central list
//     of events is the single source of truth.
//   • **@Observable @MainActor singleton** matching the rest of the
//     service layer.

// MARK: - Event Catalogue
//
// The canonical list of tracked events. Add a new case here before
// wiring a new track() call site — this enum IS the analytics spec.
// Raw values are the `event_name` column that shows up in warehouse
// queries; keep them snake_case and stable once shipped.

enum AnalyticsEvent: String, Sendable {
    // Onboarding funnel
    case onboardingStarted     = "onboarding_started"
    case onboardingSlideViewed = "onboarding_slide_viewed"
    case onboardingCompleted   = "onboarding_completed"

    // Core loop: Add → Track → Rescue → Celebrate → Share
    case itemAdded             = "item_added"
    case pantryViewed          = "pantry_viewed"
    case itemConsumed          = "item_consumed"
    case itemShared            = "item_shared"
    case itemDonated           = "item_donated"
    case itemDeleted           = "item_deleted"

    // Flagship iOS 26 features
    case rescueChefOpened      = "rescue_chef_opened"
    case aiRescueRequested     = "ai_rescue_requested"
    case aiRescueSucceeded     = "ai_rescue_succeeded"
    case aiRescueFailed        = "ai_rescue_failed"
    case weeklyWrapOpened      = "weekly_wrap_opened"
    case weeklyWrapShared      = "weekly_wrap_shared"

    // Community
    case listingCreated        = "listing_created"
    case listingClaimed        = "listing_claimed"
    case fridgeViewed          = "fridge_viewed"

    // Monetisation
    case paywallShown          = "paywall_shown"
    case paywallDismissed      = "paywall_dismissed"
    case subscriptionPurchased = "subscription_purchased"
    case subscriptionRestored  = "subscription_restored"
}

// MARK: - Service

@Observable @MainActor
final class AnalyticsService {

    static let shared = AnalyticsService()

    /// Anonymous session ID for pre-auth events. Regenerated on every
    /// cold launch. Used in the warehouse to stitch an anonymous
    /// session to a user_id after they sign in.
    let sessionId: String

    /// Master kill-switch. Set to `false` in unit tests or if the user
    /// ever opts out of analytics from Settings.
    var isEnabled: Bool = true

    private let logger = Logger(subsystem: "com.freshli.app", category: "Analytics")

    /// Current build's marketing version, embedded in every event so
    /// the warehouse can slice rollouts.
    private let appVersion: String = {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }()

    private init() {
        self.sessionId = UUID().uuidString
    }

    // MARK: - Public API

    /// Fire an analytics event. Never throws, never blocks. Properties
    /// should contain primitives (String, Int, Double, Bool) only —
    /// NEVER PII. Typical usage:
    ///
    ///     AnalyticsService.shared.track(.itemAdded, properties: [
    ///         "category": item.category.rawValue,
    ///         "from_source": "manual"
    ///     ])
    ///
    /// The call returns immediately; the insert runs on a detached
    /// task and any failure is logged but swallowed.
    nonisolated func track(
        _ event: AnalyticsEvent,
        properties: [String: AnyCodable] = [:]
    ) {
        Task.detached(priority: .background) { [event, properties] in
            await Self.shared.enqueue(event, properties: properties)
        }
    }

    /// Force-flush the buffer immediately. Called from
    /// `UIApplication.willResignActiveNotification` so we don't lose
    /// in-flight events when the app backgrounds.
    nonisolated func flushPending() {
        Task.detached(priority: .background) {
            await Self.shared.drain()
        }
    }

    // MARK: - Private — batching
    //
    // Previous implementation: every `track()` spawned a detached
    // Task that opened a Supabase HTTPS connection and INSERTed one
    // row. Pantry-tab onAppear alone fired ≥6 events; the resulting
    // burst of TLS handshakes was a measurable battery + cellular
    // cost. We now buffer up to `batchSize` events (or `batchInterval`
    // seconds, whichever comes first) and flush as a single bulk
    // insert. Buffer is drained on app-background so events aren't
    // lost mid-session.

    /// Maximum number of events to buffer before forcing a flush.
    private let batchSize: Int = 10
    /// Maximum time an event can sit in the buffer before being
    /// flushed, even if `batchSize` hasn't been reached.
    private let batchInterval: TimeInterval = 30

    private var pending: [AnalyticsEventDTO] = []
    private var flushTask: Task<Void, Never>?

    private func enqueue(_ event: AnalyticsEvent, properties: [String: AnyCodable]) async {
        guard isEnabled else { return }
        let userId: UUID? = try? await AppSupabase.client.auth.session.user.id
        let payload = AnalyticsEventDTO(
            userId: userId,
            sessionId: sessionId,
            eventName: event.rawValue,
            properties: properties,
            appVersion: appVersion,
            platform: "ios",
            createdAt: Date()
        )
        pending.append(payload)
        if pending.count >= batchSize {
            await drain()
        } else {
            scheduleDeferredFlushIfNeeded()
        }
    }

    private func scheduleDeferredFlushIfNeeded() {
        guard flushTask == nil else { return }
        let interval = batchInterval
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard let self else { return }
            await self.drain()
        }
    }

    private func drain() async {
        flushTask?.cancel()
        flushTask = nil
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll()

        do {
            try await AppSupabase.client
                .from("analytics_events")
                .insert(batch)
                .execute()
            logger.debug("analytics: flushed \(batch.count, privacy: .public) event(s)")
        } catch {
            // Best-effort. On failure, drop the batch — re-queueing
            // would risk infinite retry loops if the schema is bad.
            logger.debug("analytics flush failed (\(batch.count, privacy: .public) events): \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - DTO

private struct AnalyticsEventDTO: Encodable {
    let userId: UUID?
    let sessionId: String
    let eventName: String
    let properties: [String: AnyCodable]
    let appVersion: String
    let platform: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case sessionId  = "session_id"
        case eventName  = "event_name"
        case properties
        case appVersion = "app_version"
        case platform
        case createdAt  = "created_at"
    }
}

// MARK: - Convenience
//
// `AnyCodable` in this codebase is an enum with specific cases
// (`.bool`, `.int`, `.double`, `.string`, `.array`, `.object`, `.null`)
// rather than a type-erasing wrapper. The helpers below convert common
// Swift primitives into the right enum case so call sites can stay tidy:
//
//     AnalyticsService.shared.track(.itemAdded, properties: .props([
//         "category":   item.category.rawValue,
//         "quantity":   item.quantity,
//         "from_smart": true
//     ]))

extension [String: AnyCodable] {
    static func props(_ pairs: [String: Any]) -> [String: AnyCodable] {
        pairs.compactMapValues(AnyCodable.fromAny)
    }
}

extension AnyCodable {
    /// Best-effort converter from a Swift `Any` value to the closest
    /// `AnyCodable` case. Unknown types land as their String description
    /// so an event is never silently dropped, and `nil`/unsupported
    /// values become `.null`. Collections are recursively converted.
    static func fromAny(_ value: Any) -> AnyCodable {
        switch value {
        case let v as Bool:    return .bool(v)
        case let v as Int:     return .int(v)
        case let v as Int64:   return .int(Int(v))
        case let v as Double:  return .double(v)
        case let v as Float:   return .double(Double(v))
        case let v as String:  return .string(v)
        case let v as UUID:    return .string(v.uuidString)
        case let v as [Any]:
            return .array(v.map(AnyCodable.fromAny))
        case let v as [String: Any]:
            return .object(v.mapValues(AnyCodable.fromAny))
        default:
            return .string(String(describing: value))
        }
    }
}
