# Freshli - App Store Reviewer Notes

## Demo Credentials

**Email:** reviewer@freshli.app
**Password:** FreshliReview2026!

> If you prefer, you may also tap **"Continue without account"** on the auth screen to explore the full app in guest mode. All features except cloud sync are available.

---

## App Overview

Freshli is a premium food waste prevention app built entirely with **Swift 6**, **SwiftData**, and **iOS 26 SDK**. It helps users track pantry items, discover recipes for expiring ingredients, and measure their environmental impact. The app uses a custom **Liquid Glass** design system with real-time Metal shaders that adapt to ambient lighting conditions.

---

## How to Trigger Key Innovation Moments

### 1. Liquid Glass Shader System (Metal 4)
- **Where:** Every button, card, and surface in the app
- **How:** Tap any button to see the liquid glass ripple refraction effect. The ripple density and specular highlight respond to your finger position.
- **Ambient Adaptation:** Change your device brightness (Control Center slider). At low brightness, surfaces emit a warm OLED glow. At high brightness, specular highlights sharpen.
- **Note:** These shaders gracefully degrade on older devices and respect the "Reduce Motion" and "Increase Contrast" system accessibility settings.

### 2. Predictive Pre-fetching (Apple Intelligence)
- **Where:** Tab bar navigation
- **How:** Navigate between tabs (Home, Pantry, Recipes, Community). The app predicts which tab you'll visit next based on usage patterns and silently pre-loads data snapshots. This achieves sub-300ms Time to Interactive on every tab switch.
- **Observe:** Switch tabs rapidly. Content appears instantly with no loading spinners because data is already warm.

### 3. Freshli Vision (Camera + AI)
- **Where:** Tap the camera icon on the Home screen, or navigate to the Vision tab
- **How:** Point the camera at any food item or ingredient. The app uses the Vision framework to identify the item, then overlays a holographic glass card with:
  - Nutritional data (calories, protein, carbs, fat, fiber)
  - Estimated shelf life
  - Sustainability score
  - "Add to Pantry" one-tap action
- **Requires:** Camera permission (the purpose string explains this clearly)

### 4. Ray-Traced Dynamic Shadows
- **Where:** All elevated UI elements (buttons, cards, tab bar)
- **How:** Shadows cast direction and softness respond to time of day and ambient light:
  - Morning: shadows cast to the right
  - Midday: shadows directly below
  - Afternoon: shadows cast to the left
  - Dark room: OLED self-luminous green glow replaces shadows

### 5. Motion Vocabulary (Accessibility Innovation)
- **Where:** System-wide, active when VoiceOver is enabled
- **How:** Enable VoiceOver in Settings. Every visual shader effect has an equivalent haptic + audio representation:
  - Glass ripple = density-mapped "thock" haptic + glass chime
  - Elevation changes = rising/falling haptic patterns + tonal shifts
  - Freshness levels = intensity-mapped haptic (expired feels dull, peak feels crisp)
  - Tab switches = directional sweep haptics + whoosh tone
  - Food scan detection = confirmation ping + swell haptic
- **This ensures:** Users who cannot see the screen experience the same premium design language through touch and sound.

### 6. Impact Dashboard & Weekly Wrap
- **Where:** Home tab > Impact section, or the weekly wrap notification
- **How:** Add a few pantry items, then mark them as "Consumed" (swipe or tap the item). The Impact Dashboard updates in real-time showing:
  - Food items rescued
  - Money saved
  - CO2 emissions avoided
  - Rescue streak
- **Weekly Wrap:** A Spotify Wrapped-style animated summary surfaces each Sunday with your week's impact metrics.

### 7. Community Food Sharing
- **Where:** Community tab
- **How:** Tap "Share" on any pantry item to list it for your neighbors. The community feed shows nearby food listings with fuzzy location privacy (never exact addresses).

---

## Technical Architecture Highlights

| Feature | Technology |
|---------|-----------|
| Data Layer | Swift 6 strict concurrency + SwiftData (local) + Supabase (cloud sync) |
| Shader Pipeline | Metal Shading Language via SwiftUI `ShaderLibrary` ([[ stitchable ]] MSL) |
| Performance | Adaptive shader quality (ultra/high/medium/low/minimal) based on thermal + frame budget |
| Device Fallback | Metal GPU Family 4+ check; older devices get static glass aesthetic |
| Accessibility | Full VoiceOver + Reduce Motion + Increase Contrast + Motion Vocabulary + Dynamic Type |
| Privacy | Zero analytics/tracking, Privacy Manifest declared, all permissions have clear purpose strings |
| State Restoration | Tab persistence across launches + Handoff via NSUserActivity |

---

## Permissions Used

| Permission | Purpose | Fallback if Denied |
|------------|---------|-------------------|
| Camera | Barcode scanning, receipt scanning, Freshli Vision food identification | Manual item entry; Vision tab shows permission explanation |
| Photo Library | Adding custom images to pantry items and community listings | Default food category icons used instead |
| Location (When In Use) | Showing nearby community food listings and setting pickup points | Community features work without location; listings shown without distance |
| Notifications | Expiry reminders before food goes to waste | App still tracks expiry dates; user must check manually |

---

## Privacy Compliance

- **NSPrivacyTracking:** `false` (no tracking whatsoever)
- **Third-party SDKs:** Supabase Swift (authentication + cloud sync only)
- **No ad networks, no analytics SDKs, no fingerprinting**
- **Privacy Manifest:** Declares UserDefaults (app state), FileTimestamp (file operations), DiskSpace (storage checks)
- **Data collected:** UserID, email, name (for auth), location (not linked, for community features only)

---

## Known Simulator Limitations

- Metal shaders render at reduced fidelity in the Simulator. For the full Liquid Glass experience, please test on a physical device (iPhone 15 Pro or later recommended).
- Ambient light adaptation uses `UIScreen.main.brightness` as a proxy. On Simulator, adjust the brightness slider in Control Center to see the effect.
- Camera features (Freshli Vision, barcode scanning) require a physical device with a camera.

---

## Build & Run

- **Xcode:** 26.0+
- **iOS Target:** 26.0
- **Swift:** 6.0
- **Dependencies:** Supabase Swift 2.43.1 (via SPM)

Thank you for reviewing Freshli. We built this app to prove that sustainability and premium design are not mutually exclusive.
