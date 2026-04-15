# Freshli -- Apple Design Award Submission (Innovation)

## Vision

Freshli prevents food waste by making pantry management feel effortless. The core design thesis: if an interface behaves like a physical material, users stop thinking about the interface and start thinking about their food. Every surface in Freshli is optically alive -- refracting, responding to gaze, shifting with ambient light -- so that hierarchy, depth, and interaction affordances are communicated through material physics rather than explicit UI chrome. The result is a food tracking app with the cognitive overhead of a glass jar on a kitchen shelf.

## Technical Architecture

Freshli is built entirely in Swift 6 with Strict Concurrency, targeting iOS 26. The rendering pipeline comprises 21+ stitchable Metal shaders authored in MSL 3.2, composed through SwiftUI's `ShaderLibrary` and applied via `.layerEffect`, `.colorEffect`, and `.distortionEffect` modifiers. The architecture follows Atomic Design principles with zero `AnyView` type erasure -- every view is statically typed through the full composition tree. All heavy card compositions use `.drawingGroup()` for GPU-resident rendering, maintaining locked 120 Hz ProMotion frame delivery.

## Key Innovations

### Metal 4 SDF Refraction as Cognitive Load Reduction

Freshli's visual language is built on signed-distance-field refraction, not decoration. Liquid Glass surfaces combine Fresnel rim brightening, animated caustics, directional specular response, and chromatic edge shift to produce surfaces that behave like physical glass under varying light conditions. Users intuit card depth, grouping, and interactivity from optical physics alone.

The `tabMeltDissolve` shader drives tab transitions using 2D value noise with vertical gravity bias -- content dissolves downward with a luminous green edge glow, creating an organic material transition rather than a slide or fade. The `specularSparkle` shader ingests live gyroscope data via `CMMotionManager` to produce ray-traced specular highlights that track device tilt in real time. These are not visual effects layered on top of UI; they are the UI.

### Gaze-Tracking and Thought-Responsive Interaction

ARKit TrueDepth face tracking extracts gaze direction at 15 Hz. `GazeBloomState` computes per-view proximity using exponential moving average smoothing to eliminate jitter. When dwell time exceeds 0.6 seconds, a `phaseAnimator` bloom cycle activates: the target card's Liquid Glass refraction power increases 25%, a `specularSparkle` overlay appears, and a confirming haptic fires -- the interface acknowledges the user's attention without requiring a touch.

`GazeAnticipationService` extends this further by routing behavioral context through the Foundation Models framework (on-device LLM) to predict the next likely focus target. Predicted elements receive up to 25% pre-bloom intensity, so when the user's gaze arrives, the response is instantaneous. `IntentPredictionService` applies the same principle to tab navigation -- predicted destinations glow before the user touches them, collapsing perceived latency to zero.

### Haptic Material Physics and Accessible Motion Vocabulary

Every shader effect has a corresponding Core Haptics pattern engineered to its material physics. Glass ripple density maps to transient sharpness. The melt dissolve pairs a decaying rumble with a crystallisation click at completion. Freshness indicators encode their percentage as haptic intensity, giving VoiceOver users a tactile sense of urgency without reading a number.

`MotionVocabularyService` translates visual shader states into structured haptic and audio descriptions for assistive technologies. A blooming card is announced not just as "highlighted" but with a paired transient haptic that conveys the physical quality of the interaction.

## Accessibility

Every shader respects `UIAccessibility.isReduceMotionEnabled`. When active, refractive surfaces degrade gracefully to high-contrast static mesh gradients that preserve hierarchy without animation. All text composited over Liquid Glass surfaces maintains WCAG 2.2 AA contrast (4.5:1 minimum) regardless of blur or transparency levels. `AmbientLightService` drives two rendering modes -- OLED-black with self-luminous glow and high-key with crisp specular -- ensuring legibility across all lighting environments.

## Performance

Time to Interactive is held under 300 ms. Metal shader PSOs compile asynchronously off the main thread; skeleton views rendered with the Liquid Glass material fill the gap. GPU color math uses `half` precision throughout. Argument Tables and Residency Sets minimize CPU submission overhead per frame. The target frame budget is 8.3 ms -- verified continuously via Metal Performance HUD instrumentation.

## Impact

Freshli demonstrates that advanced GPU rendering and on-device intelligence are not features reserved for games or creative tools. Applied to an everyday utility, they eliminate cognitive friction at every interaction point. The interface disappears. What remains is a person looking at their food, understanding exactly what needs to be used, and wasting less. That is the innovation.
