# Freshli Project Complete Wiring Audit
**Date:** April 10, 2026  
**Target:** Swift 6.3, iOS SDK 26.4

---

## 🔍 CRITICAL MISSING FILES - MUST CREATE

### 1. App Entry Point
- ❌ **`FreshliApp.swift`** - Main @main App struct with environment setup

### 2. Design System (PS = Pantry Saver Design System)
- ❌ **`PSColors.swift`** - Color palette
- ❌ **`PSSpacing.swift`** - Spacing/radius constants
- ❌ **`PSLayout.swift`** - Layout utilities & adaptive sizing
- ❌ **`PSMotion.swift`** - Animation curves
- ❌ **`FLMotion.swift`** - Freshli-specific animations
- ❌ **`PSHaptics.swift`** - Haptic feedback

### 3. Services & Managers
- ❌ **`ImpactService.swift`** - Impact statistics calculation
- ❌ **`RecipeService.swift`** - Recipe suggestions
- ❌ **`NotificationService.swift`** - Local notifications
- ❌ **`SpotlightService.swift`** - Spotlight indexing
- ❌ **`NetworkMonitor.swift`** - Network connectivity
- ❌ **`OfflineSyncQueue.swift`** - Offline sync queue
- ❌ **`FreshliHapticManager.swift`** - Advanced haptics
- ❌ **`PSLogger.swift`** - Structured logging

### 4. Views
- ❌ **`RecipesView.swift`** - Recipes tab
- ❌ **`CommunityView.swift`** - Community tab
- ❌ **`ProfileView.swift`** - Profile tab
- ❌ **`AddItemView.swift`** - Add item sheet
- ❌ **`FreshliDetailView.swift`** - Item detail
- ❌ **`WeeklyWrapView.swift`** - Weekly recap

### 5. Supporting Types
- ❌ **`CelebrationType.swift`** - Celebration event types
- ❌ **`PreviewSampleData.swift`** - Preview data
- ❌ **`AppSupabase.swift`** - Supabase client configuration
- ❌ **`AppleSignInCoordinator.swift`** - Apple Sign In handler

### 6. Extensions & Utilities
- ❌ **`Date+Extensions.swift`** - Date helpers (daysFromNow, expiryDisplayText)
- ❌ **`View+Extensions.swift`** - SwiftUI view modifiers
- ❌ **`Color+Extensions.swift`** - Color hex initializer

### 7. UI Components
- ❌ **`PSShimmerView.swift`** - Loading shimmer
- ❌ **`PSEmptyState.swift`** - Empty state view
- ❌ **`PressableButtonStyle.swift`** - Button style

---

## 🐛 BUGS FOUND IN EXISTING FILES

### HomeView.swift
**Issue:** Optional AuthManager (inconsistent with AppTabView fix)
```swift
// Line 18 - Should be non-optional
@Environment(AuthManager.self) private var authManager: AuthManager?
```
**Fix:** Remove optional

---

## 📋 WIRING CHECKLIST

### App Structure
- [ ] Main App struct with environment injection
- [ ] Model container setup
- [ ] Environment objects properly initialized
- [ ] Navigation stack configured

### Tab Navigation
- [x] AppTabView structure ✅
- [ ] All 5 tab views implemented
- [ ] Tab switching works
- [ ] Navigation between views

### Data Layer
- [x] SwiftData models defined ✅
- [ ] Services wired to model context
- [ ] Sync service configured
- [ ] Offline queue working

### UI/UX
- [ ] Design system constants
- [ ] Animations and transitions
- [ ] Haptic feedback
- [ ] Accessibility support

### Features
- [ ] Add/Edit/Delete items
- [ ] Expiry tracking
- [ ] Recipe suggestions
- [ ] Community sharing
- [ ] Impact tracking
- [ ] Celebrations
- [ ] Weekly recap
- [ ] Search functionality
- [ ] Notifications
- [ ] Spotlight integration

---

## 🎯 IMPLEMENTATION PRIORITY

### Phase 1: Critical Infrastructure (MUST HAVE)
1. ✅ Design System (PSColors, PSSpacing, PSLayout, PSMotion)
2. ✅ App Entry Point (FreshliApp.swift)
3. ✅ Core Services (ImpactService, RecipeService)
4. ✅ Missing View Stubs
5. ✅ Extensions (Date, View, Color)

### Phase 2: Feature Completion
1. Notification Service
2. Spotlight Integration
3. Network Monitor
4. Offline Sync Queue
5. Haptic Manager

### Phase 3: Polish
1. Empty states
2. Loading states
3. Error handling
4. Accessibility
5. Localization

---

## 🚀 NEXT STEPS

1. Create all Phase 1 files
2. Wire up environment in FreshliApp
3. Implement missing views
4. Test in simulator
5. Fix any runtime issues
6. Complete Phase 2 & 3

