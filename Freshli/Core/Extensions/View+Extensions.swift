import SwiftUI

extension View {
    func screenPadding() -> some View {
        padding(.horizontal, PSSpacing.screenHorizontal)
    }

    func cardStyle() -> some View {
        background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            // Metal GPU caustic light — subtle glass refraction on every card
            .metalCardGlass(intensity: 0.3)
            .elevation(.z1)
            // Hover specular — follows pointer/pencil/touch proximity
            .hoverSpecular(intensity: 0.4, cornerRadius: PSSpacing.radiusLg)
    }

    func elevatedCardStyle() -> some View {
        background(PSColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            // Metal GPU caustic light — stronger for elevated cards
            .metalCardGlass(intensity: 0.5)
            .elevation(.z2)
            // Hover specular — follows pointer/pencil/touch proximity
            .hoverSpecular(intensity: 0.5, cornerRadius: PSSpacing.radiusLg)
    }

    // MARK: - Liquid Glass (iOS 26)

    /// Freshli's canonical Liquid Glass surface. iOS 26 signature visual.
    /// Use this instead of `.background(.ultraThinMaterial)` on cards, toolbars,
    /// floating controls, and overlay sheets. Falls through to `.glassEffect()`
    /// which lets the system produce a properly blurred, specular-highlighted
    /// background that adapts to the content behind it.
    ///
    /// - Parameter shape: The clip shape. Defaults to the design-system's large
    ///   rounded rectangle — pass `.capsule` for pill buttons, or a custom radius
    ///   rect for tighter controls.
    func freshliGlass(in shape: some Shape = RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)) -> some View {
        self.glassEffect(.regular, in: shape)
    }

    /// Interactive variant — the glass highlights and subtly deforms in response
    /// to touches. Use on tappable glass surfaces (floating action buttons,
    /// glass-chip filters, the tab bar).
    func freshliGlassInteractive(in shape: some Shape = Capsule()) -> some View {
        self.glassEffect(.regular.interactive(), in: shape)
    }

    /// Tinted glass — use sparingly for hero CTAs or branded accents. The glass
    /// still refracts content behind it, but carries a subtle colour cast.
    func freshliGlassTinted(_ color: Color, in shape: some Shape = RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)) -> some View {
        self.glassEffect(.regular.tint(color), in: shape)
    }

    /// Emerald surface card style (profile, add item screens)
    func emeraldCardStyle() -> some View {
        background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(PSColors.emeraldSurface, lineWidth: 1)
            )
            .elevation(.z1, color: PSColors.primaryGreen)
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func accessibilityAction(_ label: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: Text(label), action)
    }

    func reduceMotion() -> Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Subtle scale animation on tap for interactive cards
    func interactiveCard() -> some View {
        self.buttonStyle(PressableButtonStyle())
    }

    /// Gentle pulse animation for attention-grabbing elements
    func attentionPulse(_ active: Bool = true) -> some View {
        self.symbolEffect(.pulse, isActive: active)
    }

    /// Glass card style using Liquid Glass + Metal caustic overlay
    func glassCardStyle() -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .metalCardGlass(intensity: 0.6)
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .highContrastGlass(cornerRadius: PSSpacing.radiusLg)
            .elevation(.z1)
            .hoverSpecular(intensity: 0.5, cornerRadius: PSSpacing.radiusLg)
    }

    /// Subtle glass background for floating elements
    func glassBackground() -> some View {
        self
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }

    // MARK: - Accessibility Modifiers

    /// Applies standard accessibility label and hint
    func psAccessible(label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }

    /// Makes a view a proper accessibility header
    func psAccessibleHeader(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isHeader)
    }

    /// Ensures minimum 44pt touch target
    func psMinTouchTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }

    // MARK: - VoiceOver Custom Actions for List Rows
    //
    // Repeated row content (Pantry items, Recipe cards, Community listings,
    // Inventory rows) is the most-traversed surface in the app. Without
    // custom actions, a VoiceOver user must swipe through every action
    // button on every row — exhausting on long lists.
    //
    // These helpers attach a structured set of `accessibilityCustomAction`
    // entries to the row's container element so the user can perform any
    // action with the rotor in two flicks: rotor → "Actions", flick down to
    // pick, double-tap to fire.
    //
    // The labels are localised at the call site via `String(localized:)`.

    /// Attaches a single VoiceOver custom action.
    func psCustomAction(_ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: Text(label), action)
    }

    /// Attaches the canonical pantry-row action set (consume, share, donate,
    /// edit, delete). Pass nil for any action that does not apply to this row
    /// — for example a community listing has no "consume" action.
    func psPantryRowActions(
        onConsume: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onDonate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        self
            .if(onConsume != nil) { v in v.accessibilityAction(named: Text(String(localized: "Mark consumed")), onConsume!) }
            .if(onShare != nil)   { v in v.accessibilityAction(named: Text(String(localized: "Share with community")), onShare!) }
            .if(onDonate != nil)  { v in v.accessibilityAction(named: Text(String(localized: "Donate")), onDonate!) }
            .if(onEdit != nil)    { v in v.accessibilityAction(named: Text(String(localized: "Edit")), onEdit!) }
            .if(onDelete != nil)  { v in v.accessibilityAction(named: Text(String(localized: "Delete")), onDelete!) }
    }

    /// Recipe-card actions: cook now, save, share, view details.
    func psRecipeRowActions(
        onCook: (() -> Void)? = nil,
        onSave: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil
    ) -> some View {
        self
            .if(onCook != nil)  { v in v.accessibilityAction(named: Text(String(localized: "Start cooking")), onCook!) }
            .if(onSave != nil)  { v in v.accessibilityAction(named: Text(String(localized: "Save recipe")), onSave!) }
            .if(onShare != nil) { v in v.accessibilityAction(named: Text(String(localized: "Share recipe")), onShare!) }
    }

    /// Community-listing actions: claim, message, save, report.
    func psListingRowActions(
        onClaim: (() -> Void)? = nil,
        onMessage: (() -> Void)? = nil,
        onSave: (() -> Void)? = nil,
        onReport: (() -> Void)? = nil
    ) -> some View {
        self
            .if(onClaim != nil)   { v in v.accessibilityAction(named: Text(String(localized: "Claim listing")), onClaim!) }
            .if(onMessage != nil) { v in v.accessibilityAction(named: Text(String(localized: "Message neighbour")), onMessage!) }
            .if(onSave != nil)    { v in v.accessibilityAction(named: Text(String(localized: "Save listing")), onSave!) }
            .if(onReport != nil)  { v in v.accessibilityAction(named: Text(String(localized: "Report listing")), onReport!) }
    }
}
