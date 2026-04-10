# ✅ CORRECT FILE STRUCTURE (After Deleting Duplicates)

## 📁 What Your Project Should Look Like

After you delete the duplicates, your Xcode project should have these files (and NOT the duplicates):

---

## ✅ KEEP THESE FILES

### App Entry
- ✅ FreshliApp.swift
- ✅ ContentView.swift
- ✅ AppTabView.swift

### Views
- ✅ HomeView.swift
- ✅ FreshliView.swift
- ✅ RecipesView.swift
- ✅ CommunityView.swift
- ✅ ProfileView.swift
- ✅ AddItemView.swift
- ✅ FreshliDetailView.swift
- ✅ WeeklyWrapView.swift

### Models
- ✅ FreshliItem.swift
- ✅ SharedListing.swift
- ✅ UserProfile.swift
- ✅ FoodCategory.swift
- ✅ StorageLocation.swift
- ✅ MeasurementUnit.swift
- ✅ ExpiryStatus.swift

### Services
- ✅ FreshliService.swift
- ✅ ImpactService.swift (NOT "ImpactService 2.swift")
- ✅ RecipeService.swift
- ✅ NotificationService.swift
- ✅ SpotlightService.swift (NOT "SpotlightService 2.swift")
- ✅ NetworkMonitor.swift
- ✅ OfflineSyncQueue.swift

### Managers
- ✅ AuthManager.swift
- ✅ SyncService.swift
- ✅ CelebrationManager.swift

### Design System
- ✅ PSColors.swift
- ✅ PSSpacing.swift
- ✅ PSLayout.swift
- ✅ PSMotion.swift
- ✅ PSHaptics.swift
- ✅ PSLogger.swift (ONLY ONE - delete duplicate if exists)
- ✅ PSEmptyState.swift
- ✅ PSShimmerView.swift
- ✅ PressableButtonStyle.swift

### Extensions
- ✅ Date+Extensions.swift
- ✅ View+Extensions.swift

### Backend & Data
- ✅ AppSupabase.swift
- ✅ SupabaseModels.swift
- ✅ AppleSignInHelper.swift (NOT "AppleSignInCoordinator.swift")
- ✅ PreviewHelpers.swift (NOT "PreviewSampleData.swift")

### Celebration
- ✅ CelebrationTypes.swift

---

## ❌ DELETE THESE FILES (Duplicates)

- ❌ SpotlightService 2.swift (has space + "2" in name)
- ❌ ImpactService 2.swift (has space + "2" in name)
- ❌ PreviewSampleData.swift (duplicate of PreviewHelpers.swift)
- ❌ AppleSignInCoordinator.swift (duplicate of AppleSignInHelper.swift)
- ❌ PSLogger.swift (if there are TWO, keep the one with `static let app`)

---

## 🔍 HOW TO VERIFY

### In Xcode:

1. **Search for "2.swift"** using ⌘⇧F
   - If any files show up like "Something 2.swift", DELETE them

2. **Search for duplicate type names:**
   - Press ⌘⇧O
   - Type "PreviewSampleData"
   - If you see it appear TWICE (in two different files), delete one

3. **Check Build Phases:**
   - Click project → Target → Build Phases
   - Expand "Compile Sources"
   - Make sure NO file appears twice in the list

---

## 📊 FILE COUNT

After cleanup, you should have approximately:
- **~50-55 .swift files** total
- **NO files with "2" in the name** (like "Something 2.swift")
- **NO duplicate type definitions**

---

## ✅ VERIFICATION

To verify everything is correct:

```bash
# In Terminal, navigate to your project folder
cd /path/to/Freshli

# List all swift files
find . -name "*.swift" | sort

# Check for files with "2" in name (should return nothing)
find . -name "*2.swift"
```

If the last command returns any files, those are duplicates - delete them!

---

## 🎯 FINAL CHECK

After deleting duplicates:

- [ ] Pressed ⌘⇧K (Clean)
- [ ] Pressed ⌘B (Build)
- [ ] Build succeeded with 0 errors
- [ ] No "ambiguous" error messages
- [ ] Ready to run (⌘R)

---

**Once you have this file structure, all 42 errors will be gone!** ✅
