# FamilySyncService Usage Guide
## Production-Ready CloudKit Family Sync

### Quick Start

```swift
import SwiftUI

@main
struct FreshliApp: App {
    @State private var familySync = FamilySyncService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(familySync)
        }
    }
}
```

---

## Creating a Family

```swift
@Environment(FamilySyncService.self) private var familySync

func createFamily() {
    Task {
        do {
            try await familySync.createFamily(
                name: "Smith Family",
                adminName: "John Smith"
            )
            
            // Success! Share the invite URL
            if let inviteURL = familySync.inviteURL {
                shareInvite(inviteURL)
            }
        } catch let error as FamilySyncError {
            // Handle specific errors
            showError(error.userMessage)
        } catch {
            showError("Unexpected error occurred")
        }
    }
}
```

### Error Handling Best Practices

```swift
// ✅ GOOD: Handle specific errors
catch let error as FamilySyncError {
    switch error {
    case .iCloudNotSignedIn:
        showSettingsPrompt()
    case .invalidFamilyName:
        focusNameField()
    case .networkUnavailable:
        showRetryButton()
    default:
        showGenericError(error.userMessage)
    }
}

// ❌ BAD: Swallow all errors
catch {
    // User has no idea what went wrong
}
```

---

## Joining a Family

```swift
func joinFamily(url: URL) {
    Task {
        do {
            try await familySync.joinFamily(
                shareURL: url,
                memberName: "Jane Smith"
            )
            
            // Success! Navigate to family view
            showFamilyView()
        } catch let error as FamilySyncError {
            showError(error.userMessage)
        }
    }
}
```

---

## Observing Sync Status

```swift
struct FamilyView: View {
    @Environment(FamilySyncService.self) private var familySync
    
    var body: some View {
        VStack {
            // Show sync status
            HStack {
                Image(systemName: syncStatusIcon)
                Text(familySync.syncStatus.displayText)
                    .foregroundStyle(syncStatusColor)
            }
            
            // Family members list
            ForEach(familySync.members) { member in
                MemberRow(member: member)
            }
        }
    }
    
    var syncStatusIcon: String {
        switch familySync.syncStatus {
        case .idle: return "cloud"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "cloud.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    var syncStatusColor: Color {
        familySync.syncStatus.isError ? .red : .secondary
    }
}
```

---

## Syncing Pantry Items

```swift
func syncPantry() async {
    let activeItems = freshliService.fetchActiveItems()
    
    guard !activeItems.isEmpty else { return }
    
    do {
        try await familySync.syncPantryItems(activeItems)
        print("✅ Synced \(activeItems.count) items")
    } catch {
        print("❌ Sync failed: \(error)")
    }
}
```

### Automatic Sync on Changes

```swift
@Observable
class PantryViewModel {
    let familySync: FamilySyncService
    let freshliService: FreshliService
    
    func addItem(_ item: FreshliItem) {
        freshliService.addItem(item)
        
        // Auto-sync if shared pantry is enabled
        if familySync.currentFamily?.sharedPantryEnabled == true {
            Task {
                try? await familySync.syncPantryItems([item])
            }
        }
    }
}
```

---

## Member Management

### Removing a Member (Admin Only)

```swift
func removeMember(_ member: FamilyMember) {
    guard familySync.isFamilyOwner else {
        showError("Only the family owner can remove members")
        return
    }
    
    Task {
        do {
            try await familySync.removeMember(member)
        } catch let error as FamilySyncError {
            showError(error.userMessage)
        }
    }
}
```

### Leaving a Family

```swift
func leaveFamily() {
    Task {
        do {
            try await familySync.leaveFamily()
            // Navigate back to home
            dismiss()
        } catch let error as FamilySyncError {
            showError(error.userMessage)
        }
    }
}
```

---

## Validation Helpers

### Pre-Validate User Input

```swift
struct CreateFamilyView: View {
    @State private var familyName = ""
    @State private var adminName = ""
    @Environment(FamilySyncService.self) private var familySync
    
    var isValid: Bool {
        let trimmedFamily = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAdmin = adminName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmedFamily.count >= FamilyGroup.minNameLength &&
               trimmedFamily.count <= FamilyGroup.maxNameLength &&
               !trimmedAdmin.isEmpty &&
               trimmedAdmin.count <= 50
    }
    
    var body: some View {
        Form {
            TextField("Family Name", text: $familyName)
            TextField("Your Name", text: $adminName)
            
            Button("Create Family") {
                createFamily()
            }
            .disabled(!isValid)
        }
    }
}
```

---

## Testing Scenarios

### Unit Testing

```swift
import Testing
@testable import Freshli

@Test("Family creation validates name")
func testFamilyValidation() {
    let family = FamilyGroup(name: "   ")
    #expect(!family.isValid)
    
    let validFamily = FamilyGroup(name: "Smith Family")
    #expect(validFamily.isValid)
}
```

### Integration Testing

```swift
@MainActor
@Test("Creating family updates state")
func testFamilyCreation() async throws {
    let service = FamilySyncService()
    
    // Mock CloudKit in test environment
    try await service.createFamily(name: "Test", adminName: "Tester")
    
    #expect(service.currentFamily != nil)
    #expect(service.currentFamily?.name == "Test")
    #expect(service.syncStatus == .synced)
}
```

---

## Performance Tips

### 1. Batch Sync Operations

```swift
// ✅ GOOD: Sync in batches
let items = fetchActiveItems()
try await familySync.syncPantryItems(items)

// ❌ BAD: Sync one at a time
for item in items {
    try await familySync.syncPantryItems([item]) // Multiple network calls!
}
```

### 2. Debounce Frequent Updates

```swift
class PantryViewModel {
    private var syncTask: Task<Void, Never>?
    
    func scheduleSync() {
        syncTask?.cancel()
        
        syncTask = Task {
            try? await Task.sleep(for: .seconds(2))
            let items = fetchActiveItems()
            try? await familySync.syncPantryItems(items)
        }
    }
}
```

### 3. Check Sync State Before Operations

```swift
// Prevent duplicate syncs
guard familySync.syncStatus != .syncing else {
    print("Sync already in progress")
    return
}
```

---

## Error Recovery Patterns

### Automatic Retry with User Feedback

```swift
func syncWithRetry(maxAttempts: Int = 3) async {
    for attempt in 1...maxAttempts {
        do {
            try await familySync.syncPantryItems(items)
            return // Success!
        } catch let error as FamilySyncError {
            if error.shouldRetry && attempt < maxAttempts {
                showToast("Retrying... (\(attempt)/\(maxAttempts))")
                try? await Task.sleep(for: .seconds(2))
            } else {
                showError(error.userMessage)
                return
            }
        }
    }
}
```

### Graceful Degradation

```swift
func ensureSharedPantry() async {
    do {
        try await familySync.toggleSharedPantry()
    } catch {
        // Fallback: local-only mode
        showWarning("Shared pantry unavailable, using local mode")
        enableLocalMode()
    }
}
```

---

## Common Mistakes to Avoid

### ❌ Not Handling Errors

```swift
// DON'T DO THIS
Task {
    try await familySync.createFamily(name: name, adminName: admin)
    // What if it fails?
}
```

### ✅ Proper Error Handling

```swift
Task {
    do {
        try await familySync.createFamily(name: name, adminName: admin)
        showSuccess()
    } catch let error as FamilySyncError {
        showError(error.userMessage)
    } catch {
        showError("An unexpected error occurred")
    }
}
```

---

### ❌ Blocking Main Thread

```swift
// DON'T DO THIS - Will freeze UI
func createFamily() {
    // Synchronous call on main thread!
    try! familySync.createFamily(name: name, adminName: admin)
}
```

### ✅ Async/Await Pattern

```swift
func createFamily() {
    Task {
        try await familySync.createFamily(name: name, adminName: admin)
    }
}
```

---

### ❌ Ignoring Validation

```swift
// DON'T DO THIS
try await familySync.createFamily(name: "", adminName: "")
// Will throw validation error
```

### ✅ Pre-Validate Input

```swift
guard !name.isEmpty else {
    showError("Please enter a family name")
    return
}

try await familySync.createFamily(name: name, adminName: admin)
```

---

## Debugging Tips

### Enable Verbose Logging

```swift
// PSLogger already logs all operations
// Check console for:
// [Sync] Creating family: Smith Family
// [Sync] Created CloudKit zone: FreshliFamily
// [Sync] Successfully created family: Smith Family
```

### Inspect Sync Status

```swift
// Add a debug view
struct DebugSyncView: View {
    @Environment(FamilySyncService.self) private var sync
    
    var body: some View {
        Form {
            Section("Status") {
                Text("Status: \(sync.syncStatus.displayText)")
                Text("Family: \(sync.currentFamily?.name ?? "None")")
                Text("Members: \(sync.memberCount)")
                Text("Is Owner: \(sync.isFamilyOwner.description)")
            }
            
            Section("Actions") {
                Button("Test Sync") {
                    Task {
                        try? await sync.fetchMembers()
                    }
                }
            }
        }
    }
}
```

---

## Production Checklist

Before deploying:

- ✅ CloudKit container configured
- ✅ Record types created (FamilyGroup, FamilyMember, FreshliItem)
- ✅ Custom zone created (FreshliFamily)
- ✅ Security roles defined
- ✅ Error handling tested
- ✅ Network timeout scenarios tested
- ✅ iCloud sign-out scenarios tested
- ✅ Offline mode tested
- ✅ Logging verified
- ✅ User feedback messages reviewed

---

## Support & Troubleshooting

### Common Issues

**Issue:** "iCloud not signed in" error  
**Solution:** Check Settings > [User Name] > iCloud

**Issue:** "Permission denied" error  
**Solution:** Verify CloudKit security roles are configured

**Issue:** Sync hangs indefinitely  
**Solution:** Timeout protection is built-in (15s max)

**Issue:** Members not appearing  
**Solution:** Check network connectivity and CloudKit dashboard

---

**Last Updated:** April 10, 2026  
**Version:** 1.0 (Production Ready)
