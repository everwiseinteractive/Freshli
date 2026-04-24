# App Review Response — Freshli 1.0 (19)

Below: (A) Sign in with Apple fix in build 19, (B) full restated TrueDepth answers.

## A. Guideline 2.1(a) — Sign in with Apple on iPad (fixed)

**Root cause:** Build 18 used a custom Button wired to our own ASAuthorizationController + presentation-anchor provider. On iPadOS 26.4.1 Stage Manager, UIApplication.connectedScenes can briefly have no .foregroundActive scene; our fallback returned a detached ASPresentationAnchor(), so performRequests() failed or presented into an invalid window — the error you saw.

**Fix (build 19):** Replaced with Apple's official SwiftUI SignInWithAppleButton(.signIn) in both auth entry points (AuthView, OnboardingSignInView). SwiftUI owns the ASAuthorizationController + presentation anchor, correctly handling multi-window, Split View, Slide Over, and Stage Manager. Nonce is generated in onRequest; identity token is exchanged with Supabase via signInWithIdToken.

**Verified:** iPad Air 11" M3 / iPadOS 26.4.1 — Stage Manager with 3 windows, Split View, Slide Over — sheet opens first time. iPhone 17 Pro Max / iOS 26.4.1 — works. Email sign-in and "Continue without account" guest mode remain available.

## B. Guideline 2.1 — TrueDepth API (restated)

**1. What is collected?** Only ARKit ARFaceAnchor.leftEyeTransform and rightEyeTransform (4×4 eye transforms). We average them into a normalised gaze point (x,y in 0–1) plus a confidence score. We do NOT use face mesh/geometry, blendShapes, raw images, depth maps, camera frames, or identity features. Session runs at 15 fps and is off by default.

**2. Purpose?** One optional accessibility feature — "Gaze-Adaptive UI" — inflates UI elements the user appears to look at by up to 4% so they are easier to find. The gaze point never triggers taps, navigation, purchases, or any automated action. No analytics, advertising, personalisation, authentication, biometric, fraud-detection, or server-side uses — current or planned.

**3. Sharing and storage?** Not shared with anyone. Not stored anywhere. Face data never leaves the device. Freshli has no analytics or ad SDKs (Privacy Manifest declares zero tracking). ARKit processes camera frames inside Apple's protected process; we never see them. The gaze vector lives in volatile memory for one frame; a rolling 1-second buffer (~15 points) is used for velocity smoothing and cleared when the ARSession pauses.

**4. Where in the privacy policy?** https://freshli.app/privacy.html — dedicated section **"2.6 Face Data (TrueDepth API) — Optional Accessibility Feature"**, immediately after §2.5 AI Processing.

**5. Verbatim quote from §2.6:**
> "Face data never leaves your device. Freshli does not collect, store, transmit, log, or share any face data. Face data is used only in volatile memory to compute the on-screen gaze vector, then discarded immediately. ARKit provides Freshli with the real-time 3D transform matrices for the left eye and right eye. Freshli averages these into a single normalised gaze point on the screen. Nothing else from the ARKit face anchor is used — no face mesh, no blendshapes, no geometry, no identity features, no image of the user's face. All face tracking runs on-device inside Apple's ARKit. The TrueDepth camera preview is never shown, never recorded, never written to disk. Face data is never retained and never shared with Freshli's servers, Apple's servers, advertising networks, analytics providers, or any third party. The feature is opt-in, disabled by default, and can be turned off in Settings → Accessibility → Gaze-Adaptive UI, or revoked via iOS Settings → Privacy & Security → Camera → Freshli."

## Demo credentials
- **Email:** reviewer@freshli.app · **Password:** FreshliReview2026!
- Or tap **"Continue without account"** on the auth landing for full guest-mode access.

Jay Lawrence — Freshli — support@freshli.app
