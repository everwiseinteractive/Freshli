# FamilySyncService Quick Reference Card

## 🚀 Common Operations

### Create Family
```swift
try await familySync.createFamily(name: "Smith Family", adminName: "John")
```

### Join Family  
```swift
try await familySync.joinFamily(shareURL: url, memberName: "Jane")
```

### Leave Family
```swift
try await familySync.leaveFamily()
```

### Remove Member (Admin Only)
```swift
try await familySync.removeMember(member)
```

### Sync Pantry Items
```swift
try await familySync.syncPantryItems(items)
```

### Toggle Shared Pantry
```swift
try await familySync.toggleSharedPantry()
```

### Fetch Members
```swift
let members = try await familySync.fetchMembers()
```

---

## 📊 Properties

### Observable State
```swift
currentFamily: FamilyGroup?       // Current family data
inviteURL: URL?                   // Share invitation URL
syncStatus: SyncStatus            // Current sync state
```

### Computed Properties
```swift
members: [FamilyMember]           // All family members
memberCount: Int                  // Number of members
isFamilyOwner: Bool               // Is current user admin?
```

---

## ⚠️ Error Handling

### All Errors are FamilySyncError
```swift
do {
    try await operation()
} catch let error as FamilySyncError {
    print(error.userMessage)      // User-friendly message
    print(error.shouldRetry)      // Can retry?
}
```

### Common Errors
```swift
.invalidFamilyName               // Name too short/long/empty
.invalidMemberName               // Member name invalid
.familyFull                      // Max 20 members reached
.duplicateMember                 // Member name exists
.iCloudNotSignedIn              // User needs to sign in
.networkUnavailable             // No internet connection
.notFamilyOwner                 // Admin-only operation
.noFamilyToLeave               // Not in a family
```

---

## ✅ Validation Rules

### Family Name
- Min: 1 character
- Max: 100 characters
- Auto-trimmed

### Member Name
- Min: 1 character  
- Max: 50 characters
- Auto-trimmed

### Family Size
- Max: 20 members

---

## 🎯 Built-in Features

### Automatic
- ✅ Input validation
- ✅ Retry (3 attempts)
- ✅ Timeout (15s)
- ✅ Rollback on failure
- ✅ Haptic feedback
- ✅ Logging

### Manual Check
```swift
// Validate before creating
let family = FamilyGroup(name: name)
guard family.isValid else { return }

// Check ownership
guard familySync.isFamilyOwner else { return }

// Check status
if familySync.syncStatus.isError {
    // Show error UI
}
```

---

## 🎨 UI Integration

### SwiftUI Environment
```swift
@Environment(FamilySyncService.self) private var familySync
```

### Observe Status
```swift
Text(familySync.syncStatus.displayText)
    .foregroundStyle(
        familySync.syncStatus.isError ? .red : .secondary
    )
```

### Show Members
```swift
ForEach(familySync.members) { member in
    Text(member.name)
    Text(member.role.displayName)
}
```

---

## 📱 Example View

```swift
struct FamilyView: View {
    @Environment(FamilySyncService.self) private var sync
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            Section("Members") {
                ForEach(sync.members) { member in
                    HStack {
                        Text(member.name)
                        Spacer()
                        Text(member.role.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Button("Leave Family") {
                    leaveFamily()
                }
                .foregroundStyle(.red)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    func leaveFamily() {
        Task {
            do {
                try await sync.leaveFamily()
            } catch let error as FamilySyncError {
                errorMessage = error.userMessage
                showError = true
            }
        }
    }
}
```

---

## 🧪 Testing

```swift
@Test("Creating valid family")
func testCreate() async throws {
    let service = FamilySyncService()
    try await service.createFamily(
        name: "Test Family",
        adminName: "Admin"
    )
    #expect(service.currentFamily != nil)
}

@Test("Invalid name throws error")
func testInvalidName() async {
    let service = FamilySyncService()
    await #expect(throws: FamilySyncError.invalidFamilyName) {
        try await service.createFamily(name: "", adminName: "Admin")
    }
}
```

---

## 🔧 Debugging

### Enable Console Logging
All operations automatically log via PSLogger:
```
[Sync] Creating family: Smith Family
[Sync] Created CloudKit zone: FreshliFamily
[Sync] Successfully created family: Smith Family
```

### Check Sync Status
```swift
print(familySync.syncStatus.displayText)
// "Ready" | "Syncing..." | "Synced" | "Error: ..."
```

---

## ⚡️ Performance Tips

### DO
✅ Batch sync operations
✅ Check status before retrying
✅ Use family.isValid before CloudKit calls

### DON'T
❌ Sync items one at a time
❌ Call sync during active sync
❌ Ignore validation errors

---

## 🔒 Security Notes

- Shares require explicit invite acceptance (not public)
- Only family owner can remove members
- Only family owner can toggle shared pantry
- All inputs are validated and sanitized

---

## 📚 Full Documentation

- **Usage Guide:** `FamilySyncService_Usage_Guide.md`
- **Audit Report:** `PRODUCTION_AUDIT_REPORT.md`
- **Migration Guide:** `FamilySyncService_Migration_Guide.md`
- **Test Suite:** `FamilySyncServiceTests.swift`

---

**Version:** 1.0 Production  
**Swift:** 6.3+  
**iOS:** 18+  
**Last Updated:** April 10, 2026
