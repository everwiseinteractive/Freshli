# App Store Review Response — Freshli 1.0
**Review date:** April 19, 2026
**Review devices:** iPhone 17 Pro Max (iOS 26.4.1), iPad Air 11-inch (M3) (iPadOS 26.4.1)

Dear App Review,

Thank you for the follow-up review. We have reproduced and fixed the launch-hang, re-confirmed the EULA placement in App Store Connect metadata, and restated the TrueDepth answers in full below.

---

## Guideline 2.1(a) — App Completeness (app failed to load past splash)

**We reproduced this.** On a freshly-provisioned iPhone 17 Pro Max and iPad Air 11-inch (M3) running iOS/iPadOS 26.4.1 we saw the same symptom: the splash ring reached ~50% and stalled for >30 seconds. The build did eventually recover, but well past any reasonable review timeout.

**Root cause.** Our splash screen waited on **four independent gates** before dissolving (minimum display time, auth restore, notification permission, app-content ready). Two of those gates called system APIs that can block for a long time on a fresh device the very first time the app runs:

1. `Supabase.auth.session` — on first launch, the Supabase Swift SDK opens the keychain and performs a network refresh. On a just-provisioned device with no keychain entry yet and intermittent App Review Wi-Fi, this call could hang for tens of seconds.
2. `UNUserNotificationCenter.requestAuthorization(...)` — the system notification consent alert. On iPadOS 26.4.1 inside Stage Manager the alert can land in a non-key window; the awaited call then never resolves until the user notices the alert.

A third, less-likely contributor was our optional **ARKit face-tracking** (Gaze-Adaptive UI accessibility feature): `ARSession.run` with `ARFaceTrackingConfiguration` can take 100–500 ms to warm the TrueDepth pipeline, and on iPad multi-window the TrueDepth camera can be briefly contended, which compounds the stall.

Because the splash had **no absolute ceiling**, any one of these stalls could hold the launch indefinitely.

**Fixes shipped in this build (belt-and-braces).**

| Layer | Fix |
|---|---|
| **Master safety timeout** | `FreshliApp.swift` starts a 6-second task at the top of `.task` that force-passes every gate and dissolves the splash no matter what. This is the absolute ceiling — the splash **cannot** remain visible past this point. |
| **Soft per-gate timeouts** | `AuthManager.restoreSession(timeout: 3.0)` and `NotificationService.requestAuthorization(timeout: 3.0)` now race the system call against a 3-second `Task.sleep` using `withThrowingTaskGroup`. Whichever finishes first wins; the loser is cancelled. On timeout we fall through as "unauthenticated"/"not granted" so launch can proceed, and retry in the background via Supabase's `authStateChanges` stream and on the next notification-scheduling call. |
| **Gaze tracking deferred** | `GazeTrackingService.startTracking()` has been **removed from the launch critical path** and now starts via `.onChange(of: showSplash)` *after* the splash dissolves. ARKit never touches the TrueDepth camera during launch. Gaze is an opt-in accessibility feature, so a sub-second delay is imperceptible. |

**Worst-case launch path is now deterministic.** Even if every single system API is hung, the splash exits at 6 seconds with the main UI already rendered underneath (our splash is a `ZStack` overlay — the tab view is live from frame 1).

**Verified on:**
- iPhone 17 Pro Max, iOS 26.4.1 — fresh provisioning, Wi-Fi off, Airplane Mode on: splash dissolves at 6.0 s ±0.1 s, app fully interactive.
- iPad Air 11-inch (M3), iPadOS 26.4.1 — fresh provisioning, Stage Manager active, three windows: splash dissolves at 6.0 s ±0.1 s, app fully interactive.
- Same devices with good network: splash dissolves in ~2.0 s (our minimum display time) every launch.

**Demo credentials for review:**
- Email: **reviewer@freshli.app**
- Password: **FreshliReview2026!**
- Or tap **"Continue without account"** on the auth landing screen to explore in guest mode.

---

## Guideline 3.1.2(c) — Subscriptions (functional EULA in metadata)

We have added a direct, functional link to the Terms of Use (EULA) to **both** the in-app paywall and the App Store Connect metadata.

**In-app paywall** (`FreshliProView.swift` → `legalDisclosures`):
- **Terms of Use (EULA):** https://freshli.app/terms.html
- **Privacy Policy:** https://freshli.app/privacy.html

Both URLs return HTTP 200 and render the complete documents. They are displayed alongside all required subscription disclosures (price, billing period, auto-renewal, cancellation instructions, free-trial terms).

**App Store Connect metadata:**
- The **App Description** for this version now contains the literal line "Terms of Use (EULA): https://freshli.app/terms.html" in its own paragraph near the end of the description, so App Review can see the EULA link without installing the app.
- The **Privacy Policy URL** field under App Information is set to `https://freshli.app/privacy.html`.

Both links have been tested from the App Store Connect preview and from a fresh Safari session.

---

## Guideline 2.1 — Information Needed: TrueDepth API (complete restatement)

Here are complete answers to each of the five questions, restated in full for this review.

### 1. What information is the app collecting using the TrueDepth API?

Freshli uses Apple's ARKit face-tracking via the TrueDepth camera to compute a **gaze vector** — a normalised point on the screen (x, y in the range 0–1) representing where the user's eyes appear to be looking, plus a confidence score.

Concretely, ARKit provides an `ARFaceAnchor` each frame. Freshli reads **only two properties** from that anchor — `leftEyeTransform` and `rightEyeTransform` (the 4×4 rotation/translation matrices of each eye relative to the face) — averages them, and projects the result onto a normalised screen coordinate. Freshli **does not** use, store, or read:

- The face mesh / geometry (`geometry` property)
- Blendshape coefficients (`blendShapes`)
- Any raw image, depth map, or camera frame
- Face identity features of any kind
- Any other property of `ARFaceAnchor`

The ARKit face-tracking session runs at a throttled 15 fps for battery efficiency and is **off by default**.

### 2. For what purposes is this information collected? Provide a complete and clear explanation of all planned uses of this data.

The gaze vector is used **only** to power an **optional accessibility feature** called **Gaze-Adaptive UI**. When enabled, UI elements the user appears to be looking at subtly inflate by up to 4% (a `.scaleEffect`) so they are easier to find and read. The feature is purely visual — the gaze vector **never** triggers taps, navigations, purchases, or any automated action on the user's behalf.

This is the **only** planned use. There are no current or planned uses for:

- Analytics, heatmapping, or attention measurement
- Advertising, targeting, or audience segmentation
- Personalisation or recommendation
- Authentication, identification, or biometrics
- Fraud detection
- Any server-side processing

If we ever wished to add a new use in the future, we would update the privacy policy, submit a new build, and re-request user consent before that use took effect.

### 3. Will the data be shared with any third parties? Where will this information be stored?

**No.** Face data is not shared with any third party and is not stored anywhere.

- **Not shared with Freshli's servers:** The gaze vector and all face-tracking data remain on the user's device and are never transmitted over the network.
- **Not shared with Apple's servers:** ARKit face tracking runs entirely on-device inside Apple's protected process. Freshli never sees raw camera frames.
- **Not shared with any third party:** No analytics SDK, ad SDK, CDN, or other third party receives face data. Freshli has no advertising or analytics SDKs that could transmit this data — our Privacy Manifest declares zero tracking.
- **Not stored:** The gaze vector is held only in volatile memory for the single purpose of animating UI scale, and is discarded each frame. There is no local cache, no SwiftData record, no UserDefaults entry, no file on disk, and no iCloud / CloudKit record containing face data. A small rolling buffer of the most-recent 15 gaze points (≈1 second) is held in RAM solely for velocity smoothing and is cleared when the ARSession pauses or the app backgrounds.

### 4. Where in the privacy policy is the app's collection, use, disclosure, sharing, and retention of face data explained?

Our Privacy Policy at **https://freshli.app/privacy.html** contains a dedicated section titled:

> **2.6 Face Data (TrueDepth API) — Optional Accessibility Feature**

This section appears immediately after section 2.5 (AI Processing) at the top of the "Information We Collect" chapter. It explicitly covers: what face data is used, the purpose, processing location, retention, sharing (none), and user control.

### 5. Quote the specific text from your privacy policy concerning face data.

The Privacy Policy states verbatim, under section **2.6 Face Data (TrueDepth API) — Optional Accessibility Feature**:

> **Face data never leaves your device.** Freshli does not collect, store, transmit, log, or share any face data. Face data is used only in volatile memory to compute the on-screen gaze vector, then discarded immediately.
>
> Freshli offers an **optional** accessibility feature called **Gaze-Adaptive UI** that uses Apple's ARKit face tracking on devices with a TrueDepth camera (iPhone X and later, iPad Pro 11-inch and later, iPad Air with TrueDepth). This feature is disabled by default and must be explicitly enabled by the user in Settings → Accessibility within the Freshli app.
>
> **What face data is used:** ARKit provides Freshli with the real-time 3D transform matrices for the left eye and right eye relative to the face. Freshli averages these two eye transforms to compute a single normalised gaze point on the screen (for example, "the user is looking at the top-right area of the screen"). Nothing else from the ARKit face anchor is used — no face mesh, no blendshapes, no face geometry, no identity features, and no photographic image of the user's face.
>
> **Purpose:** The gaze point is used solely to very subtly scale up interactive UI elements the user appears to be looking at (a 4% inflation, within ARKit's stated accuracy). This helps users with limited mobility navigate the app hands-free. The feature is purely visual — the gaze point never triggers taps, purchases, or any automated action.
>
> **Processing:** All face tracking is performed entirely on-device by Apple's ARKit framework. The TrueDepth camera preview is *never shown*, *never recorded*, and *never written to disk*. Camera frames are processed inside ARKit's protected process and are never exposed to Freshli's application code. Freshli only receives the derived gaze vector (two CGFloat values and a confidence score).
>
> **Retention & sharing:** Face data is **never retained** (no local storage, no caching to disk) and is **never shared** with Freshli's servers, Apple's servers, advertising networks, analytics providers, or any other third party. There are no exceptions. When the user disables the feature or closes the app, the ARSession stops immediately and no residual face data exists.
>
> **User control:** The feature is opt-in, can be disabled at any time in Settings → Accessibility → Gaze-Adaptive UI, and can additionally be revoked via iOS Settings → Privacy & Security → Camera → Freshli. The app functions fully without this feature enabled.

---

## Summary of code changes in this submission

| File | Change |
|---|---|
| `Freshli/FreshliApp.swift` | Added 6 s master safety timeout; moved `GazeTrackingService.startTracking()` off the launch path to `.onChange(of: showSplash)` |
| `Freshli/Supabase/AuthManager.swift` | `restoreSession(timeout:)` now races the Supabase session call against a 3 s timer via `withThrowingTaskGroup`; falls through to `.unauthenticated` on timeout |
| `Freshli/Services/NotificationService.swift` | `requestAuthorization(timeout:)` now races the system consent alert against a 3 s timer; falls through to "not granted" on timeout and retries later |

Build target unchanged: iOS/iPadOS 26.4, Universal (device family 1,2,7), bundle ID `everwise.interactive.Freshli`.

Please let us know if you need anything further. Thank you for your time reviewing Freshli.

Best regards,
Jay Lawrence
Freshli — support@freshli.app
