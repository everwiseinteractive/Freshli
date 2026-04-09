import SwiftUI

// MARK: - Helper Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct LocalizationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var localizationService = LocalizationService.shared
    @State private var selectedCulturalRegions: Set<CulturalRegion> = []
    @State private var showCulturalPreferences = false
    @State private var appearAnimation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.xl) {
                    // MARK: - Measurement System

                    measurementSystemSection

                    // MARK: - Date Format

                    dateFormatSection

                    // MARK: - Temperature Unit

                    temperatureUnitSection

                    // MARK: - Currency

                    currencySection

                    // MARK: - Cultural Food Preferences

                    culturalPreferencesSection

                    // MARK: - Reset Button

                    resetButton
                }
                .padding(PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .navigationTitle(String(localized: "Localization Settings"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(PSMotion.springBouncy.delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Measurement System Section

    private var measurementSystemSection: some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text(String(localized: "Measurement System"))
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                VStack(spacing: PSSpacing.sm) {
                    ForEach(MeasurementSystem.allCases, id: \.self) { system in
                        measurementSystemButton(for: system)
                    }
                }

                // Preview
                previewBox(
                    title: String(localized: "Preview"),
                    lines: [
                        "Weight: \(localizationService.formatWeight(500))",
                        "Volume: \(localizationService.formatVolume(750))"
                    ]
                )
            }
        }
        .scaleEffect(appearAnimation ? 1 : 0.95)
        .opacity(appearAnimation ? 1 : 0)
    }

    private func measurementSystemButton(for system: MeasurementSystem) -> some View {
        Button(action: {
            withAnimation(PSMotion.springBouncy) {
                localizationService.currentMeasurementSystem = system
            }
        }) {
            HStack(spacing: PSSpacing.md) {
                Image(systemName: localizationService.currentMeasurementSystem == system ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(localizationService.currentMeasurementSystem == system ? PSColors.primaryGreen : PSColors.textTertiary)

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(system.displayName)
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textPrimary)
                }

                Spacer()
            }
            .padding(PSSpacing.md)
            .background(localizationService.currentMeasurementSystem == system ? PSColors.green50 : PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
    }

    // MARK: - Date Format Section

    private var dateFormatSection: some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text(String(localized: "Date Format"))
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                VStack(spacing: PSSpacing.sm) {
                    ForEach(DateFormatStyle.allCases, id: \.self) { style in
                        dateFormatButton(for: style)
                    }
                }

                // Example dates preview
                previewBox(
                    title: String(localized: "Today's Date"),
                    lines: DateFormatStyle.allCases.map { style in
                        "\(style.displayName): \(style.format(date: Date()))"
                    }
                )
            }
        }
        .scaleEffect(appearAnimation ? 1 : 0.95)
        .opacity(appearAnimation ? 1 : 0)
    }

    private func dateFormatButton(for style: DateFormatStyle) -> some View {
        Button(action: {
            withAnimation(PSMotion.springBouncy) {
                localizationService.currentDateFormat = style
            }
        }) {
            HStack(spacing: PSSpacing.md) {
                Image(systemName: localizationService.currentDateFormat == style ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(localizationService.currentDateFormat == style ? PSColors.primaryGreen : PSColors.textTertiary)

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(style.displayName)
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textPrimary)
                    Text(style.format(date: Date()))
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()
            }
            .padding(PSSpacing.md)
            .background(localizationService.currentDateFormat == style ? PSColors.green50 : PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
    }

    // MARK: - Temperature Unit Section

    private var temperatureUnitSection: some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text(String(localized: "Temperature Unit"))
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                VStack(spacing: PSSpacing.sm) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        temperatureUnitButton(for: unit)
                    }
                }

                // Preview at 20°C
                previewBox(
                    title: String(localized: "Room Temperature (20°C)"),
                    lines: TemperatureUnit.allCases.map { unit in
                        let temp = 20.0
                        let celsius = localizationService.currentTemperatureUnit == .celsius ? temp : temp
                        let fahrenheit = (celsius * 9 / 5) + 32
                        return unit == .celsius ? "Celsius: 20°C" : "Fahrenheit: \(String(format: "%.0f", fahrenheit))°F"
                    }
                )
            }
        }
        .scaleEffect(appearAnimation ? 1 : 0.95)
        .opacity(appearAnimation ? 1 : 0)
    }

    private func temperatureUnitButton(for unit: TemperatureUnit) -> some View {
        Button(action: {
            withAnimation(PSMotion.springBouncy) {
                localizationService.currentTemperatureUnit = unit
            }
        }) {
            HStack(spacing: PSSpacing.md) {
                Image(systemName: localizationService.currentTemperatureUnit == unit ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(localizationService.currentTemperatureUnit == unit ? PSColors.primaryGreen : PSColors.textTertiary)

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(unit.displayName)
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textPrimary)
                }

                Spacer()
            }
            .padding(PSSpacing.md)
            .background(localizationService.currentTemperatureUnit == unit ? PSColors.green50 : PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
    }

    // MARK: - Currency Section

    private var currencySection: some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text(String(localized: "Currency"))
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                HStack(spacing: PSSpacing.md) {
                    Text(String(localized: "Current:"))
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)

                    Text(localizationService.currentCurrencyCode)
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textPrimary)

                    Spacer()
                }
                .padding(PSSpacing.md)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                // Preview
                previewBox(
                    title: String(localized: "Example Amount"),
                    lines: [
                        localizationService.formatCurrency(99.99, currencyCode: localizationService.currentCurrencyCode)
                    ]
                )
            }
        }
        .scaleEffect(appearAnimation ? 1 : 0.95)
        .opacity(appearAnimation ? 1 : 0)
    }

    // MARK: - Cultural Preferences Section

    private var culturalPreferencesSection: some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                HStack {
                    Text(String(localized: "Cultural Food Preferences"))
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    Spacer()

                    if !selectedCulturalRegions.isEmpty {
                        PSBadge(
                            text: String(localized: "\(selectedCulturalRegions.count) selected"),
                            variant: .fresh
                        )
                    }
                }

                Text(String(localized: "Select your food cultures to get region-specific shelf life recommendations"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

                // Regional chips
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    ForEach(CulturalRegion.allCases.chunked(into: 2), id: \.self) { regionPair in
                        HStack(spacing: PSSpacing.md) {
                            ForEach(regionPair, id: \.self) { region in
                                PSFilterChip(
                                    title: "\(region.flagEmoji) \(region.displayName)",
                                    isSelected: selectedCulturalRegions.contains(region)
                                ) {
                                    withAnimation(PSMotion.springBouncy) {
                                        if selectedCulturalRegions.contains(region) {
                                            selectedCulturalRegions.remove(region)
                                        } else {
                                            selectedCulturalRegions.insert(region)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }

                if !selectedCulturalRegions.isEmpty {
                    Divider()
                        .padding(.vertical, PSSpacing.sm)

                    // Show food items from selected regions
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        Text(String(localized: "Foods from Selected Regions"))
                            .font(PSTypography.caption1Medium)
                            .foregroundStyle(PSColors.textSecondary)

                        VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                            ForEach(selectedCulturalRegions.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { region in
                                HStack(spacing: PSSpacing.xxs) {
                                    let foods = CulturalFoodDatabase.shared.itemsForRegion(region)
                                    ForEach(foods.prefix(3), id: \.id) { food in
                                        PSBadge(text: food.name, variant: .default)
                                    }
                                    if foods.count > 3 {
                                        PSBadge(text: "+\(foods.count - 3)", variant: .default)
                                    }
                                }
                            }
                        }
                    }
                    .padding(PSSpacing.md)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                }
            }
        }
        .scaleEffect(appearAnimation ? 1 : 0.95)
        .opacity(appearAnimation ? 1 : 0)
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        PSButton(
            title: String(localized: "Reset to Defaults"),
            style: .secondary,
            action: {
                withAnimation(PSMotion.springBouncy) {
                    localizationService.resetToDefaults()
                    selectedCulturalRegions.removeAll()
                }
            }
        )
        .scaleEffect(appearAnimation ? 1 : 0.95)
        .opacity(appearAnimation ? 1 : 0)
    }

    // MARK: - Helper Views

    private func previewBox(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {
            Text(title)
                .font(PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PSSpacing.md)
        .background(PSColors.emeraldSurface)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }
}



// MARK: - Preview

#Preview {
    LocalizationSettingsView()
        .environment(LocalizationService.shared)
}
