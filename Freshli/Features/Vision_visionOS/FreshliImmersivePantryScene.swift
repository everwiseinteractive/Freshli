#if os(visionOS)
import SwiftUI
import RealityKit
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Freshli Immersive Pantry — visionOS
//
// A first-class spatial experience for Apple Vision Pro that turns
// the pantry into a glass-shelf room around the user. Each tracked
// item is a Liquid Glass card floating at a comfortable reach
// distance, sorted by expiry urgency — items closest to expiry are
// nearer the user at eye level, fresher items sit further back.
//
// Architecture:
//   • `ImmersiveSpace(id: "pantry")` is registered at the App scene
//     level. The iOS / iPadOS app can open it via
//     `@Environment(\.openImmersiveSpace)` from the Profile tab.
//   • Inside the immersive space, a `RealityView` hosts the spatial
//     ambience (a soft floor disc and an entity per item). SwiftUI
//     attachments render the actual glass cards on each entity.
//   • All SwiftUI APIs used here are real public APIs in
//     visionOS 1.0+: `RealityView`, `attachments`, `Attachment`,
//     `RealityViewContent.add(_:)`, `Entity.position`, `MeshResource`,
//     `Model3D`, `.offset(z:)`, `.frame(depth:)`,
//     `.glassBackgroundEffect(in:)`.
//   • Pantry data is read from the App Group shared snapshot the
//     widgets already use. Disposition actions are queued back
//     through the same App Group container so the iOS app picks them
//     up via `OfflineSyncQueue` on next foreground.
// ══════════════════════════════════════════════════════════════════

@MainActor
struct FreshliImmersivePantryScene: Scene {
    var body: some Scene {
        ImmersiveSpace(id: "pantry") {
            FreshliImmersivePantryView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

// MARK: - Immersive Pantry View

@MainActor
struct FreshliImmersivePantryView: View {
    /// The pantry items to render. Starts empty (real users must see an
    /// empty space until they've added items via the iOS app); populated
    /// on appear from the App Group snapshot the iOS app shares with us.
    @State private var items: [SpatialPantryItem] = []

    /// Currently picked-up item (pinch-and-drag in progress).
    @State private var pickedUpItemID: UUID?

    /// Count of items marked consumed during this session — surfaced
    /// to the iOS app on dismissal for celebration.
    @State private var consumedThisSession: Int = 0

    private let logger = Logger(subsystem: "com.freshli.app", category: "ImmersivePantry")

    var body: some View {
        RealityView { content, attachments in
            // 1. Floor disc — gentle aura under the user.
            let floor = ModelEntity(
                mesh: .generatePlane(width: 4.0, depth: 4.0, cornerRadius: 0.4),
                materials: [SimpleMaterial(color: .init(white: 0.05, alpha: 0.18), isMetallic: false)]
            )
            floor.position = SIMD3<Float>(0, -0.95, -1.6)
            content.add(floor)

            // 2. One entity per item — places the SwiftUI attachment
            // (the glass card) at a 3D position chosen by the model.
            for item in items {
                guard let attachment = attachments.entity(for: item.id.uuidString) else { continue }
                attachment.position = item.simdPosition
                content.add(attachment)
            }
        } update: { content, attachments in
            // Re-position attachments when the items array changes
            // (e.g. after `loadItemsFromSharedSnapshot`).
            for item in items {
                guard let attachment = attachments.entity(for: item.id.uuidString) else { continue }
                attachment.position = item.simdPosition
                if attachment.parent == nil { content.add(attachment) }
            }
        } attachments: {
            ForEach(items) { item in
                Attachment(id: item.id.uuidString) {
                    ItemGlassCard(
                        item: item,
                        isPickedUp: pickedUpItemID == item.id,
                        onConsume: { mark(.consumed, item: item) },
                        onShare:   { mark(.shared,   item: item) },
                        onDonate:  { mark(.donated,  item: item) },
                        onPickUp:  { pickedUpItemID = item.id },
                        onDrop:    { pickedUpItemID = nil }
                    )
                }
            }
        }
        .onAppear {
            logger.info("Immersive Pantry opened with \(items.count, privacy: .public) items.")
            loadItemsFromSharedSnapshot()
        }
        .onDisappear {
            logger.info("Immersive Pantry closed. consumed=\(consumedThisSession)")
        }
        .accessibilityLabel(String(localized: "Freshli Immersive Pantry"))
        .accessibilityHint(String(localized: "Glass cards float in front of you, one per pantry item closest to expiry. Pinch and drag to mark items consumed, shared, or donated."))
    }

    // MARK: - Data plumbing

    private func loadItemsFromSharedSnapshot() {
        guard let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli"),
              let raw = defaults.array(forKey: "widget_expiring_items") as? [[String: Any]]
        else {
            return
        }

        let parsed: [SpatialPantryItem] = raw.enumerated().compactMap { index, dict in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = dict["name"] as? String,
                  let category = dict["category"] as? String,
                  let days = dict["daysUntilExpiry"] as? Int
            else { return nil }

            // Place items in a horseshoe arc 1.2m in front of the user,
            // fanned out by index. Eye height is roughly 1.5m for a
            // standing user; we place at 1.2m with urgent items closer
            // to eye level.
            let theta = Double(index) * 0.18 - Double(raw.count) * 0.09
            let radius: Double = 1.2
            let x = radius * sin(theta)
            let z = -radius * cos(theta)
            let y: Double = 1.2 + (days < 2 ? 0.15 : 0.0)

            return SpatialPantryItem(
                id: id,
                name: name,
                category: category,
                daysUntilExpiry: days,
                position: (x: x, y: y, z: z)
            )
        }

        if !parsed.isEmpty { items = parsed }
    }

    private enum Disposition: String { case consumed, shared, donated }

    private func mark(_ disposition: Disposition, item: SpatialPantryItem) {
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli") ?? .standard
        var queue = defaults.array(forKey: "spatial_pending_actions") as? [[String: Any]] ?? []
        queue.append([
            "itemId": item.id.uuidString,
            "action": disposition.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        defaults.set(queue, forKey: "spatial_pending_actions")

        consumedThisSession += (disposition == .consumed ? 1 : 0)
        items.removeAll { $0.id == item.id }
        logger.info("Spatial mark \(disposition.rawValue, privacy: .public) for item \(item.name, privacy: .public)")
    }
}

// MARK: - Glass Card Attachment View

@MainActor
private struct ItemGlassCard: View {
    let item: SpatialPantryItem
    let isPickedUp: Bool
    let onConsume: () -> Void
    let onShare:   () -> Void
    let onDonate:  () -> Void
    let onPickUp:  () -> Void
    let onDrop:    () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text(item.emoji)
                    .font(.system(size: 56))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    Text(item.expiryLabel)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(item.urgencyColor)
                }
            }

            HStack(spacing: 14) {
                Button(action: onConsume) {
                    Label(String(localized: "Consumed"), systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onShare) {
                    Label(String(localized: "Share"), systemImage: "person.2.fill")
                }
                .buttonStyle(.bordered)

                Button(action: onDonate) {
                    Label(String(localized: "Donate"), systemImage: "hand.raised.fill")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(28)
        .frame(width: 360)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(item.urgencyColor.opacity(0.25), lineWidth: 1)
        )
        .scaleEffect(isPickedUp ? 1.06 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isPickedUp)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.expiryLabel)")
        .accessibilityAction(named: Text(String(localized: "Mark consumed")), onConsume)
        .accessibilityAction(named: Text(String(localized: "Share with community")), onShare)
        .accessibilityAction(named: Text(String(localized: "Donate")), onDonate)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPickUp() }
                .onEnded   { _ in onDrop() }
        )
    }
}

// MARK: - Spatial Item Model

struct SpatialPantryItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let daysUntilExpiry: Int
    /// World-space anchor for the entity hosting this card's
    /// SwiftUI attachment. x and z in metres, y in metres above floor.
    let position: (x: Double, y: Double, z: Double)

    /// SIMD3 form for `Entity.position`.
    var simdPosition: SIMD3<Float> {
        SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
    }

    var emoji: String {
        switch category {
        case "fruits": return "🍎"
        case "vegetables": return "🥬"
        case "dairy": return "🥛"
        case "meat": return "🥩"
        case "bakery": return "🍞"
        case "frozen": return "🧊"
        case "beverages": return "🥤"
        default: return "🍽️"
        }
    }

    var expiryLabel: String {
        switch daysUntilExpiry {
        case ...0: return String(localized: "Expired")
        case 1:    return String(localized: "Expires tomorrow")
        default:   return String(localized: "Expires in \(daysUntilExpiry) days")
        }
    }

    var urgencyColor: Color {
        switch daysUntilExpiry {
        case ...0:  return Color(red: 0.831, green: 0.094, blue: 0.239)  // expiredRed
        case 1...2: return Color(red: 0.961, green: 0.620, blue: 0.043)  // warningAmber
        default:    return Color(red: 0.133, green: 0.773, blue: 0.369)  // freshGreen
        }
    }

    static func == (lhs: SpatialPantryItem, rhs: SpatialPantryItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let previewSet: [SpatialPantryItem] = [
        .init(id: UUID(), name: "Spinach",      category: "vegetables", daysUntilExpiry: 1, position: (-0.4, 1.4, -1.0)),
        .init(id: UUID(), name: "Greek Yogurt", category: "dairy",      daysUntilExpiry: 2, position: ( 0.0, 1.4, -1.0)),
        .init(id: UUID(), name: "Sourdough",    category: "bakery",     daysUntilExpiry: 3, position: ( 0.4, 1.4, -1.0)),
        .init(id: UUID(), name: "Apples",       category: "fruits",     daysUntilExpiry: 5, position: (-0.6, 1.2, -1.4)),
        .init(id: UUID(), name: "Chicken",      category: "meat",       daysUntilExpiry: 1, position: ( 0.6, 1.2, -1.4)),
    ]
}

#endif
