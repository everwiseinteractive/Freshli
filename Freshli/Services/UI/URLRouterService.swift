//
//  URLRouterService.swift
//  Freshli
//
//  Routes incoming deep-link URLs (custom scheme `freshli://` and Universal Links
//  on https://freshli.app) into in-app destinations. Required for App Store
//  In-App Events: each event's deep link MUST navigate the user to the event's
//  content within the app, otherwise App Review will reject the event.
//
//  Supported routes (used by the in-app events declared in App Store Connect):
//
//      freshli://events/spring-pantry-reset      → Pantry tab + reset challenge banner
//      freshli://events/world-environment-day    → Home tab + Live Rescue Wave focus
//      freshli://events/plastic-free-july        → Home tab + 31-day challenge banner
//      freshli://events/bbq-saver                → Community tab + Magic Bag listings
//      freshli://events/lunch-lab                → Recipes tab + Rescue Chef
//      freshli://events/world-food-day           → Home tab + global rescue wave
//      freshli://events/holiday-pantry-hero      → Pantry tab + holiday tips
//
//  Universal-link equivalents (https://freshli.app/events/<slug>) resolve via the
//  same `Route` enum once Associated Domains + AASA are configured (see
//  README_DEEP_LINKS.md).
//

import Foundation
import SwiftUI
import os

@MainActor
@Observable
final class URLRouterService {

    // MARK: - Singleton

    static let shared = URLRouterService()

    // MARK: - Route

    /// A destination the router has resolved an incoming URL into.
    /// Views observe `pendingRoute` and respond by switching tabs or presenting
    /// the relevant sheet / banner.
    enum Route: Equatable {
        case event(EventSlug)
        case tab(AppTab)
        case unknown
    }

    /// Each slug maps 1:1 to an App Store In-App Event configured
    /// in App Store Connect. The 12 slugs below give us at least
    /// one event per calendar month — every visit to the App Store
    /// listing surfaces a fresh, time-sensitive event with a deep
    /// link, optimised for both new-user acquisition (existing /
    /// browsing card on the listing) and re-engagement of lapsed
    /// users (push-notification badging via the App Store app).
    enum EventSlug: String, CaseIterable, Sendable {
        // Q1
        case veganuary            = "veganuary"               // January
        case valentinesSweetSave  = "valentines-sweet-save"   // February
        case stPatricksSoupStash  = "st-patricks-soup-stash"  // March
        // Q2
        case easterBrunchSaver    = "easter-brunch-saver"     // April
        case springPantryReset    = "spring-pantry-reset"     // May
        case worldEnvironmentDay  = "world-environment-day"   // June 5
        // Q3
        case plasticFreeJuly      = "plastic-free-july"       // July
        case bbqSaver             = "bbq-saver"               // August
        case lunchLab             = "lunch-lab"               // September
        // Q4
        case worldFoodDay         = "world-food-day"          // October 16
        case halloweenTreatsTrade = "halloween-treats-trade"  // October 31
        case copClimateSprint     = "cop-climate-sprint"      // November
        case holidayPantryHero    = "holiday-pantry-hero"     // December

        /// The tab to switch to when this event is opened.
        var landingTab: AppTab {
            switch self {
            case .veganuary:            return .recipes
            case .valentinesSweetSave:  return .recipes
            case .stPatricksSoupStash:  return .recipes
            case .easterBrunchSaver:    return .recipes
            case .springPantryReset:    return .pantry
            case .worldEnvironmentDay:  return .home
            case .plasticFreeJuly:      return .home
            case .bbqSaver:             return .community
            case .lunchLab:             return .recipes
            case .worldFoodDay:         return .home
            case .halloweenTreatsTrade: return .community
            case .copClimateSprint:     return .home
            case .holidayPantryHero:    return .pantry
            }
        }

        /// User-facing title for the welcome banner.
        var displayTitle: String {
            switch self {
            case .veganuary:            return String(localized: "Veganuary Rescue")
            case .valentinesSweetSave:  return String(localized: "Valentine's Sweet Save")
            case .stPatricksSoupStash:  return String(localized: "St Patrick's Soup Stash")
            case .easterBrunchSaver:    return String(localized: "Easter Brunch Saver")
            case .springPantryReset:    return String(localized: "Spring Pantry Reset")
            case .worldEnvironmentDay:  return String(localized: "World Environment Day")
            case .plasticFreeJuly:      return String(localized: "Plastic Free July")
            case .bbqSaver:             return String(localized: "Bank Holiday BBQ Saver")
            case .lunchLab:             return String(localized: "Lunch Lab")
            case .worldFoodDay:         return String(localized: "World Food Day Sprint")
            case .halloweenTreatsTrade: return String(localized: "Halloween Treats Trade")
            case .copClimateSprint:     return String(localized: "COP Climate Sprint")
            case .holidayPantryHero:    return String(localized: "Holiday Pantry Hero")
            }
        }

        /// Short subtitle shown in the event banner.
        var displaySubtitle: String {
            switch self {
            case .veganuary:            return String(localized: "31 plant-led recipes. One rescued fridge.")
            case .valentinesSweetSave:  return String(localized: "Share the love — and last week's roses.")
            case .stPatricksSoupStash:  return String(localized: "Stash a soup, save a fiver.")
            case .easterBrunchSaver:    return String(localized: "Turn leftovers into Sunday brunch heroes.")
            case .springPantryReset:    return String(localized: "Reset your fridge in 14 days.")
            case .worldEnvironmentDay:  return String(localized: "One day. One rescue. One planet.")
            case .plasticFreeJuly:      return String(localized: "31 days. Zero plastic.")
            case .bbqSaver:             return String(localized: "Don't waste the feast.")
            case .lunchLab:             return String(localized: "14 lunches in 14 minutes with AI.")
            case .worldFoodDay:         return String(localized: "Join the global rescue wave.")
            case .halloweenTreatsTrade: return String(localized: "Spooky surplus? Trade it with the street.")
            case .copClimateSprint:     return String(localized: "Two weeks. Real climate action.")
            case .holidayPantryHero:    return String(localized: "Don't waste the feast. Share it.")
            }
        }
    }

    // MARK: - State observed by views

    /// The latest route the router has resolved. AppTabView observes this and
    /// reacts by switching tabs / presenting banners. After consumption the
    /// view should call `clear()` so the same route doesn't fire twice.
    private(set) var pendingRoute: Route? = nil

    /// Whichever event banner should currently be shown. Set when an event
    /// route is resolved; cleared when the user dismisses the banner.
    private(set) var activeEvent: EventSlug? = nil

    private let logger = Logger(subsystem: "com.freshli.app", category: "URLRouter")

    private init() {}

    // MARK: - Public API

    /// Handle a URL coming from `.onOpenURL` (custom scheme) or
    /// `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` (universal link).
    /// Safe to call with `nil` (no-op).
    @discardableResult
    func handle(_ url: URL?) -> Route {
        guard let url else {
            logger.debug("handle(nil) — ignored")
            return .unknown
        }
        let route = resolve(url)
        logger.info("Resolved \(url.absoluteString, privacy: .public) -> \(String(describing: route), privacy: .public)")
        pendingRoute = route
        if case let .event(slug) = route {
            activeEvent = slug
        }
        return route
    }

    /// Called by AppTabView once it has consumed a pending route.
    func clear() {
        pendingRoute = nil
    }

    /// Called when the user dismisses the in-app event banner.
    func dismissActiveEvent() {
        activeEvent = nil
    }

    // MARK: - Resolution

    /// Pure URL→Route mapping. Public so unit tests can exercise it without
    /// going through the singleton's mutable state.
    func resolve(_ url: URL) -> Route {
        // Only honour our two trusted hosts.
        let isCustomScheme    = url.scheme?.lowercased() == "freshli"
        let isUniversalLink   = url.scheme?.lowercased() == "https"
                              && url.host?.lowercased() == "freshli.app"
        guard isCustomScheme || isUniversalLink else { return .unknown }

        // Path components for both `freshli://events/foo` and `https://freshli.app/events/foo`.
        // For custom-scheme URLs, `host` contains the first segment ("events"),
        // and `path` contains the rest. Normalize both into a single component list.
        var components: [String] = []
        if isCustomScheme {
            if let host = url.host, !host.isEmpty { components.append(host) }
            components.append(contentsOf: url.pathComponents.filter { $0 != "/" && !$0.isEmpty })
        } else {
            components.append(contentsOf: url.pathComponents.filter { $0 != "/" && !$0.isEmpty })
        }

        guard let first = components.first?.lowercased() else { return .unknown }

        switch first {
        case "events":
            // /events/<slug>
            guard components.count >= 2,
                  let slug = EventSlug(rawValue: components[1].lowercased())
            else { return .unknown }
            return .event(slug)

        case "tab":
            // /tab/<name>
            guard components.count >= 2,
                  let tab = AppTab(rawValue: components[1].lowercased())
            else { return .unknown }
            return .tab(tab)

        default:
            return .unknown
        }
    }
}
