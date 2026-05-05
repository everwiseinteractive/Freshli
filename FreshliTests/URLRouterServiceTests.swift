//
//  URLRouterServiceTests.swift
//  FreshliTests
//
//  Verifies every App Store In-App Event deep-link slug resolves to the
//  expected route. If any of these tests fail, App Review will reject the
//  corresponding event.
//

import XCTest
@testable import Freshli

@MainActor
final class URLRouterServiceTests: XCTestCase {

    private let router = URLRouterService.shared

    // MARK: - Custom scheme

    func testCustomScheme_AllSevenEventSlugsResolve() {
        let cases: [(String, URLRouterService.EventSlug)] = [
            ("freshli://events/spring-pantry-reset",   .springPantryReset),
            ("freshli://events/world-environment-day", .worldEnvironmentDay),
            ("freshli://events/plastic-free-july",     .plasticFreeJuly),
            ("freshli://events/bbq-saver",             .bbqSaver),
            ("freshli://events/lunch-lab",             .lunchLab),
            ("freshli://events/world-food-day",        .worldFoodDay),
            ("freshli://events/holiday-pantry-hero",   .holidayPantryHero),
        ]
        for (urlString, expected) in cases {
            let url = URL(string: urlString)!
            XCTAssertEqual(router.resolve(url), .event(expected),
                           "Custom scheme \(urlString) should resolve to .event(.\(expected))")
        }
    }

    // MARK: - Universal Links

    func testUniversalLink_AllSevenEventSlugsResolve() {
        let cases: [(String, URLRouterService.EventSlug)] = [
            ("https://freshli.app/events/spring-pantry-reset",   .springPantryReset),
            ("https://freshli.app/events/world-environment-day", .worldEnvironmentDay),
            ("https://freshli.app/events/plastic-free-july",     .plasticFreeJuly),
            ("https://freshli.app/events/bbq-saver",             .bbqSaver),
            ("https://freshli.app/events/lunch-lab",             .lunchLab),
            ("https://freshli.app/events/world-food-day",        .worldFoodDay),
            ("https://freshli.app/events/holiday-pantry-hero",   .holidayPantryHero),
        ]
        for (urlString, expected) in cases {
            let url = URL(string: urlString)!
            XCTAssertEqual(router.resolve(url), .event(expected),
                           "Universal link \(urlString) should resolve to .event(.\(expected))")
        }
    }

    // MARK: - Landing tab mapping (the critical bit App Reviewers test)

    func testEventLandingTabsAreSensible() {
        XCTAssertEqual(URLRouterService.EventSlug.springPantryReset.landingTab,   .pantry)
        XCTAssertEqual(URLRouterService.EventSlug.worldEnvironmentDay.landingTab, .home)
        XCTAssertEqual(URLRouterService.EventSlug.plasticFreeJuly.landingTab,     .home)
        XCTAssertEqual(URLRouterService.EventSlug.bbqSaver.landingTab,            .community)
        XCTAssertEqual(URLRouterService.EventSlug.lunchLab.landingTab,            .recipes)
        XCTAssertEqual(URLRouterService.EventSlug.worldFoodDay.landingTab,        .home)
        XCTAssertEqual(URLRouterService.EventSlug.holidayPantryHero.landingTab,   .pantry)
    }

    // MARK: - Defensive fallbacks

    func testUnknownSchemeDoesNotResolve() {
        let cases = [
            "fake://events/spring-pantry-reset",
            "http://freshli.app/events/spring-pantry-reset",   // http not https
            "https://example.com/events/spring-pantry-reset",  // wrong host
            "https://freshli.app/wat/spring-pantry-reset",     // wrong segment
            "freshli://events/not-a-real-event",               // unknown slug
            "freshli://",                                      // empty
        ]
        for s in cases {
            guard let u = URL(string: s) else { continue }
            XCTAssertEqual(router.resolve(u), .unknown, "\(s) should resolve to .unknown")
        }
    }

    func testTabRouteResolves() {
        XCTAssertEqual(router.resolve(URL(string: "freshli://tab/recipes")!), .tab(.recipes))
        XCTAssertEqual(router.resolve(URL(string: "https://freshli.app/tab/community")!), .tab(.community))
    }

    func testHandleNilIsSafe() {
        XCTAssertEqual(router.handle(nil), .unknown)
    }
}
