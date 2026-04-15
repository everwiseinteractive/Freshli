# Freshli — App Store Screenshot Briefs
# iPhone 15 Pro Max · 1290 × 2796 px · Portrait
# Format per slide: DEVICE CONTENT / HEADLINE / SUBHEADLINE / NOTES

---

## Screenshot 1 — HERO: "Liquid Glass Dashboard"
**Filename:** `01-liquid-glass-dashboard.png`
**Slot:** Primary (first impression, search grid, product page hero)

### Device Content
The Freshli Home / Pantry Dashboard at rest. The full-bleed background is the
Metal 4 SDF refraction shader — ambient kitchen light refracts through layered
glass planes, bending the gradient beneath into soft caustic arcs of deep forest
green (#0D2B18) and warm cream (#FFF8EE). No static background: the material
breathes with a 4-second idle cycle, subtly shifting specular highlights.

Foreground: a vertical stack of three Liquid Glass pantry cards (avocado,
greek yogurt, sourdough) float above the shader. Each card has frosted-glass
body (blur radius 28pt, 72% opacity), a luminous freshness badge (green glow for
safe, amber pulse for 2-day warning), and a real food photograph. Parallax depth
is implied — the top card casts a soft shadow on the one below.

Bottom: the Tab Bar, itself a Liquid Glass material — you can see the distorted
gradient of the screen *through* the bar.

### Headline Text (overlay, top third, white, SF Rounded Bold 52pt)
"Your kitchen,\nalive."

### Subheadline Text (overlay, below headline, 60% white, SF Pro Regular 28pt)
"Metal 4 Liquid Glass. Every surface refracts reality."

### Production Notes
- Capture during the specular peak of the idle animation (approx frame 48 of 96)
- Device frame: Natural Titanium iPhone 15 Pro Max, no notch crop
- Background behind device: deep #0A1F0E with 8% grain overlay
- Headline gradient: white → Freshli-Green (#00FF00 at 40% opacity) left-to-right

---

## Screenshot 2 — FEATURE: "Gaze-Adaptive Recipes"
**Filename:** `02-gaze-adaptive-recipes.png`
**Slot:** Second (establishes AI / intelligence story)

### Device Content
FLRecipesPage. Three recipe cards fill the scroll view. The CENTER card —
"Rescue Pasta Primavera" — is in the active bloom state: the Liquid Glass
surface has increased refraction density by 25%, a specular hotspot (driven by
gyroscope, frozen at a 12° right tilt) tracks toward the top-right corner of
the card like a physical highlight, and the card scale is 1.035× relative to
its neighbors. A razor-thin luminous green rim (1pt, #00FF00, 60% opacity)
traces the card's rounded rectangle — the "bloom ring."

The two flanking cards are at rest (neutral refraction, no rim). This
contrast makes the center card feel almost magnetic.

Overlaid on the center card in small SF Pro Medium 14pt / Freshli-Green:
"● Gaze detected — blooming"

### Headline Text (overlay, top third, white, SF Rounded Bold 52pt)
"The app that\nsees your intent."

### Subheadline Text (overlay, below headline, 60% white, SF Pro Regular 28pt)
"Apple Intelligence predicts. Metal 4 responds. Before you tap."

### Production Notes
- Use a real device running Freshli; trigger bloom by holding gaze on card for 0.6s
  then screenshot via AssistiveTouch (avoids physical button motion blur)
- Gyroscope tilt: hold device 12° clockwise — specular hotspot hits upper-right quadrant
- Do NOT flatten or merge the specular layer — its separation from the card body
  must be visible as a distinct translucent lozenge
- Status bar: hide carrier, show 9:41 AM, full battery, no cellular dots

---

## Screenshot 3 — TRANSITION: "The Melt"
**Filename:** `03-melt-transition.png`
**Slot:** Third (the "wow" / differentiator shot)

### Device Content
A composite freeze-frame of the Tab Bar Melt transition, mid-dissolve at
progress ≈ 0.38. The LEFT half of the screen shows FLRecipesPage still intact.
The RIGHT half shows FLPantryPage beginning to materialise. Between them, the
dissolution edge runs as a ragged organic frontier — not a straight line, but
a noise-field boundary with:
  - Dissolved pixels fully transparent, revealing the #0A1F0E background beneath
  - A 6pt luminous green glow band (#24D266, 55% opacity) tracing the live edge
  - Micro-droplets of the departing view still visible just past the frontier

The Tab Bar at the bottom is fully rendered on both sides — showing the Recipes
tab icon fading and the Pantry tab icon crystallising (sharp transient click
moment, captured at the 420ms mark of the melt haptic pattern).

### Headline Text (overlay, bottom quarter, white, SF Rounded Bold 52pt)
"Navigation that\nmelts and reforms."

### Subheadline Text (overlay, below headline, 60% white, SF Pro Regular 28pt)
"Metal 4 noise-field dissolution. Tactile. Visceral. Instant."

### Production Notes
- Use Xcode Simulator slow-motion animation (5× slowdown via Debug > Slow Animations)
  to capture the exact 0.38 progress frame
- Export as PNG from the Metal Performance HUD frame capture in Xcode Instruments
- The composite split is a POST-PRODUCTION effect: shoot both screens separately at
  the same progress value, then composite with a hand-masked noise-field edge in
  Photoshop (mask should match the actual shader noise output — export the noise
  field from the shader at progress=0.38 as a reference mask)
- Overlay the green glow band as a Screen blend layer at 80% opacity
- This screenshot may require an "In-App Event" badge waiver — file with ASC team

---

## Screenshot 4 — VALUE: "Your Impact, Rendered"
**Filename:** `04-impact-dashboard.png`
**Slot:** Fourth (emotional / community / mission beat)

### Device Content
The Weekly Wrap / Impact screen. A full-bleed cinematic view dominated by a
large animated number: "£47 rescued this week" in SF Rounded Bold 72pt,
Freshli-Green, with a subtle Metal glow bloom behind the digits. Below: three
stat pills (Liquid Glass material, frosted) showing CO₂ avoided, meals shared,
karma credits. A world map in the lower half renders the Live Rescue Wave —
animated arcs of green light connecting cities where food rescues happened in
the last 24 hours, rendered with Metal particle instancing.

A user's avatar and "Seedling → Sprout" hero tier progression bar sits at the
top, the tier label in Freshli-Green.

### Headline Text (overlay, top quarter, white, SF Rounded Bold 52pt)
"Every item saved\nis a story."

### Subheadline Text (overlay, below headline, 60% white, SF Pro Regular 28pt)
"Track your real-world impact — money, carbon, community."

### Production Notes
- Populate with demo account: "jaytest@freshli.app" / seeded with 6 weeks of data
- Capture during the Live Rescue Wave peak animation (arcs fully extended)
- The £47 figure should glow — use a Gaussian blur (radius 24px) on a duplicate
  layer set to Screen blend at 60% to simulate the Metal bloom
- No device frame on this shot — use edge-to-edge with rounded corner mask only

---

## Screenshot 5 — ECOSYSTEM: "Freshli, Everywhere"
**Filename:** `05-ecosystem-multidevice.png`
**Slot:** Fifth (platform breadth / stickiness)

### Device Content
A three-device composite on a deep #0A1F0E background:

LEFT — Apple Watch Ultra 2 (prominent, angled 15° left):
  Freshli complication on the Modular face. Three expiry countdown rings,
  the innermost showing "Avocado · 1d" in Freshli-Green.

CENTER — iPhone 15 Pro Max (hero, straight on):
  Lock Screen with a Freshli Live Activity banner: a pasta timer "12:34 remaining"
  with a Liquid Glass pill and green progress arc.

RIGHT — iPad Pro M4 (angled 15° right):
  FLPantryPage on the larger canvas. The same Liquid Glass cards from Screenshot 1,
  but in a 2-column grid layout, with the sidebar navigation visible at left.

Connecting all three: a thin luminous green arc (4pt, gradient from #00FF00 to
transparent) sweeping device-to-device, implying data sync — Freshli's continuity.

### Headline Text (overlay, center top, white, SF Rounded Bold 52pt)
"iPhone. iPad.\nApple Watch."

### Subheadline Text (overlay, below headline, 60% white, SF Pro Regular 28pt)
"One rescue mission. Every screen in your life."

### Production Notes
- Devices must be real hardware renders — use Apple's official device frames
  from the Apple Design Resources kit (Sketch / Figma)
- Match the Liquid Glass shader colour temperature across all three screens
  (same Metal shader uniform values: density 0.72, refraction 0.18)
- The connecting arc is a vector overlay, not captured from the app
- Ensure Watch face, Lock Screen time, and iPad time all read 9:41 AM
