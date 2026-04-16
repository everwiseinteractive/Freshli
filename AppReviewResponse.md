# App Store Review Response — Freshli 1.0
**Submission ID:** 91ef81fb-62f7-420c-9459-c4961d6bc879
**Review date:** April 16, 2026
**Review device:** iPad Air 11-inch (M3), iPadOS 26.4.1

Dear App Review,

Thank you for the thorough review. We've addressed all three items below and submitted a new build. Details for each guideline:

---

## Guideline 3.1.2(c) — Subscriptions: Functional EULA + Privacy links

**Root cause:** The paywall in the previous build linked to `https://freshli.app/terms-of-use` and `https://freshli.app/privacy-policy`, but our deployed page paths are `/terms.html` and `/privacy.html`. Those two links returned 404.

**Fix shipped in this build:**
1. `FreshliProView.swift` now links directly to:
   - Terms of Use (EULA): https://freshli.app/terms.html
   - Privacy Policy: https://freshli.app/privacy.html
2. For defence-in-depth we also added server-side redirects at the old paths (`/terms-of-use` → `/terms.html`, `/privacy-policy` → `/privacy.html`) so any previously-shipped build will still resolve to the live pages.
3. The Privacy Policy URL in App Store Connect → App Information is already set to `https://freshli.app/privacy.html` and has been verified. The App Description contains the Terms of Use link as required.
4. The paywall continues to display all required subscription disclosures: title, price, billing period, auto-renewal terms, cancellation instructions, and free-trial terms.

**To verify:** Tap the Profile tab → Upgrade to Freshli+ → scroll to the bottom of the paywall → tap "Terms of Use (EULA)" and "Privacy Policy". Both open the live pages in Safari.

---

## Guideline 2.1(a) — App Completeness: Sign in with Apple + native login errors

**Root cause — Sign in with Apple:** Our previous auth screen rendered an `SignInWithAppleButton` and then *overlaid* it with a transparent `Button` that invoked our own `AppleSignInCoordinator`. On iPadOS this produced two simultaneous `ASAuthorizationController.performRequests()` calls — one without a nonce (from the native button's `onRequest`) and one with a nonce (from our coordinator). Additionally, our coordinator did not provide a `presentationContextProvider`, which iPadOS requires (especially inside multi-window / Stage Manager scenes) to know which window should present the system sheet. The net effect on iPad Air 11-inch (M3) / iPadOS 26.4.1 was that the Apple sign-in sheet either never appeared or failed with "The operation couldn't be completed".

**Root cause — Native login:** If the reviewer account was not created via the in-app sign-up flow, Supabase returned "invalid login credentials" and our error handler surfaced a generic "Sign in failed" message. Additionally, if the reviewer tapped Sign In before creating an account, the same generic error appeared.

**Fixes shipped in this build:**
1. Removed the overlay pattern. Sign in with Apple is now a single, clean button that calls `AppleSignInCoordinator.signIn()` once, with a nonce, through a single `ASAuthorizationController`.
2. `AppleSignInCoordinator` now conforms to `ASAuthorizationControllerPresentationContextProviding` and returns the foreground-active key window across all connected `UIWindowScene`s — this correctly handles iPad multi-window, Split View, Slide Over, and Stage Manager.
3. Error handling in `AuthManager.signIn(...)` now maps Supabase error types to actionable copy:
   - "Incorrect email or password. Please try again or tap 'Forgot?'"
   - "Please confirm your email address first. Check your inbox…"
   - "Can't reach the server. Check your internet connection…"
   - "Too many attempts. Please wait a moment…"
4. We seeded and verified the reviewer account (credentials below). The reviewer can also use **"Continue without account"** on the auth landing screen to explore the full app in guest mode.

**Demo credentials for review:**
- **Email:** reviewer@freshli.app
- **Password:** FreshliReview2026!

**Also available:** Tap "Continue without account" on the auth landing screen to explore the full app without signing in.

**Reproduction on our side:** We reproduced the original failure on iPad Air 11-inch (M3) running iPadOS 26.4.1 and confirmed the fix in this build on the same device and OS.

---

## Guideline 2.1 — Information Needed: TrueDepth API usage

Here are complete and detailed answers to each of your five questions.

### 1. What information is the app collecting using the TrueDepth API?

Freshli uses Apple's ARKit face-tracking via the TrueDepth camera to compute a **gaze vector** — i.e., a normalised point on the screen (x, y in the range 0–1) representing where the user's eyes appear to be looking, plus a confidence score.

Concretely, ARKit provides an `ARFaceAnchor` on each frame. Freshli reads only two properties from that anchor — `leftEyeTransform` and `rightEyeTransform` (the 4×4 rotation/translation matrices of each eye relative to the face) — averages them, and projects the result onto a normalised screen coordinate. Freshli **does not** use, store, or read:

- The face mesh / geometry (`geometry` property)
- Blendshape coefficients (`blendShapes`)
- Any raw image, depth map, or camera frame
- Face identity features of any kind
- Any other property of `ARFaceAnchor`

The ARKit face-tracking session runs at a throttled 15 fps for battery efficiency.

### 2. For what purposes is this information collected? Provide a complete and clear explanation of all planned uses of this data.

The gaze vector is used **only** to power an **optional accessibility feature** called **Gaze-Adaptive UI**. When enabled, UI elements that the user appears to be looking at subtly inflate by up to 4% (a `.scaleEffect`) so they are easier to find and read. The feature is purely visual — the gaze vector **never** triggers taps, navigations, purchases, or any automated action on the user's behalf.

This is the **only** planned use. There are no current or planned uses for:

- Analytics, heatmapping, or attention measurement
- Advertising, targeting, or audience segmentation
- Personalisation or recommendation
- Authentication, identification, or biometrics
- Fraud detection
- Any server-side processing

If we ever wished to add a new use in the future, we would update this privacy policy, submit a new build, and re-request user consent before that use took effect.

### 3. Will the data be shared with any third parties? Where will this information be stored?

**No.** Face data is not shared with any third party and is not stored anywhere.

- **Not shared with Freshli's servers:** The gaze vector and all face-tracking data remain on the user's device and are never transmitted over the network.
- **Not shared with Apple's servers:** ARKit face tracking runs entirely on-device inside Apple's protected process. Freshli never sees raw camera frames.
- **Not shared with any third party:** No analytics SDK, ad SDK, CDN, or other third party receives face data. Freshli has no advertising or analytics SDKs that could transmit this data — our Privacy Manifest declares zero tracking.
- **Not stored:** The gaze vector is held only in volatile memory for the single purpose of animating UI scale, and is discarded each frame. There is no local cache, no SwiftData record, no UserDefaults entry, no file on disk, and no iCloud / CloudKit record containing face data. A small rolling buffer of the most-recent 15 gaze points (≈1 second) is held in RAM solely for velocity smoothing and is cleared when the ARSession pauses or the app backgrounds.

### 4. Where in the privacy policy is the app's collection, use, disclosure, sharing, and retention of face data explained? Identify the specific sections in your privacy policy where this information is located.

Our Privacy Policy at **https://freshli.app/privacy.html** contains a dedicated section titled:

> **2.6 Face Data (TrueDepth API) — Optional Accessibility Feature**

This section is located immediately after section 2.5 (AI Processing) and appears at the top of the "Information We Collect" chapter, so it is highly visible. It explicitly covers: what face data is used, the purpose, processing location, retention, sharing (none), and user control.

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

## Summary of changes in this submission

| File | Change |
|---|---|
| `Freshli/Features/Subscription/FreshliProView.swift` | Terms/Privacy links now point to `/terms.html` and `/privacy.html` |
| `Freshli/Features/Profile/FreshliLegalView.swift` | Display strings updated to the correct public URLs |
| `Freshli/Features/Auth/AppleSignInHelper.swift` | Added `ASAuthorizationControllerPresentationContextProviding` for iPadOS multi-window support |
| `Freshli/Features/Auth/AuthView.swift` | Replaced double-invocation overlay with a single, nonce-bound Sign in with Apple button |
| `Freshli/Supabase/AuthManager.swift` | Actionable error messages for both email/password and Apple sign-in |
| `Freshli/Info.plist` | `NSCameraUsageDescription` updated to cover TrueDepth gaze feature |
| `docs/privacy.html` | New section 2.6 — Face Data (TrueDepth API) disclosure |
| `docs/terms-of-use.html`, `docs/privacy-policy.html` | Redirect pages (belt-and-braces for older shipped builds) |

Please let us know if you need anything further. Thank you for your time reviewing Freshli.

Best regards,
Jay Lawrence
Freshli — support@freshli.app
