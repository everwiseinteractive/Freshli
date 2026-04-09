# Freshli Design System Quick Reference

## Naming Convention

**App Name**: Freshli  
**Prefix**: FL (for all design system components)  
**Bundle ID Pattern**: `com.yourcompany.Freshli`

---

## Design System Components

### Colors - `FLColors`
```swift
// Usage
.foregroundStyle(FLColors.primaryGreen)
.background(FLColors.surfaceCard)

// Brand Colors
FLColors.primaryGreen       // Main brand color
FLColors.primaryGreenDark   // Darker variant
FLColors.secondaryAmber     // Secondary accent
FLColors.accentTeal         // Tertiary accent

// Semantic Colors
FLColors.freshGreen         // Fresh items
FLColors.warningAmber       // Expiring soon
FLColors.expiredRed         // Expired items
FLColors.infoBlue           // Info messages

// Surfaces
FLColors.backgroundPrimary
FLColors.backgroundSecondary
FLColors.backgroundTertiary
FLColors.surfaceCard
FLColors.surfaceElevated

// Text
FLColors.textPrimary
FLColors.textSecondary
FLColors.textTertiary

// Borders
FLColors.border
FLColors.borderLight
FLColors.divider

// Category & Expiry
FLColors.categoryColor(for: category)
FLColors.expiryColor(for: status)
FLColors.expiryBackground(for: status)
```

### Motion - `FLMotion`
```swift
// Usage
withAnimation(FLMotion.springDefault) { ... }

// Spring Animations
FLMotion.springQuick        // Fast: 0.28s
FLMotion.springDefault      // Medium: 0.36s
FLMotion.springGentle       // Slow: 0.44s
FLMotion.springBouncy       // Bouncy feel
FLMotion.springSnappy       // Snappy feel

// Eased Animations
FLMotion.easeDefault        // 0.25s
FLMotion.easeSlow           // 0.4s
FLMotion.easeQuick          // 0.15s

// Transitions
FLMotion.slideUp
FLMotion.scaleIn
FLMotion.fadeSlide

// Helpers
FLMotion.staggerDelay(index: 0, base: 0.05)
FLMotion.flAdaptive(animation, reduceMotion: bool)

// View Modifiers
.screenTransition()
.staggeredAppearance(index: 0)
.pressable()
.bouncy()
.refreshBounce(isRefreshing: $isRefreshing)
```

### Spacing - `FLSpacing`
```swift
// Usage
.padding(FLSpacing.md)
.padding(.horizontal, FLSpacing.screenHorizontal)

// Spacing Values
FLSpacing.xs                // Extra small
FLSpacing.sm                // Small
FLSpacing.md                // Medium
FLSpacing.lg                // Large
FLSpacing.xl                // Extra large
FLSpacing.xxl               // 2X large

// Corner Radius
FLSpacing.radiusSm
FLSpacing.radiusMd
FLSpacing.radiusLg
FLSpacing.radiusXl

// Screen Margins
FLSpacing.screenHorizontal  // Standard horizontal padding
FLSpacing.screenVertical    // Standard vertical padding
```

### Layout - `FLLayout`
```swift
// Usage
.font(.system(size: FLLayout.scaledFont(16)))
.frame(height: FLLayout.scaled(44))

// Methods
FLLayout.scaledFont(_ size: CGFloat)       // Accessibility-scaled font
FLLayout.scaled(_ value: CGFloat)          // Accessibility-scaled dimension
FLLayout.safeAreaInsets                    // Current safe area
FLLayout.screenWidth
FLLayout.screenHeight
```

### Haptics - `FLHaptics`
```swift
// Usage
FLHaptics.shared.lightTap()

// Methods
FLHaptics.shared.lightTap()         // Light impact
FLHaptics.shared.mediumTap()        // Medium impact
FLHaptics.shared.heavyTap()         // Heavy impact
FLHaptics.shared.success()          // Success feedback
FLHaptics.shared.warning()          // Warning feedback
FLHaptics.shared.error()            // Error feedback
FLHaptics.shared.selectionChanged() // Selection changed
```

### Toast - `FLToastManager`
```swift
// Setup in app
@State private var toastManager = FLToastManager()

// In environment
.environment(toastManager)
.toastOverlay(manager: toastManager)

// Usage in views
@Environment(FLToastManager.self) private var toastManager

// Show toasts
toastManager.show(.success("Saved!"))
toastManager.show(.error("Failed"))
toastManager.show(.warning("Check this"))
toastManager.show(.info("FYI"))
toastManager.show(.itemAdded("Banana"))
toastManager.show(.itemConsumed("Apple"))
toastManager.show(.itemShared("Bread"))
toastManager.show(.itemDonated("Rice"))
toastManager.show(.itemDeleted("Milk"))

// Dismiss
toastManager.dismiss()
```

### Button - `FLButton`
```swift
// Usage
FLButton(
    title: "Add Item",
    icon: "plus.circle.fill",
    style: .primary,
    isFullWidth: true,
    isLoading: false,
    action: { /* action */ }
)

// Styles
.primary                    // Green, primary action
.secondary                  // Outlined, secondary action
.destructive                // Red, destructive action
.ghost                      // Text only, minimal

// Properties
title: String               // Button text
icon: String?               // SF Symbol name (optional)
style: FLButtonStyle        // Button style
isFullWidth: Bool           // Full width or compact
isLoading: Bool             // Show loading spinner
action: () -> Void          // Action handler
```

### Shimmer View - `FLShimmerView`
```swift
// Usage
FLShimmerView(
    height: 120,
    cornerRadius: FLSpacing.radiusMd
)

// Properties
height: CGFloat             // View height
cornerRadius: CGFloat       // Corner radius
```

---

## Common Patterns

### Standard Card
```swift
VStack {
    // Content
}
.padding(FLSpacing.md)
.background(FLColors.surfaceCard)
.clipShape(RoundedRectangle(
    cornerRadius: FLSpacing.radiusLg,
    style: .continuous
))
.shadow(color: .black.opacity(0.05), radius: 8, y: 2)
```

### Primary Button
```swift
FLButton(
    title: "Continue",
    icon: "arrow.right",
    style: .primary,
    isFullWidth: true,
    action: { /* action */ }
)
.padding(.horizontal, FLSpacing.screenHorizontal)
```

### Animated List Item
```swift
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ItemRow(item: item)
        .staggeredAppearance(index: index)
}
```

### Success Toast
```swift
do {
    try saveItem()
    toastManager.show(.success("Item saved!"))
} catch {
    toastManager.show(.error("Failed to save"))
}
```

### Loading State
```swift
if isLoading {
    FLShimmerView(
        height: 100,
        cornerRadius: FLSpacing.radiusMd
    )
} else {
    ContentView()
}
```

---

## Migration from PS to FL

| Old (PantryShare) | New (Freshli) |
|-------------------|---------------|
| `PSColors` | `FLColors` |
| `PSMotion` | `FLMotion` |
| `PSSpacing` | `FLSpacing` |
| `PSLayout` | `FLLayout` |
| `PSHaptics` | `FLHaptics` |
| `PSToastManager` | `FLToastManager` |
| `PSToastType` | `FLToastType` |
| `PSButton` | `FLButton` |
| `PSShimmerView` | `FLShimmerView` |

---

## Environment Setup

### In App File (FreshliApp.swift)
```swift
@State private var toastManager = FLToastManager()

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(toastManager)
            .toastOverlay(manager: toastManager)
    }
}
```

### In Views
```swift
struct MyView: View {
    @Environment(FLToastManager.self) private var toastManager
    
    var body: some View {
        // Use design system
    }
}
```

---

## Tips

1. **Always use FL prefix** for design system components
2. **Use semantic colors** (e.g., `textPrimary`) instead of raw colors
3. **Use spacing constants** instead of hardcoded values
4. **Leverage motion system** for consistent animations
5. **Show toast feedback** for user actions
6. **Add haptics** for important interactions
7. **Use staggered animations** for lists
8. **Scale fonts and layouts** for accessibility

---

## Related Files

- `FLColors.swift` - Color system
- `FLMotion.swift` - Animation & transitions
- `FLToast.swift` - Toast notifications
- `FLSpacing.swift` - Spacing & layout constants
- `FLLayout.swift` - Layout utilities
- `FLHaptics.swift` - Haptic feedback
- `FLButton.swift` - Button component
- `FLShimmerView.swift` - Loading shimmer effect
