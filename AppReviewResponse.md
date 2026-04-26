# App Review Response — Freshli 1.0 (20)

Below: (A) launch-freeze fix in build 20, (B) SIWA fix retained from 19, (C) full restated TrueDepth answers.

## A. Guideline 2.1(a) — Launch freeze (fixed in build 20)

**Symptom:** "app froze upon launch" on iPhone 17 Pro Max / iOS 26.4.

**Root cause:** build 19's splash master safety timeout was 6 s. Apple's launch-responsiveness threshold is closer to 5 s, so on a fresh-provisioned device with slow keychain/network the splash could exceed the threshold and be reported as a freeze even though auth state was still resolving.

**Fix in build 20:**
- Master safety timeout: **6 s → 3.5 s** (well below Apple's 5 s threshold).
- Auth-restore timeout: **3 s → 2 s**. Notification permission timeout: **3 s → 1 s**.
- Master timeout now forces auth-state resolution: if `.loading`, it is forced to `.unauthenticated` so the screen has something to render the moment the splash dissolves.
- Non-critical service init (TipKit, MetricKit, NWPathMonitor, ambient-light) moved to a parallel Task so none can block the splash.
- Master timeout Task is now scheduled **first** in `.task`, armed before any awaited call.

**Verified:** iPhone 17 Pro Max / iOS 26.4.1 + iPad Air 11" M3 / iPadOS 26.4.1, fresh-installed across airplane-mode → wifi → cellular. Max observed splash: 1.6 s. Build: 0 warnings.

## B. Guideline 2.1(a) — Sign in with Apple on iPad (retained from build 19)

Build 19 replaced our custom Button + `ASAuthorizationController` with Apple's official SwiftUI `SignInWithAppleButton(.signIn)`. SwiftUI owns the controller and presentation anchor, correctly handling Stage Manager, Split View, Slide Over, and multi-window. Re-verified in build 20.

## C. Guideline 2.1 — TrueDepth API (restated)

**1. What is collected?** Only ARKit `ARFaceAnchor.leftEyeTransform` and `rightEyeTransform` (4×4 eye transforms). We average them into a normalised gaze point (x,y in 0–1) + confidence. NOT used: face mesh, blendShapes, raw images, depth maps, camera frames, identity features. Session runs at 15 fps; off by default.

**2. Purpose?** One optional accessibility feature — "Gaze-Adaptive UI" — inflates UI elements the user appears to look at by up to 4%. The gaze point never triggers taps, navigation, purchases, or any automated action. No analytics, advertising, personalisation, authentication, biometric, or server-side uses — current or planned.

**3. Sharing/storage?** Not shared. Not stored. Face data never leaves the device. Freshli has no analytics or ad SDKs (Privacy Manifest declares zero tracking). ARKit processes camera frames inside Apple's protected process; we never see them. The gaze vector lives in volatile memory for one frame; a rolling 1 s buffer (~15 points) for smoothing is cleared when the ARSession pauses.

**4. Where in the privacy policy?** https://freshli.app/privacy.html — section **"2.6 Face Data (TrueDepth API) — Optional Accessibility Feature"**.

**5. Verbatim quote from §2.6:**
> "Face data never leaves your device. Freshli does not collect, store, transmit, log, or share any face data. ARKit provides the real-time 3D transform matrices for the left and right eye, which Freshli averages into a single normalised gaze point. Nothing else from the ARKit face anchor is used — no face mesh, no blendshapes, no geometry, no identity features, no image. All tracking runs on-device inside Apple's ARKit. Face data is never retained and never shared with Freshli's servers, Apple's servers, advertising networks, analytics providers, or any third party. The feature is opt-in, disabled by default, and can be turned off in Settings → Accessibility → Gaze-Adaptive UI."

## Demo credentials
- **reviewer@freshli.app** / **FreshliReview2026!**
- Or tap **"Continue without account"** for full guest-mode access.

Jay Lawrence — Freshli — support@freshli.app
