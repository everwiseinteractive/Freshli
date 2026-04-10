# Migration Guide: FamilySyncService Updates
## Upgrading to Production-Ready Version

This guide helps you update existing code that uses FamilySyncService to work with the new production-ready, crash-proof implementation.

---

## Breaking Changes

### 1. Error Type Changed

**Before:**
```swift
enum SyncStatus {
    case error(String)
}
```

**After:**
```swift
enum SyncStatus {
    case error(FamilySyncError)
}
```

**Migration:**
```swift
// Old code
if case .error(let message) = syncStatus {
    print(message)
}

// New code
if case .error(let error) = syncStatus {
    print(error.userMessage)
}
```

---

### 2. Validation Required

**Before:**
```swift
try await familySync.createFamily(name: userInput, adminName: adminInput)
// Would crash or create invalid data
```

**After:**
```swift
// Input is automatically validated and throws FamilySyncError if invalid
do {
    try await familySync.createFamily(name: userInput, adminName: adminInput)
} catch FamilySyncError.invalidFamilyName {
    // Handle validation error
} catch {
    // Handle other errors
}
```

**Migration:**
```swift
// Add validation error handling
func createFamily() {
    Task {
        do {
            try await familySync.createFamily(
                name: familyName,
                adminName: adminName
            )
        } catch FamilySyncError.invalidFamilyName {
            showError("Please enter a valid family name (1-100 characters)")
        } catch FamilySyncError.invalidMemberName {
            showError("Please enter a valid name (1-50 characters)")
        } catch let error as FamilySyncError {
            showError(error.userMessage)
        } catch {
            showError("An unexpected error occurred")
        }
    }
}
```

---

### 3. Models Now Hashable

**Before:**
```swift
struct FamilyMember: Identifiable, Codable, Sendable {
    // ...
}
```

**After:**
```swift
struct FamilyMember: Identifiable, Codable, Sendable, Hashable {
    // ...
}
```

**Migration:**
If you were using custom comparison logic, you can now use `==` directly:

```swift
// Old code
members.contains { $0.id == searchedMember.id }

// New code (still works, but simpler)
members.contains(searchedMember)

// Or use Set for unique members
let uniqueMembers = Set(members)
```

---

### 4. New Validation Properties

**Before:**
```swift
// No validation available
let family = FamilyGroup(name: "")
// Could create invalid family
```

**After:**
```swift
let family = FamilyGroup(name: "")
if !family.isValid {
    print("Family validation failed")
}

// Check admin exists
if !family.hasAdmin {
    print("Family needs an admin")
}
```

**Migration:**
```swift
// Add validation checks before operations
func canCreateFamily() -> Bool {
    let testFamily = FamilyGroup(
        name: familyName,
        members: [FamilyMember(name: adminName, role: .admin)]
    )
    return testFamily.isValid
}
```

---

## New Features You Can Use

### 1. Retry Logic (Built-in)

**Before:**
```swift
// Had to implement retry yourself
func syncWithRetry() async {
    var attempts = 0
    while attempts < 3 {
        do {
            try await familySync.syncPantryItems(items)
            return
        } catch {
            attempts += 1
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
```

**After:**
```swift
// Retry is automatic for transient failures!
try await familySync.syncPantryItems(items)
// Automatically retries up to 3 times for network errors
```

---

### 2. Timeout Protection (Built-in)

**Before:**
```swift
// Operations could hang indefinitely
try await familySync.joinFamily(shareURL: url, memberName: name)
```

**After:**
```swift
// Automatically times out after 15 seconds
try await familySync.joinFamily(shareURL: url, memberName: name)
// No more indefinite hangs!
```

---

### 3. Optimistic Updates with Rollback

**Before:**
```swift
// State could become inconsistent
familySync.currentFamily?.sharedPantryEnabled = true
try await updateCloudKit()
// If CloudKit fails, local state is now wrong!
```

**After:**
```swift
// Automatic rollback on failure
try await familySync.toggleSharedPantry()
// If it fails, state is automatically reverted
```

---

### 4. Better Error Messages

**Before:**
```swift
catch {
    showError(error.localizedDescription)
    // "The operation couldn't be completed. (CKError 9)"
}
```

**After:**
```swift
catch let error as FamilySyncError {
    showError(error.userMessage)
    // "Network connection unavailable"
}
```

---

## Updated Error Handling Pattern

### Old Pattern ❌
```swift
func createFamily() {
    Task {
        do {
            try await familySync.createFamily(name: name, adminName: admin)
            showSuccess()
        } catch {
            showError("Failed to create family")
        }
    }
}
```

### New Pattern ✅
```swift
func createFamily() {
    Task {
        do {
            try await familySync.createFamily(name: name, adminName: admin)
            showSuccess()
        } catch FamilySyncError.iCloudNotSignedIn {
            // Specific action for iCloud issue
            showSettingsPrompt()
        } catch FamilySyncError.networkUnavailable {
            // Specific action for network issue
            showRetryButton()
        } catch let error as FamilySyncError where error.shouldRetry {
            // Handle retryable errors
            showRetryButton(error.userMessage)
        } catch let error as FamilySyncError {
            // Other sync errors
            showError(error.userMessage)
        } catch {
            // Unexpected errors
            showError("An unexpected error occurred")
            logger.error("Unexpected error: \(error)")
        }
    }
}
```

---

## View Updates

### Old View Code
```swift
struct FamilyView: View {
    @Environment(FamilySyncService.self) private var familySync
    
    var body: some View {
        VStack {
            if case .error(let message) = familySync.syncStatus {
                Text(message)
                    .foregroundColor(.red)
            }
        }
    }
}
```

### New View Code
```swift
struct FamilyView: View {
    @Environment(FamilySyncService.self) private var familySync
    
    var body: some View {
        VStack {
            // Better error handling
            if case .error(let error) = familySync.syncStatus {
                ErrorBanner(
                    message: error.userMessage,
                    canRetry: error.shouldRetry
                ) {
                    retryLastOperation()
                }
            }
        }
    }
}
```

---

## Testing Updates

### Old Test Pattern
```swift
@Test
func testFamilyCreation() async throws {
    let service = FamilySyncService()
    try await service.createFamily(name: "Test", adminName: "User")
    // Might crash on invalid input
}
```

### New Test Pattern
```swift
@Test("Valid family creation succeeds")
func testValidFamilyCreation() async throws {
    let service = FamilySyncService()
    try await service.createFamily(name: "Test Family", adminName: "Test User")
    #expect(service.currentFamily != nil)
    #expect(service.currentFamily?.isValid == true)
}

@Test("Invalid family name throws error")
func testInvalidFamilyName() async {
    let service = FamilySyncService()
    await #expect(throws: FamilySyncError.invalidFamilyName) {
        try await service.createFamily(name: "", adminName: "User")
    }
}
```

---

## UI Feedback Improvements

### Before
```swift
// Limited feedback
try await familySync.createFamily(name: name, adminName: admin)
```

### After
```swift
// Automatic haptic feedback on success/failure
try await familySync.createFamily(name: name, adminName: admin)
// Success: PSHaptics.shared.success() called automatically
// Failure: PSHaptics.shared.error() called automatically
```

---

## Performance Optimizations to Leverage

### 1. Batch Syncing
```swift
// Old: Sync items one at a time
for item in items {
    try await sync.syncPantryItems([item])
}

// New: Batch sync (automatically chunks into batches of 400)
try await sync.syncPantryItems(items)
```

### 2. Smart Validation
```swift
// Old: Let CloudKit reject invalid data
try await sync.createFamily(name: userInput, adminName: admin)

// New: Fail fast with local validation
let family = FamilyGroup(name: userInput, members: [admin])
guard family.isValid else {
    showError("Invalid family data")
    return
}
try await sync.createFamily(name: userInput, adminName: admin.name)
```

---

## Security Improvements

### Share Permissions

**Before:**
```swift
shareRecord.publicPermission = .readWrite
// Anyone with link could modify!
```

**After:**
```swift
shareRecord.publicPermission = .none
// Explicit invite acceptance required
```

### Authorization Checks

**New: Owner-only operations**
```swift
// Old: No check
try await familySync.removeMember(member)

// New: Automatic check
try await familySync.removeMember(member)
// Throws FamilySyncError.notFamilyOwner if not owner
```

**Recommended: UI-level check**
```swift
Button("Remove Member") {
    removeMember()
}
.disabled(!familySync.isFamilyOwner)
```

---

## Validation Constants

New validation limits you should be aware of:

```swift
FamilyGroup.maxMembers = 20
FamilyGroup.minNameLength = 1
FamilyGroup.maxNameLength = 100

// Member name max length: 50 characters

// Use these for UI validation
TextField("Family Name", text: $name)
    .onChange(of: name) { oldValue, newValue in
        if newValue.count > FamilyGroup.maxNameLength {
            name = String(newValue.prefix(FamilyGroup.maxNameLength))
        }
    }
```

---

## Deprecation Notices

### ⚠️ Force Unwrap Removed
If you were relying on this behavior:
```swift
// This would crash before
let url = try await generateShareURL(for: share) // Could return force-unwrapped URL

// Now throws proper error instead
let url = try await generateShareURL(for: share)
// Throws FamilySyncError.operationFailed if URL not available
```

---

## Step-by-Step Migration

### 1. Update Error Handling
```bash
# Search for old error handling
grep -r "case .error(let message)" .
```
Replace with:
```swift
case .error(let error) => error.userMessage
```

---

### 2. Add Validation Checks
Add validation before operations:
```swift
// At the top of create/join functions
guard !name.isEmpty, name.count <= 100 else {
    throw FamilySyncError.invalidFamilyName
}
```

---

### 3. Update Test Cases
Add tests for new error types:
```swift
@Test("Invalid input throws validation error")
func testValidation() async {
    await #expect(throws: FamilySyncError.self) {
        try await service.createFamily(name: "", adminName: "")
    }
}
```

---

### 4. Leverage New Features
Remove custom retry logic and use built-in:
```swift
// Delete custom retry functions
// Replace with simple call - retry is automatic!
try await service.syncPantryItems(items)
```

---

### 5. Update UI Feedback
Replace generic error alerts with specific ones:
```swift
switch error {
case .iCloudNotSignedIn:
    presentSettingsPrompt()
case .networkUnavailable:
    showRetryButton()
case .familyFull:
    showUpgradePrompt()
default:
    showGenericError(error.userMessage)
}
```

---

## Verification Checklist

After migration, verify:

- ✅ All error cases handled
- ✅ No force unwraps remaining
- ✅ Validation added for user inputs
- ✅ Tests updated for new error types
- ✅ UI shows user-friendly error messages
- ✅ Haptic feedback working
- ✅ Sync status properly observed
- ✅ No build warnings
- ✅ Swift 6 concurrency warnings resolved

---

## Support

If you encounter issues during migration:

1. Check the console for `PSLogger` messages
2. Review the `PRODUCTION_AUDIT_REPORT.md`
3. Consult the `FamilySyncService_Usage_Guide.md`
4. Test with the new `FamilySyncServiceTests.swift`

---

**Migration Version:** 1.0  
**Last Updated:** April 10, 2026  
**Compatibility:** Swift 6.3+, iOS 18+
