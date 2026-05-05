# Freshli — Apple Design Award Submission (Inclusivity & Innovation)

## Vision

Freshli prevents food waste by making pantry management feel effortless. The core design thesis: an interface that behaves like a physical material disappears, and what remains is the user looking at their food, understanding exactly what needs to be used, and wasting less. Every elevated surface in Freshli refracts, breathes with ambient light, and responds to attention — so hierarchy, depth, and interactive affordances are communicated through material physics rather than explicit chrome. The result is a food tracking app with the cognitive overhead of a glass jar on a kitchen shelf.

## Technical Architecture

Freshli is built entirely in Swift 6.2 with strict concurrency, MainActor default isolation, and the `MEMBER_IMPORT_VISIBILITY` upcoming feature on. It targets iOS 26.4, iPadOS 26.4, and visionOS 26.4 from a single SwiftUI codebase using the Observation framework — there is zero use of `ObservableObject`, `@Published`, `@StateObject`, or `@EnvironmentObject` anywhere in the app target. SwiftData provides local persistence (intentionally configured with `cloudKitDatabase: .none` to avoid the optionality conflict with our non-optional model attributes); Supabase provides the cloud sync layer, with an `OfflineSyncQueue` that buffers writes when `NetworkMonitor` reports the path is unsatisfied and replays them on reconnect.

The atomic-design source tree (Atoms · Molecules · Organisms · Pages, plus per-feature folders) keeps composition statically typed without `AnyView` erasure. The app ships with a Watch companion (`FreshliWatch`), a widgets extension (`FreshliWidgetsExtension`) that hosts both Home Screen and Lock Screen widgets, two Live Activities (claim + recipe timer), and Control Center widgets for one-tap quick scan.

## Key Innovations

### Liquid Glass — refraction as cognitive layer, not decoration

`LiquidGlass.metal` ships two stitchable Metal shaders (`liquidGlass` and `gazeBloom`) that operate on key elevated surfaces — the floating tab bar pill, the profile circle, the `liquidGlass(_:)` modifier on hero cards, and the gaze-bloom overlay used by the optional gaze-adaptive accessibility feature. Each is parameterised by a `MaterialDensity` token (`.low`, `.medium`, `.high`) that controls refraction index, blur radius, chromatic aberration, border opacity, and shadow depth. Lower-priority surfaces (shimmer cards, dashboard entrance animations, harvest overlays) intentionally use SwiftUI gradient compositions instead of Metal — the file `MetalEffects.swift` documents this trade-off explicitly. This split is the right engineering call: GPU shaders where they pay for themselves, and SwiftUI animations where they don't, all behind a single conceptual API.

### On-device Apple Intelligence — Rescue Chef

`AIRescueService.swift` wraps Apple's `FoundationModels` framework with a `@Generable` schema (`AIRescueResponse` containing exactly three `AIRescueMission` objects, each with a constrained `@Guide` description, used items, additional pantry staples, 4–7 cooking steps, and an impact note). The service falls back gracefully when `SystemLanguageModel.default.isAvailable` is false — older devices, unsupported regions, or Apple Intelligence disabled. The entire pipeline runs on-device: pantry contents never leave the user's phone. The same intent surface is exposed through Siri ("Hey Siri, rescue my pantry with Freshli") via the `RescueMyPantryIntent` App Intent, which performs the LLM call inside the headless extension process.

### Gaze-Adaptive UI — TrueDepth as opt-in accessibility

`GazeTrackingService` (in `Services/GazeTrackingService.swift`) uses an `ARKit` face-tracking session at 30 fps to extract `ARFaceAnchor.leftEyeTransform` and `rightEyeTransform`. Those transforms are averaged into a single normalised gaze point (x, y in 0–1, plus confidence) — and that is the only data the rest of the app sees. No face mesh, no blendshapes, no images, no depth maps, no identity features ever leave ARKit's protected process. The session auto-pauses on backgrounding to save battery. The feature is **off by default**, opt-in from Settings, and documented in the privacy policy section 2.6. When enabled, items near the user's gaze inflate by up to 4% via `GazeAdaptiveGlassService` and the `gazeBloom` Metal shader; the visual response never triggers a tap, navigation, purchase, or automated action.

### Motion Vocabulary — accessibility innovation

`MotionVocabularyService.swift` is, to our knowledge, unique in shipping iOS apps. It translates ten classes of visual material event (`glassRipple`, `elevationChange`, `oledGlow`, `specularFlash`, `tabSlide`, `freshnessEncounter`, `itemRescue`, `shadowShift`, `scanDetection`, `prefetchWarm`) into structured Core Haptics patterns and synthesised audio descriptions. A glass ripple at high density produces a heavy, viscous "thock" haptic and a low-pitched glass chime; the same ripple at low density produces a crisp, airy tap and a bright ping. A blooming card that catches the user's attention is announced not just as "highlighted" but with a paired transient haptic that conveys the physical quality of the interaction. The service auto-enables when VoiceOver is running and can be toggled manually. This gives users who cannot see the screen the same premium design language through touch and sound — preserving the app's identity across accessibility modes instead of stripping it.

### Predictive intent bloom

`IntentPredictionService` analyses tab-navigation history to predict the next tab. When confidence crosses a threshold the predicted tab's SF Symbol enters a `.symbolEffect(.breathe)` cycle and a soft green bloom appears behind it. When the user actually taps, the visual response feels instantaneous because the system was already gesturing toward that destination. The same pattern (`PrefetchCoordinator`) prewarms data snapshots for every tab during first render, holding TTI on tab switches under our internal target on the devices we tested.

## Performance

The launch path in `FreshliApp.swift` is a multi-gate state machine with a 3.5 s master safety timeout — well under Apple's ~5 s freeze heuristic — and parallel gates for minimum splash display (1.5 s), auth resolution (2 s), data prefetch, and tab readiness. Non-critical service startup (TipKit, NetworkMonitor, AmbientLightService) is fanned out off the launch path in fire-and-forget Tasks. ARKit gaze tracking starts only after the splash dissolves, never on the launch path. The launch implementation is documented inline; it has been hardened through four App Review submissions (builds 19, 20, 22, 24).

`RenderPerformanceService` and `DynamicShaderResolutionService` adapt shader quality and resolution scale based on thermal state and frame budget across five tiers (ultra · high · medium · low · minimal). `FreshliHapticEngine` enforces a 2 s `maxContinuousDuration` to prevent battery drain from runaway interactions and updates parameters at a 120 Hz cap matched to ProMotion. The bundled `MetricKit` subscriber records `MXMetaPayload`, `MXAppLaunchMetric`, and `MXAnimationMetric` so the team can validate frame budget claims with on-device telemetry across the user base — not just internal test devices.

## Accessibility

Freshli treats accessibility as a design pillar, not a checklist:

- **Dynamic Type** — `PSLayout.scaledFont(_:)` passes its width-adjusted base size through `UIFontMetrics.default.scaledValue(for:)`, with a layout-safety cap at ~1.6× (AX3 equivalent) for hand-tuned compositions and `scaledFontUncapped(_:)` for text-only screens (recipe steps, weekly wrap, legal). Apple text-style fonts (`Font.freshliBody`, `Font.freshliDisplayLarge`, etc.) participate fully; views can opt their boundary into `.dynamicTypeSize(...DynamicTypeSize.accessibility5)` for full AX5 expression where layout permits.
- **WCAG AA contrast** — verified at design-token level. `textPrimary` is AAA in both modes; `textSecondary` and `textTertiary` clear AA for normal-size text on canonical light/dark backgrounds. Color contrast targets are documented inline in `PSColors.swift`.
- **Reduce Motion** — every shader, every animated transition, every shimmer, every spring respects `accessibilityReduceMotion`. Refractive surfaces degrade to high-contrast static mesh gradients via `HighContrastMaterialSystem` (with per-theme palettes targeting WCAG AAA 7:1) when Reduce Transparency or Increase Contrast is enabled.
- **Differentiate Without Color** — every status badge pairs colour with text and an SF Symbol (e.g. expiring badge: amber + "2 days left" + `clock.badge.exclamationmark`).
- **Touch targets** — minimum 44 pt enforced via `psMinTouchTarget()` and validated at AX5 via the snapshot test suite.
- **Custom actions for VoiceOver** — every repeated row in Pantry, Recipes, Community, and Inventory exposes context-appropriate actions (consume, share, save, claim) so VoiceOver users don't need to swipe through hidden buttons.
- **Sign in with Apple** — implemented and fixed for iPadOS Stage Manager and Supabase exchange failures (App Review builds 22 and 24).
- **Account deletion** — `AuthManager.deleteAccount()` calls a Supabase RPC and signs out regardless of success.

## Privacy

Zero tracking SDKs. The `PrivacyInfo.xcprivacy` manifest declares `NSPrivacyTracking: false`, an empty `NSPrivacyTrackingDomains` array, and only the three privacy-accessing API categories the app actually uses (UserDefaults, FileTimestamp, DiskSpace) with the correct required-reason codes. The widgets extension ships its own privacy manifest. All four permission strings (camera, photo library, location, notifications) explain *what* and *why* in plain English; the camera string is explicit about the optional ARKit gaze feature being on-device and never stored.

## Impact

Freshli demonstrates that on-device intelligence and considered material design are not features reserved for games or creative tools. Applied to an everyday utility, they eliminate cognitive friction at every interaction point. The interface disappears. What remains is a person looking at their food, understanding exactly what needs to be used, and wasting less.

The Inclusivity work, in particular, is the contribution we are most proud of: an app that costs nothing extra to use with VoiceOver, Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast, Differentiate Without Color, or Voice Control — and that, with Motion Vocabulary, sounds and feels as designed even when you cannot see the screen at all.
