import Foundation
import SwiftUI

// Temporary shims to bridge PS -> FL rename during migration.
// Scope aliases inside a private namespace to avoid top-level redeclarations.

enum FLShimNamespace { }

// Card
extension FLShimNamespace { typealias Card = PSCard }
// Badge
extension FLShimNamespace { typealias Badge = PSBadge }
// Button
extension FLShimNamespace { typealias Button = PSButton }
// Spacing
extension FLShimNamespace { typealias Spacing = PSSpacing }
// Typography
extension FLShimNamespace { typealias Typography = PSTypography }
// Colors
extension FLShimNamespace { typealias Colors = PSColors }
// Haptics
extension FLShimNamespace { typealias Haptics = PSHaptics }

// Provide global typealiases only if FL* types are not already declared.
// Since Swift cannot conditionally check symbol existence, we minimize conflict by aliasing
// through the namespace. Update call sites to use FLShimNamespace.* if global FL* exists.

// As a temporary bridge, also expose global aliases with distinct names to avoid collision.
// Adjusted names: FLAliasCard, FLAliasBadge, etc. Update call sites if needed during transition.

typealias FLAliasCard = FLShimNamespace.Card
typealias FLAliasBadge = FLShimNamespace.Badge
typealias FLAliasButton = FLShimNamespace.Button
typealias FLAliasSpacing = FLShimNamespace.Spacing
typealias FLAliasTypography = FLShimNamespace.Typography
typealias FLAliasColors = FLShimNamespace.Colors
typealias FLAliasHaptics = FLShimNamespace.Haptics
