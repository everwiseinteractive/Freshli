import SwiftUI

// MARK: - FL ↔ PS Compatibility Typealiases
// Bridges old PS-prefixed names and new FL-prefixed names so both compile.
// This allows incremental migration without touching every file at once.

// Components
typealias FLCard = PSCard
typealias FLCompactCard = PSCompactCard
typealias FLActionCard = PSActionCard
typealias FLButton = PSButton
typealias FLButtonStyle = PSButtonStyle
typealias FLButtonSize = PSButtonSize
typealias FLIconButton = PSIconButton
typealias FLShimmerView = PSShimmerView
typealias FLShimmerItemCard = PSShimmerItemCard
typealias FLShimmerPill = PSShimmerPill
typealias FLShimmerList = PSShimmerList
typealias FLShimmerStat = PSShimmerStat
typealias FLSearchBar = PSSearchBar
typealias FLEmptyState = PSEmptyState
typealias FLStatTile = PSStatTile
typealias FLStatTileRow = PSStatTileRow
typealias FLFilterChip = PSFilterChip
typealias FLBadge = PSBadge
typealias FLExpiryBadge = PSExpiryBadge
typealias FLBadgeVariant = PSBadgeVariant
typealias FLQuantityStepper = PSQuantityStepper
typealias FLProgressRing = PSProgressRing
typealias FLProgressRingLabeled = PSProgressRingLabeled
typealias FLSuccessCelebration = PSSuccessCelebration
typealias FLSegmentedControl = PSSegmentedControl
typealias FLBottomSheet = PSBottomSheet

// Tokens
typealias FLSpacing = PSSpacing
typealias FLLayout = PSLayout
typealias FLHaptics = PSHaptics
typealias FLTypography = PSTypography
typealias FLLogCategory = PSLogCategory
typealias FLLogger = PSLogger
