# App Store Review Response — Freshli 1.0
**Review date:** April 23, 2026
**Review devices:** iPhone 17 Pro Max (iOS 26.4.1), iPad Air 11-inch (M3) (iPadOS 26.4.1)
**Build:** 1.0 (19) — uploaded after this fix

Dear App Review,

Thank you for the continued review. We identified the underlying cause of the Sign in with Apple error on iPad and have moved to Apple's official SwiftUI `SignInWithAppleButton` component. The full TrueDepth answers from the previous submission are restated verbatim below so they appear in this build's review notes as well.

---

## Guideline 2.1(a) — App Completeness (Sign in with Apple error on iPad)

### Root cause

Our previous build drove the Sign in with Apple flow through a **custom `Button`** that invoked `ASAuthorizationController` directly via our own coordinator. While we added a presentation-context provider to handle iPad multi-window, the coordinator's presentation-anchor discovery is sensitive to the exact state of `UIApplication.connectedScenes` on iPadOS 26.4.1 — in particular, when Stage Manager is active, there can be a brief window in which no `UIWindowScene` is in `.foregroundActive` state. When that happens, our fallback returned a detached `ASPresentationAnchor()` (an empty `UIWindow` with no scene), and `ASAuthorizationController.performRequests()` then either failed with `not handled` or presented into an invalid window. Our error surface in `AuthManager.signInWithApple()` mapped that to a visible "Sign in with Apple couldn't open / failed" alert — which is the error message App Review saw.

We have been unable to reproduce this 100% of the time — it depends on scene activation timing on a freshly-provisioned iPad Air in Stage Manager — but we consistently reproduced *transient* failures on that device by backgrounding/foregrounding the app mid-launch. The official SwiftUI button does not hit this code path.

### Fix shipped in this build

We replaced the custom `Button` with Apple's **official `SignInWithAppleButton`** SwiftUI component in both auth entry points (`AuthView.swift` and `OnboardingSignInView.swift`).

`SignInWithAppleButton` is the HIG-required component for Sign in with Apple (§4.8). It:

- Owns its own `ASAuthorizationController` lifecycle
- Picks the correct `presentationAnchor` automatically, including on iPadOS multi-window, Split View, Slide Over, and Stage Manager
- Passes our nonce-bound request through `onRequest` so the cryptographic chain is preserved end-to-end
- Returns the credential (or `ASAuthorizationError.canceled`) through `onCompletion`, which we hand off to a new `AuthManager.signInWithApple(idToken:nonce:fullName:)` method that exchanges the token with Supabase

The legacy coordinator + `AuthManager.signInWithApple()` method remain for unit-test paths but are no longer reachable from the UI.

### Verified on

- iPad Air 11-inch (M3), iPadOS 26.4.1 — Stage Manager active with three simultaneous windows — Sign in with Apple sheet opens first time, every time
- iPad Air 11-inch (M3), iPadOS 26.4.1 — Split View + Slide Over — works
- iPhone 17 Pro Max, iOS 26.4.1 — works
- Reviewer account **reviewer@freshli.app** / **FreshliReview2026!** also still available for email sign-in, and **"Continue without account"** on the auth landing screen gives full access to the app in guest mode

### Demo credentials (re-confirmed)

- **Email:** reviewer@freshli.app
- **Password:** FreshliReview2026!

Or tap **"Continue without account"** on the auth landing to explore the full app in guest mode.

---

## Guideline 2.1 — Information Needed: TrueDepth API (complete restatement)

Restated here in full — these answers apply to build 1.0 (19) as submitted.

### 1. What information is the app collecting using the TrueDepth API?

Freshli uses Apple's ARKit face-tracking via the TrueDepth camera to compute a **gaze vector** — a normalised point on the screen (x, y in the range 0–1) representing where the user's eyes appear to be looking, plus a confidence score.

Concretely, ARKit provides an `ARFaceAnchor` on each frame. Freshli reads **only two properties** from that anchor — `leftEyeTransform` and `rightEyeTransform` (the 4×4 rotation/translation matrices of each eye relative to the face) — averages them, and projects the result onto a normalised screen coordinate. Freshli **does not** use, store, or read:

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
| `Freshli/Features/Auth/AuthView.swift` | Custom SIWA `Button` replaced with official `SignInWithAppleButton(.signIn)`; nonce managed via `@State`; completion handler invokes the new credential-taking auth path |
| `Freshli/Features/Onboarding/OnboardingSignInView.swift` | Same refactor — `SignInWithAppleButton(.signIn)` with in-view loading overlay |
| `Freshli/Supabase/AuthManager.swift` | New method `signInWithApple(idToken:nonce:fullName:)` that exchanges pre-obtained credentials with Supabase; legacy coordinator-driven method retained and refactored to delegate |

The complete previous launch-path fixes (splash master safety timeout, auth/notification timeout races, deferred gaze tracking) remain in place.

Please let us know if you need anything further.

Best regards,
Jay Lawrence
Freshli — support@freshli.app
