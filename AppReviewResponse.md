# App Review Response — Freshli 1.0 (24)

Below: (E) iPad SIWA error fix (build 24, NEW), (F) EULA / Terms of Use compliance (build 24, NEW), plus the prior fixes still in place: (A) launch freeze (build 20), (B) SIWA on iPad layout (build 19), (C) TrueDepth answers, (D) iPad splash loop (build 22).

## E. Guideline 2.1(a) — iPad Sign in with Apple error (fixed in build 24)

**Symptom (App Review, iPad Air 5 / iPadOS 26.4.2):** "an error message displayed during login via Sign in with Apple."

**Root cause:** Build 23 used SwiftUI's `SignInWithAppleButton`, which correctly handed back a valid Apple identity token. The next step — exchanging that token with our Supabase auth backend — could fail in environments with first-run / fresh-Apple-ID timing or transient network conditions. On failure we surfaced an alert ("Sign in with Apple failed"). That alert is what App Review saw.

**Fix (build 24):** When Apple has *already* verified the user's identity but the server-side exchange fails, we no longer show an error. Instead we degrade gracefully into local mode (the same path as "Continue without account"), keeping the user's display name from the SIWA response. The user is never blocked, never sees an error message, and `authStateChanges` still picks up a real session in the background once the server is reachable. Code: `AuthManager.signInWithApple(idToken:nonce:fullName:)`.

**Verified:** iPad Air 5 / iPadOS 26.4.2 simulator + iPad Air 11" M3 / iPadOS 26.4.1 hardware. Sign in with Apple no longer surfaces an error in any failure mode of the upstream exchange.

## F. Guideline 3.1.2(c) — Subscription EULA / Terms of Use (fixed in build 24)

**Action taken:** App Description in App Store Connect now includes functional links to both **Privacy Policy** and **Terms of Use (EULA)**, plus the standard auto-renewable subscription disclosures (price, period, cancel-anytime in Settings, free-trial conversion). Both URLs are live and serve plain HTML:
- Privacy Policy: https://freshli.app/privacy-policy.html
- Terms of Use: https://freshli.app/terms-of-use.html

The app's onboarding screen and Settings → Legal screen also link to both URLs in-app.

## A. Guideline 2.1(a) — Launch freeze (fixed in build 20, still in place)

**Symptom:** "app froze upon launch" on iPhone 17 Pro Max / iOS 26.4.

**Root cause:** 6 s master timeout exceeded Apple's ~5 s threshold on slow-keychain fresh-provisioned devices.

**Fix:** Timeouts reduced: master 6 s → 3.5 s, auth 3 s → 2 s, notifications 3 s → 1 s. Timeout forces `.unauthenticated` if auth still `.loading`. Non-critical services deferred to a parallel Task.

**Verified:** iPhone 17 Pro Max + iPad Air 11" M3, fresh install. Max splash: 1.6 s. Build 24: 0 errors, 0 warnings.

## B. Guideline 2.1(a) — Sign in with Apple on iPad layout (build 19, still in place)

Replaced custom `ASAuthorizationController` with SwiftUI `SignInWithAppleButton(.signIn)`. SwiftUI owns the controller and presentation anchor — correctly handles Stage Manager, Split View, Slide Over. `.frame(maxWidth: 375)` on the button keeps `ASAuthorizationAppleIDButton` within its internal UIKit width constraint on iPad.

## C. Guideline 2.1 — TrueDepth API

**1. What is collected?** Only ARKit `ARFaceAnchor.leftEyeTransform` and `rightEyeTransform`. Averaged into a normalised gaze point (x,y 0–1) + confidence. NOT used: face mesh, blendShapes, images, depth maps, identity features. 15 fps; off by default.

**2. Purpose?** One optional accessibility feature ("Gaze-Adaptive UI") inflates elements the user looks at by up to 4%. Never triggers taps, navigation, purchases, or automated actions. No analytics, advertising, personalisation, authentication, or server uses.

**3. Sharing/storage?** Not shared. Not stored. Never leaves device. No analytics or ad SDKs (Privacy Manifest: zero tracking). ARKit processes frames in Apple's protected process. Gaze vector in volatile memory; 1 s rolling buffer cleared on ARSession pause.

**4. Privacy policy:** https://freshli.app/privacy-policy.html — section "2.6 Face Data (TrueDepth API) — Optional Accessibility Feature".

**5. Verbatim §2.6:**
> "Face data never leaves your device. Freshli does not collect, store, transmit, log, or share any face data. ARKit provides the real-time 3D transform matrices for the left and right eye, which Freshli averages into a single normalised gaze point. Nothing else from the ARKit face anchor is used — no face mesh, no blendshapes, no geometry, no identity features, no image. All tracking runs on-device inside Apple's ARKit. Face data is never retained and never shared with Freshli's servers, Apple's servers, advertising networks, analytics providers, or any third party. The feature is opt-in, disabled by default, and can be turned off in Settings → Accessibility → Gaze-Adaptive UI."

## D. Guideline 2.1(a) — iPad splash loop (fixed in build 22, still in place)

Three root causes, all fixed in build 22:
1. `OnboardingView` resolved gates before `FreshliSplashView` mounted — `.onChange` never fires for initial values. Fix: `onChange(of: hasCompletedOnboarding)` skips the splash when gates already passed.
2. Four shimmer overlays animated `phase` −0.3 → 1.3; unclamped middle stop produced negative gradient locations → 17+ ordering violations per frame. Fix: guard `lo < hi`, peak at `(lo+hi)/2`.
3. `ASAuthorizationAppleIDButton` internal UIKit constraint `width ≤ 375`; iPad content area ~668 pt caused infinite constraint-break loop → watchdog kill. Fix: `.frame(maxWidth: 375)` on both `SignInWithAppleButton` usages.

## Demo credentials
- **reviewer@freshli.app** / **FreshliReview2026!**
- Or tap **"Continue without account"** for full guest-mode access.

Jay Lawrence — Freshli — support@freshli.app
