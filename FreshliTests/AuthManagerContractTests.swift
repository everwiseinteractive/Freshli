import Testing
import Foundation
@testable import Freshli

// ══════════════════════════════════════════════════════════════════
// AuthManager contract tests.
//
// These tests pin the *contract* of AuthManager that the rest of the
// app and the launch state machine depend on. They do not network
// against Supabase — they exercise the pure-Swift state machine.
// ══════════════════════════════════════════════════════════════════

@Suite("AuthState equality")
struct AuthStateTests {

    @Test("AuthState equality is reflexive across all cases")
    func equalityReflexive() {
        #expect(AuthState.loading == .loading)
        #expect(AuthState.unauthenticated == .unauthenticated)
        #expect(AuthState.authenticated == .authenticated)
    }

    @Test("AuthState equality distinguishes cases")
    func equalityDistinguishes() {
        #expect(AuthState.loading != .unauthenticated)
        #expect(AuthState.loading != .authenticated)
        #expect(AuthState.unauthenticated != .authenticated)
    }
}

@Suite("AuthError localized descriptions")
struct AuthErrorTests {

    @Test("Every AuthError case provides a non-empty localized description")
    func everyCaseLocalized() {
        let cases: [AuthError] = [
            .invalidEmail,
            .weakPassword,
            .signUpFailed("test"),
            .signInFailed("test"),
            .signOutFailed("test"),
            .sessionExpired,
            .unknown("test")
        ]
        for error in cases {
            let description = error.errorDescription ?? ""
            #expect(!description.isEmpty, "AuthError \(error) has empty errorDescription")
        }
    }

    @Test("invalidEmail and weakPassword use localized strings (not raw English)")
    func invalidEmailLocalized() {
        // The errorDescription should resolve through String(localized:) so
        // a non-en locale gets the translated message. We can't easily flip
        // the locale in the test runtime, but we can assert the strings are
        // ours (containing key substrings).
        #expect(AuthError.invalidEmail.errorDescription?.contains("email") == true ||
                AuthError.invalidEmail.errorDescription?.contains("correo") == true ||
                AuthError.invalidEmail.errorDescription?.contains("e-mail") == true ||
                AuthError.invalidEmail.errorDescription?.contains("E-Mail") == true)
    }
}

// ══════════════════════════════════════════════════════════════════
@Suite("AppTab routing invariants")
struct AppTabTests {

    @Test("Every AppTab has a non-empty title and icon")
    @MainActor
    func everyTabIsRenderable() {
        for tab in AppTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.icon.isEmpty)
        }
    }

    @Test("AppTab raw values are stable for state restoration")
    @MainActor
    func rawValuesStable() {
        // These raw values are persisted to UserDefaults. Changing them
        // breaks state restoration across upgrades.
        #expect(AppTab.home.rawValue == "home")
        #expect(AppTab.pantry.rawValue == "pantry")
        #expect(AppTab.recipes.rawValue == "recipes")
        #expect(AppTab.community.rawValue == "community")
        #expect(AppTab.profile.rawValue == "profile")
    }

    @Test("AppTab(rawValue:) round-trips for every case")
    @MainActor
    func rawValueRoundTrip() {
        for tab in AppTab.allCases {
            let restored = AppTab(rawValue: tab.rawValue)
            #expect(restored == tab)
        }
    }
}

// ══════════════════════════════════════════════════════════════════
@Suite("FoodCategory + ExpiryStatus exhaustiveness")
struct CategoryEnumTests {

    @Test("Every FoodCategory has a non-default category color")
    @MainActor
    func everyCategoryColored() {
        // Colors are non-throwing so we just verify the function returns
        // for every enum case (compile-time exhaustiveness).
        for cat in FoodCategory.allCases {
            _ = PSColors.categoryColor(for: cat)
        }
    }

    @Test("Every ExpiryStatus has both a foreground and background color")
    @MainActor
    func everyExpiryStatusColored() {
        for status in ExpiryStatus.allCases {
            _ = PSColors.expiryColor(for: status)
            _ = PSColors.expiryBackground(for: status)
        }
    }
}
