# 🚀 Freshli Quick Start Guide

## Run the App (3 Steps)

1. **Open Xcode**
   ```bash
   open Freshli.xcodeproj
   ```

2. **Select Simulator**
   - Choose "iPhone 15 Pro" or "iPhone 15"
   - iOS 18.4+ required

3. **Build & Run**
   - Press `⌘R` or click the Play button
   - App launches in ~2 seconds

---

## 🎯 First Launch Experience

### What You'll See:
1. **Home Tab (Default)**
   - Green curved header with greeting
   - "Expiring Soon" carousel (horizontal scroll)
   - "Your Impact" stats card
   - Recipe suggestion
   - Community swap CTA

2. **Pantry Tab** 
   - 8 pre-loaded sample items
   - Search bar at top
   - Category filter chips
   - Tap + button (bottom right) to add items

3. **Recipes Tab**
   - Matched recipes based on pantry
   - Recipe cards with match percentage
   - Tap to see full recipe details

4. **Community Tab**
   - Empty state (no listings yet)
   - "Share Food" button

5. **Profile Tab**
   - Impact statistics
   - Settings options
   - Sign out button

---

## 📂 Key Files to Know

### Starting Points:
- **FreshliApp.swift** - App entry point, environment setup
- **AppTabView.swift** - Tab navigation controller
- **ContentView.swift** - Root view

### Add/Edit Features:
- **AddItemView.swift** - Form to add pantry items
- **FreshliDetailView.swift** - Item detail & actions

### Core Business Logic:
- **FreshliService.swift** - Pantry CRUD operations
- **ImpactService.swift** - Statistics calculation
- **RecipeService.swift** - Recipe matching algorithm

### Design System:
- **PSColors.swift** - Color palette
- **PSSpacing.swift** - Spacing constants
- **PSLayout.swift** - Layout helpers
- **PSMotion.swift** - Animations

---

## 🎨 Design System Usage

### Colors:
```swift
PSColors.primaryGreen        // Brand green
PSColors.headerGreen         // Header background
PSColors.expiredRed          // Expired items
PSColors.freshGreen          // Fresh items
PSColors.surfaceCard         // Card backgrounds
PSColors.textPrimary         // Primary text
```

### Spacing:
```swift
PSSpacing.xs  // 4pt
PSSpacing.sm  // 8pt
PSSpacing.md  // 12pt
PSSpacing.lg  // 16pt
PSSpacing.xl  // 20pt
```

### Animations:
```swift
PSMotion.freshliCurve   // Spring animation
PSMotion.smooth         // Ease in-out
PSMotion.snappy         // Quick response
```

---

## 🔧 Common Tasks

### Add a New Pantry Item:
1. Tap Pantry tab
2. Tap + button (bottom right)
3. Fill form (name, category, expiry date)
4. Tap "Add to Pantry"
5. Celebration triggers on first item!

### View Item Details:
1. Tap any item card
2. See full details
3. Mark as consumed or delete

### Test Recipes:
1. Add items with names like "Tomatoes", "Pasta", "Chicken"
2. Go to Recipes tab
3. See matched recipes

### Test Celebrations:
1. Add your first item → "Welcome to Freshli!" celebration
2. Mark item as consumed → "First Food Saved!" celebration
3. Check console for celebration logs

---

## 🐛 Troubleshooting

### Build Fails:
- Ensure Xcode 15.4+ installed
- Clean build folder: `⌘⇧K`
- Rebuild: `⌘B`

### App Crashes on Launch:
- Check console for errors
- Verify ModelContainer setup in FreshliApp.swift
- Try: Product → Clean Build Folder

### Items Not Appearing:
- Check FreshliService.seedSampleDataIfNeeded()
- Verify SwiftData is saving (check logs)

### Animations Laggy:
- Run on device, not simulator (slower performance)
- Or use newer simulator (iPhone 15 Pro)

---

## 📊 Testing Features

### Manual Test Checklist:
- [ ] Add item via + button
- [ ] Edit item details
- [ ] Mark item as consumed
- [ ] Delete item
- [ ] Search for items
- [ ] Filter by category
- [ ] Switch between tabs
- [ ] View recipe details
- [ ] Check profile stats
- [ ] Test dark mode (Settings → Appearance)

---

## 🎓 Code Patterns

### Adding a New View:
```swift
import SwiftUI

struct MyNewView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Text("Hello, Freshli!")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(PSColors.textPrimary)
    }
}

#Preview {
    MyNewView()
}
```

### Adding a New Service:
```swift
@MainActor
final class MyService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func doSomething() {
        // Your logic here
    }
}
```

### Accessing Environment:
```swift
@Environment(\.modelContext) private var modelContext
@Environment(AuthManager.self) private var authManager
@Environment(CelebrationManager.self) private var celebrationManager
```

---

## 🔑 Important Notes

### Supabase:
Currently using **mock credentials**. Backend features show empty states until you add real credentials in `AppSupabase.swift`.

### Sample Data:
First launch loads 8 sample items automatically via `FreshliService.seedSampleDataIfNeeded()`.

### Persistence:
All data persists between launches via SwiftData. To reset:
- Delete app from simulator
- Reinstall (run again)

### Notifications:
Local notifications work but require system permission. Approve when prompted.

---

## 📱 Recommended Simulator

**iPhone 15 Pro**
- Best performance
- Latest features
- Dynamic Island support
- 60fps animations

Alternative: iPhone 14 Pro or iPhone SE (for compact testing)

---

## 🎯 Quick Wins

### Add Impact to Any Action:
```swift
PSHaptics.shared.success()  // Haptic feedback
```

### Log Important Events:
```swift
PSLogger.app.info("Something happened")
PSLogger.pantry.debug("Item added: \(item.name)")
```

### Show Empty State:
```swift
PSEmptyState(
    icon: "tray",
    title: "No Items",
    message: "Add your first item!",
    actionTitle: "Add Item",
    action: { showAddItem = true }
)
```

---

## 🚀 You're Ready!

Press `⌘R` and watch Freshli come to life! 🎉

Need help? Check the full documentation in:
- `COMPLETE_AUDIT_SUMMARY.md`
- `WIRING_COMPLETE.md`
- `AUDIT_FIXES.md`

Happy coding! 🍎
