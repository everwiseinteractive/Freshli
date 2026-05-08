import SwiftUI
import SwiftData

// MARK: - Council Impact Report View
// Anonymised postcode-level waste data for local councils. Shown to users
// so they can see their footprint and opt in to data sharing.

struct CouncilImpactReportView: View {
    @Environment(AuthManager.self) private var authManager
    @Query private var items: [FreshliItem]
    @State private var binLogService = BinLogService.shared
    @State private var report: CouncilReport?
    /// User-visible locality the report is scoped to. Resolved from
    /// `AreaService.shared.currentArea` (which the user confirms in
    /// the Community tab) and falls back to a generic "Your area"
    /// label when the user hasn't set one yet.
    @State private var localityLabel: String = String(localized: "Your area")
    /// Display name of the local authority for `localityLabel`,
    /// e.g. "Leeds City Council" for "Leeds", "Camden Council" for
    /// "Camden". Computed via `CouncilLookup.councilName(for:)` —
    /// this is what gets shown in the hero card so the user
    /// understands which council the data is being shared with.
    @State private var councilDisplayName: String = String(localized: "Your local council")

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                hero
                if let report = report {
                    headlineCard(report)
                    comparisonCard(report)
                    topCategoriesCard(report)
                    reasonsCard(report)
                    shareDataCard
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle("Council Impact")
        .navigationBarTitleDisplayMode(.inline)
        .task { generate() }
    }

    private var hero: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: PSLayout.scaledFont(40)))
                .foregroundStyle(Color(hex: 0x3B82F6))
            VStack(spacing: PSSpacing.xs) {
                // Authority pill — surfaces the user's actual local
                // council (resolved from their confirmed area) so the
                // user is sure which authority the anonymised data
                // would reach.
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                    Text(councilDisplayName)
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundStyle(Color(hex: 0x3B82F6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: 0x3B82F6).opacity(0.12), in: Capsule())

                Text(String(localized: "Council Impact Report"))
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                Text(String(localized: "Anonymised waste data helps \(councilDisplayName) plan better collections and reduction campaigns."))
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    private func headlineCard(_ report: CouncilReport) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                    // Header switched from postcode to locality —
                    // councils don't aggregate by postcode in the
                    // app's MVP; they aggregate by area. Keep the
                    // tracked-uppercase typographic flavour so the
                    // hero still reads as an official report.
                    Text(localityLabel.uppercased())
                        .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(report.reportPeriod)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: PSLayout.scaledFont(32)))
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                Text("\(report.totalWastedItems)")
                    .font(.system(size: PSLayout.scaledFont(56), weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 0) {
                    Text("items")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    Text("wasted")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: PSSpacing.lg) {
                headlineStat(value: String(format: "%.1fkg", report.totalWastedKg), label: "By weight")
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: PSLayout.scaled(32))
                headlineStat(value: "£\(String(format: "%.0f", report.totalFinancialImpact))", label: "Financial")
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: PSLayout.scaled(32))
                headlineStat(value: String(format: "%.0fkg", report.estimatedCO2Impact), label: "CO₂")
            }
        }
        .padding(PSSpacing.xl)
        .background(LinearGradient(
            colors: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4).opacity(0.9)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .shadow(color: Color(hex: 0x3B82F6).opacity(0.3), radius: 20, y: 8)
    }

    private func headlineStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: PSLayout.scaledFont(16), weight: .black))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(10), weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func comparisonCard(_ report: CouncilReport) -> some View {
        guard let comparison = report.comparison else {
            return AnyView(EmptyView())
        }
        return AnyView(VStack(alignment: .leading, spacing: PSSpacing.md) {
            sectionHeader("vs. Average", icon: "chart.xyaxis.line", color: PSColors.accentTeal)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Rank")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(comparison.rank)")
                            .font(.system(size: PSLayout.scaledFont(32), weight: .black, design: .rounded))
                            .foregroundStyle(PSColors.primaryGreen)
                        Text("th percentile")
                            .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("National avg")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                    Text("\(comparison.nationalAverage) items/month")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("Regional avg")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                        .padding(.top, 2)
                    Text("\(comparison.regionalAverage) items/month")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                }
            }
            Text("You're doing better than \(comparison.rank)% of households in your area. Every item saved shrinks the council's collection costs.")
                .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1)))
    }

    private func topCategoriesCard(_ report: CouncilReport) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            sectionHeader("Top Wasted Categories", icon: "chart.pie.fill", color: PSColors.secondaryAmber)
            if report.topWastedCategories.isEmpty {
                Text("No category breakdown yet.")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            } else {
                let total = report.topWastedCategories.reduce(0) { $0 + $1.count }
                VStack(spacing: PSSpacing.sm) {
                    ForEach(report.topWastedCategories, id: \.category) { cat, count in
                        categoryBar(category: cat, count: count, total: total)
                    }
                }
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }

    private func categoryBar(category: String, count: Int, total: Int) -> some View {
        let pct = total > 0 ? Double(count) / Double(total) : 0
        return VStack(spacing: 4) {
            HStack {
                Text(category)
                    .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.secondaryAmber)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PSColors.borderLight).frame(height: PSLayout.scaled(6))
                    Capsule()
                        .fill(LinearGradient(colors: [PSColors.secondaryAmber, Color(hex: 0xF97316)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * pct, height: PSLayout.scaled(6))
                }
            }
            .frame(height: PSLayout.scaled(6))
        }
    }

    private func reasonsCard(_ report: CouncilReport) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            sectionHeader("Why Food Is Wasted Locally", icon: "questionmark.circle.fill", color: Color(hex: 0xA855F7))
            if report.topReasons.isEmpty {
                Text("No reason data yet — log items in the bin to unlock insights.")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            } else {
                VStack(spacing: PSSpacing.sm) {
                    ForEach(report.topReasons, id: \.reason) { reason, count in
                        HStack {
                            Text("•")
                                .foregroundStyle(Color(hex: 0xA855F7))
                            Text(reason)
                                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                                .foregroundStyle(PSColors.textPrimary)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                                .foregroundStyle(Color(hex: 0xA855F7))
                        }
                    }
                }
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }

    private var shareDataCard: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: PSLayout.scaledFont(22)))
                .foregroundStyle(Color(hex: 0x3B82F6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Share Anonymous Data")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Help your council reduce local waste — no personal info is ever shared.")
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: .constant(true))
                .labelsHidden()
                .tint(Color(hex: 0x3B82F6))
        }
        .padding(PSSpacing.lg)
        .background(Color(hex: 0x3B82F6).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(Color(hex: 0x3B82F6).opacity(0.2), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: PSLayout.scaledFont(40)))
                .foregroundStyle(PSColors.textTertiary)
            Text("No data yet")
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
            Text("Add and track items to generate your council impact report.")
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(PSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: icon).font(.system(size: PSLayout.scaledFont(13))).foregroundStyle(color)
            Text(title)
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase).tracking(0.5)
        }
    }

    private func generate() {
        // Resolve the locality from the user's confirmed Community
        // area. If they haven't picked one yet (older account, or
        // location denied), the hero falls back to the generic
        // "Your area" / "Your local council" labels and the data
        // section still renders against their items.
        Task { @MainActor in
            // 1. Hydrate the Community area if it hasn't been loaded.
            if AreaService.shared.currentArea == nil,
               let userId = authManager.currentUserId {
                _ = try? await AreaService.shared.loadCurrentArea(for: userId)
            }
            if let area = AreaService.shared.currentArea {
                let locality = area.locality?.isEmpty == false ? area.locality! : area.name
                localityLabel = locality
                councilDisplayName = CouncilLookup.councilName(
                    locality: locality,
                    countryCode: area.countryCode
                )
            }
            report = CouncilDataService.shared.generateReport(
                items: items,
                binEntries: binLogService.entries,
                // Pass the locality through the existing `postcode:`
                // parameter so we don't have to fork the service
                // signature. Server-side aggregation already keys
                // off the string verbatim.
                postcode: localityLabel
            )
        }
    }
}

// MARK: - CouncilLookup
//
// Maps a (locality, countryCode) pair to the human-readable name of
// its local authority. Covers the most common UK / US / EU
// localities the app currently sees in production; falls back to
// "<Locality> Council" / "<Locality> City Council" / "<Locality>
// Authority" depending on country conventions.
//
// Static dictionary instead of a network round-trip — there's no
// public open-data API that maps every locality to its council
// reliably across countries, and the "right" data for the user is
// almost always cached at compile time. New entries can be added
// without a re-build via remote config in a future release.

enum CouncilLookup {
    /// Hand-curated overrides — these win over the country-template
    /// fallback. Keys are lowercased, whitespace-trimmed locality
    /// names. UK list covers London boroughs + the largest English
    /// cities + Scottish/Welsh/NI capitals.
    nonisolated(unsafe) private static let overrides: [String: String] = [
        // ── London (33 boroughs, each a unitary authority) ──────────
        "barking and dagenham":   "Barking and Dagenham Council",
        "barnet":                 "Barnet Council",
        "bexley":                 "Bexley Council",
        "brent":                  "Brent Council",
        "bromley":                "Bromley Council",
        "camden":                 "Camden Council",
        "city of london":         "City of London Corporation",
        "croydon":                "Croydon Council",
        "ealing":                 "Ealing Council",
        "enfield":                "Enfield Council",
        "greenwich":              "Royal Borough of Greenwich",
        "hackney":                "Hackney Council",
        "hammersmith and fulham": "Hammersmith and Fulham Council",
        "haringey":               "Haringey Council",
        "harrow":                 "Harrow Council",
        "havering":               "Havering Council",
        "hillingdon":             "Hillingdon Council",
        "hounslow":               "Hounslow Council",
        "islington":              "Islington Council",
        "kensington and chelsea": "Royal Borough of Kensington and Chelsea",
        "kingston upon thames":   "Royal Borough of Kingston upon Thames",
        "lambeth":                "Lambeth Council",
        "lewisham":               "Lewisham Council",
        "merton":                 "Merton Council",
        "newham":                 "Newham Council",
        "redbridge":              "Redbridge Council",
        "richmond upon thames":   "Richmond upon Thames Council",
        "southwark":              "Southwark Council",
        "sutton":                 "Sutton Council",
        "tower hamlets":          "Tower Hamlets Council",
        "waltham forest":         "Waltham Forest Council",
        "wandsworth":             "Wandsworth Council",
        "westminster":            "Westminster City Council",
        "london":                 "Greater London Authority",

        // ── England — major cities ──────────────────────────────────
        "leeds":         "Leeds City Council",
        "manchester":    "Manchester City Council",
        "birmingham":    "Birmingham City Council",
        "liverpool":     "Liverpool City Council",
        "sheffield":     "Sheffield City Council",
        "bristol":       "Bristol City Council",
        "newcastle":     "Newcastle City Council",
        "newcastle upon tyne": "Newcastle City Council",
        "nottingham":    "Nottingham City Council",
        "leicester":     "Leicester City Council",
        "coventry":      "Coventry City Council",
        "bradford":      "Bradford Council",
        "wakefield":     "Wakefield Council",
        "york":          "City of York Council",
        "brighton":      "Brighton & Hove City Council",
        "brighton and hove": "Brighton & Hove City Council",
        "oxford":        "Oxford City Council",
        "cambridge":     "Cambridge City Council",
        "southampton":   "Southampton City Council",
        "portsmouth":    "Portsmouth City Council",
        "plymouth":      "Plymouth City Council",
        "stoke-on-trent": "Stoke-on-Trent City Council",
        "wirral":        "Wirral Metropolitan Borough Council",
        "moreton":       "Wirral Metropolitan Borough Council",

        // ── Scotland / Wales / NI ───────────────────────────────────
        "edinburgh":     "City of Edinburgh Council",
        "glasgow":       "Glasgow City Council",
        "aberdeen":      "Aberdeen City Council",
        "dundee":        "Dundee City Council",
        "cardiff":       "Cardiff Council",
        "swansea":       "Swansea Council",
        "newport":       "Newport City Council",
        "belfast":       "Belfast City Council",
    ]

    /// Resolve the council display name for a given locality +
    /// ISO country code.
    static func councilName(locality: String?, countryCode: String?) -> String {
        let trimmed = (locality ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "Your local council") }

        // 1. Exact override hit (UK boroughs / cities).
        if let hit = overrides[trimmed.lowercased()] {
            return hit
        }

        // 2. Country-template fallback. UK = "<X> Council"; US =
        // "<X> City Council"; everywhere else = "<X> Authority".
        let cc = (countryCode ?? "").uppercased()
        switch cc {
        case "GB":
            return String(localized: "\(trimmed) Council")
        case "US":
            return String(localized: "\(trimmed) City Council")
        case "IE":
            return String(localized: "\(trimmed) County Council")
        case "AU", "NZ":
            return String(localized: "\(trimmed) City Council")
        case "FR":
            return String(localized: "Mairie de \(trimmed)")
        case "DE", "AT":
            return String(localized: "Stadt \(trimmed)")
        case "ES":
            return String(localized: "Ayuntamiento de \(trimmed)")
        case "IT":
            return String(localized: "Comune di \(trimmed)")
        case "NL":
            return String(localized: "Gemeente \(trimmed)")
        default:
            return String(localized: "\(trimmed) Authority")
        }
    }
}

#Preview {
    NavigationStack { CouncilImpactReportView() }
        .modelContainer(for: FreshliItem.self, inMemory: true)
}
