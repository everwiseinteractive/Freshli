import Testing
import Foundation
import CloudKit
@testable import Freshli

// MARK: - FamilySyncService Test Suite
// Comprehensive test coverage for production-ready family sync

@Suite("Family Sync Service Tests")
@MainActor
struct FamilySyncServiceTests {
    
    // MARK: - Model Validation Tests
    
    @Suite("FamilyMember Validation")
    struct FamilyMemberValidationTests {
        
        @Test("Valid member with proper name")
        func validMember() {
            let member = FamilyMember(name: "John Doe", role: .member)
            #expect(member.isValid)
            #expect(member.name == "John Doe")
        }
        
        @Test("Member with whitespace is trimmed")
        func memberWithWhitespace() {
            let member = FamilyMember(name: "  Jane Smith  ", role: .admin)
            #expect(member.name == "Jane Smith")
            #expect(member.isValid)
        }
        
        @Test("Member with empty name after trim is invalid")
        func emptyNameMember() {
            let member = FamilyMember(name: "   ", role: .member)
            #expect(!member.isValid)
        }
        
        @Test("Member name exceeding 50 characters is invalid")
        func longNameMember() {
            let longName = String(repeating: "a", count: 51)
            let member = FamilyMember(name: longName, role: .member)
            #expect(!member.isValid)
        }
        
        @Test("Member with exactly 50 characters is valid")
        func maxLengthNameMember() {
            let maxName = String(repeating: "a", count: 50)
            let member = FamilyMember(name: maxName, role: .member)
            #expect(member.isValid)
        }
    }
    
    // MARK: - FamilyGroup Validation Tests
    
    @Suite("FamilyGroup Validation")
    struct FamilyGroupValidationTests {
        
        @Test("Valid family group")
        func validFamily() {
            let admin = FamilyMember(name: "Admin", role: .admin)
            let family = FamilyGroup(name: "Smith Family", members: [admin])
            #expect(family.isValid)
            #expect(family.hasAdmin)
        }
        
        @Test("Family name is trimmed")
        func familyNameTrimming() {
            let family = FamilyGroup(name: "  Test Family  ")
            #expect(family.name == "Test Family")
        }
        
        @Test("Empty family name is invalid")
        func emptyFamilyName() {
            let family = FamilyGroup(name: "   ")
            #expect(!family.isValid)
        }
        
        @Test("Family name exceeding max length is invalid")
        func longFamilyName() {
            let longName = String(repeating: "a", count: 101)
            let family = FamilyGroup(name: longName)
            #expect(!family.isValid)
        }
        
        @Test("Family with too many members is invalid")
        func tooManyMembers() {
            var members: [FamilyMember] = []
            for i in 0...20 {
                members.append(FamilyMember(name: "Member \(i)", role: .member))
            }
            let family = FamilyGroup(name: "Large Family", members: members)
            #expect(!family.isValid)
            #expect(members.count > FamilyGroup.maxMembers)
        }
        
        @Test("Family with exactly max members is valid")
        func maxMembers() {
            var members: [FamilyMember] = []
            for i in 0..<FamilyGroup.maxMembers {
                members.append(FamilyMember(name: "Member \(i)", role: i == 0 ? .admin : .member))
            }
            let family = FamilyGroup(name: "Family", members: members)
            #expect(family.isValid)
            #expect(members.count == FamilyGroup.maxMembers)
        }
        
        @Test("Family with invalid member is invalid")
        func invalidMember() {
            let invalidMember = FamilyMember(name: "", role: .member)
            let family = FamilyGroup(name: "Family", members: [invalidMember])
            #expect(!family.isValid)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Suite("FamilySyncError Handling")
    struct FamilySyncErrorTests {
        
        @Test("Error user messages are descriptive")
        func errorMessages() {
            #expect(FamilySyncError.invalidFamilyName.userMessage.contains("valid family name"))
            #expect(FamilySyncError.iCloudNotSignedIn.userMessage.contains("sign in"))
            #expect(FamilySyncError.familyFull.userMessage.contains("full"))
        }
        
        @Test("Network errors are retryable")
        func retryableErrors() {
            #expect(FamilySyncError.networkUnavailable.shouldRetry)
            #expect(FamilySyncError.cloudKitNotAvailable.shouldRetry)
        }
        
        @Test("Validation errors are not retryable")
        func nonRetryableErrors() {
            #expect(!FamilySyncError.invalidFamilyName.shouldRetry)
            #expect(!FamilySyncError.invalidMemberName.shouldRetry)
            #expect(!FamilySyncError.notFamilyOwner.shouldRetry)
        }
        
        @Test("CKError conversion to FamilySyncError")
        func ckErrorConversion() {
            let notAuthenticatedError = CKError(.notAuthenticated)
            let syncError = FamilySyncError.from(notAuthenticatedError)
            #expect(syncError == .iCloudNotSignedIn)
            
            let networkError = CKError(.networkUnavailable)
            let networkSyncError = FamilySyncError.from(networkError)
            #expect(networkSyncError == .networkUnavailable)
        }
    }
    
    // MARK: - Sync Status Tests
    
    @Suite("Sync Status Display")
    struct SyncStatusTests {
        
        @Test("Status display texts")
        func statusDisplayText() {
            #expect(SyncStatus.idle.displayText == "Ready")
            #expect(SyncStatus.syncing.displayText == "Syncing...")
            #expect(SyncStatus.synced.displayText == "Synced")
        }
        
        @Test("Error status detection")
        func errorDetection() {
            let errorStatus = SyncStatus.error(.networkUnavailable)
            #expect(errorStatus.isError)
            #expect(!SyncStatus.idle.isError)
            #expect(!SyncStatus.synced.isError)
        }
        
        @Test("Error status includes message")
        func errorStatusMessage() {
            let error = FamilySyncError.iCloudNotSignedIn
            let status = SyncStatus.error(error)
            #expect(status.displayText.contains("Error"))
            #expect(status.displayText.contains(error.userMessage))
        }
    }
    
    // MARK: - Codable Tests
    
    @Suite("Model Persistence")
    struct CodableTests {
        
        @Test("FamilyMember encodes and decodes correctly")
        func memberCoding() throws {
            let member = FamilyMember(
                id: UUID(),
                name: "Test User",
                role: .admin,
                joinDate: Date(),
                cloudKitRecordName: "test-record"
            )
            
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            let data = try encoder.encode(member)
            let decoded = try decoder.decode(FamilyMember.self, from: data)
            
            #expect(decoded.id == member.id)
            #expect(decoded.name == member.name)
            #expect(decoded.role == member.role)
            #expect(decoded.cloudKitRecordName == member.cloudKitRecordName)
        }
        
        @Test("FamilyGroup encodes and decodes correctly")
        func familyCoding() throws {
            let admin = FamilyMember(name: "Admin", role: .admin)
            let family = FamilyGroup(
                id: UUID(),
                name: "Test Family",
                members: [admin],
                sharedPantryEnabled: true,
                createdDate: Date(),
                zoneID: "test-zone",
                shareRecordName: "test-share"
            )
            
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            let data = try encoder.encode(family)
            let decoded = try decoder.decode(FamilyGroup.self, from: data)
            
            #expect(decoded.id == family.id)
            #expect(decoded.name == family.name)
            #expect(decoded.members.count == family.members.count)
            #expect(decoded.sharedPantryEnabled == family.sharedPantryEnabled)
            #expect(decoded.zoneID == family.zoneID)
        }
    }
}

// MARK: - Integration Test Helpers

extension FamilySyncServiceTests {
    
    /// Mock family for testing
    static func createMockFamily(memberCount: Int = 3) -> FamilyGroup {
        var members: [FamilyMember] = []
        members.append(FamilyMember(name: "Admin User", role: .admin))
        
        for i in 1..<memberCount {
            members.append(FamilyMember(name: "Member \(i)", role: .member))
        }
        
        return FamilyGroup(
            name: "Test Family",
            members: members,
            sharedPantryEnabled: true
        )
    }
}
