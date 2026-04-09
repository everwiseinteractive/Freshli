# Freshli Rename Checklist

## Quick Search & Replace Guide

Use Xcode's Find and Replace (⌘⇧F) to update remaining files:

### 1. Design System Components

| Old Name | New Name | Files to Check |
|----------|----------|----------------|
| `PSSpacing` | `FLSpacing` | All view files, PSSpacing.swift |
| `PSLayout` | `FLLayout` | All view files, PSLayout.swift |
| `PSHaptics` | `FLHaptics` | Service files, PSHaptics.swift |
| `PSButton` | `FLButton` | All view files, PSButton.swift |
| `PSShimmerView` | `FLShimmerView` | Loading views, PSShimmerView.swift |
| `PSColors` | `FLColors` | Already done ✅ |
| `PSMotion` | `FLMotion` | Already done ✅ |
| `PSToast` | `FLToast` | Already done ✅ |

### 2. File Renames (in Xcode Navigator)

Right-click each file in Xcode and select "Rename":

- [ ] PSColors.swift → FLColors.swift
- [ ] PSMotion.swift → FLMotion.swift
- [ ] PSToast.swift → FLToast.swift
- [ ] PSSpacing.swift → FLSpacing.swift
- [ ] PSLayout.swift → FLLayout.swift
- [ ] PSHaptics.swift → FLHaptics.swift
- [ ] PSButton.swift → FLButton.swift
- [ ] PSShimmerView.swift → FLShimmerView.swift

### 3. Project Settings

#### In Xcode Project Settings:
1. Select your project in the navigator
2. Select the target
3. Update these fields:
   - [ ] **Display Name**: Change to "Freshli"
   - [ ] **Bundle Identifier**: Change from `com.*.PantryShare` to `com.*.Freshli`

#### In Info.plist:
- [ ] `CFBundleName` → "Freshli"
- [ ] `CFBundleDisplayName` → "Freshli"

### 4. Search for Remaining "PantryShare" References

Use Xcode's Find in Project (⌘⇧F):

```
Search: PantryShare
Replace with: Freshli
```

Check these locations:
- [ ] Comments
- [ ] Documentation strings
- [ ] User-facing strings (Text views)
- [ ] README files
- [ ] Configuration files
- [ ] API base URLs
- [ ] Firebase/Cloud config

### 5. Search for Remaining "pantryshare" References (lowercase)

```
Search: pantryshare
Replace with: freshli
```

Check:
- [ ] URLs
- [ ] Database collection names
- [ ] API endpoints
- [ ] File paths

### 6. Asset Catalog

Check for any asset names containing "PantryShare":
- [ ] App Icon names
- [ ] Image set names
- [ ] Color set names

### 7. Widget/Extension Targets

If you have widgets or app extensions:
- [ ] Widget bundle identifiers
- [ ] Widget display names
- [ ] Extension bundle identifiers

### 8. SwiftData/CloudKit

If using CloudKit:
- [ ] Container identifier
- [ ] Record type names (if using "PantryShare" prefix)

### 9. Build Schemes

In Xcode → Product → Scheme → Manage Schemes:
- [ ] Rename "PantryShare" scheme to "Freshli"

### 10. Unit/UI Tests

- [ ] Test bundle names
- [ ] Test case names
- [ ] Test data

### 11. Documentation

- [ ] README.md
- [ ] CHANGELOG.md
- [ ] LICENSE (if it mentions app name)
- [ ] Code comments
- [ ] API documentation

### 12. Version Control

After renaming:
```bash
# Commit all changes
git add .
git commit -m "Rebrand from PantryShare to Freshli"

# Optional: Add tag
git tag -a v1.0-freshli -m "Rebranded to Freshli"
```

### 13. External Services

Update app name in:
- [ ] Apple Developer Portal
- [ ] App Store Connect (when submitting)
- [ ] Firebase Console
- [ ] Analytics platforms
- [ ] Crash reporting services
- [ ] Push notification services
- [ ] Any third-party SDKs

## Verification Steps

After completing all renames:

1. **Clean Build Folder**: ⌘⇧K
2. **Build Project**: ⌘B
3. **Run All Tests**: ⌘U
4. **Search for "PS"**: Make sure only intentional uses remain (e.g., system frameworks)
5. **Search for "PantryShare"**: Should find 0 results
6. **Check App Display**: Install on device/simulator and verify app name shows as "Freshli"
7. **Check Bundle ID**: Verify in Settings or About screen

## Common Issues

### If build fails:
- Check for missed PS* references
- Verify all file renames in project navigator
- Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`

### If app crashes:
- Check CloudKit container identifier matches new bundle ID
- Verify keychain access groups (if used)
- Check URL scheme registrations

### If widgets don't work:
- Update widget extension bundle identifiers
- Rebuild widget target separately
- Clear widget cache on device

## Notes

- Keep old "PS" prefix in git history for reference
- Update copyright notices if they mention "PantryShare"
- Consider keeping old bundle ID active for a transition period if already on App Store
- Update any marketing materials, screenshots, app store listing
