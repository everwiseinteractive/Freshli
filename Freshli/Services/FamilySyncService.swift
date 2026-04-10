import Foundation
import CloudKit
import Observation

// MARK: - FamilyMember Model

struct FamilyMember: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var role: FamilyRole
    let joinDate: Date
    var cloudKitRecordName: String?

    enum FamilyRole: String, Codable, Sendable {
        case admin
        case member

        var displayName: String {
            switch self {
            case .admin: return "Admin"
            case .member: return "Member"
            }
        }
    }

    init(id: UUID = UUID(), name: String, role: FamilyRole = .member, joinDate: Date = Date(), cloudKitRecordName: String? = nil) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.role = role
        self.joinDate = joinDate
        self.cloudKitRecordName = cloudKitRecordName
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        !name.isEmpty && name.count <= 50
    }
}

// MARK: - FamilyGroup Model

struct FamilyGroup: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var members: [FamilyMember]
    var sharedPantryEnabled: Bool
    let createdDate: Date
    var zoneID: String?
    var shareRecordName: String?

    init(
        id: UUID = UUID(),
        name: String,
        members: [FamilyMember] = [],
        sharedPantryEnabled: Bool = false,
        createdDate: Date = Date(),
        zoneID: String? = nil,
        shareRecordName: String? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.members = members
        self.sharedPantryEnabled = sharedPantryEnabled
        self.createdDate = createdDate
        self.zoneID = zoneID
        self.shareRecordName = shareRecordName
    }
    
    // MARK: - Validation
    
    static let maxMembers = 20
    static let minNameLength = 1
    static let maxNameLength = 100
    
    var isValid: Bool {
        !name.isEmpty && 
        name.count >= Self.minNameLength && 
        name.count <= Self.maxNameLength &&
        members.count <= Self.maxMembers &&
        members.allSatisfy { $0.isValid }
    }
    
    var hasAdmin: Bool {
        members.contains { $0.role == .admin }
    }
}

// MARK: - Sync Status

enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case synced
    case error(FamilySyncError)

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let error):
            return "Error: \(error.userMessage)"
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

// MARK: - Family Sync Errors

enum FamilySyncError: Error, Sendable, Equatable {
    // Validation Errors
    case invalidFamilyName
    case invalidMemberName
    case familyFull
    case duplicateMember
    case noFamilyToLeave
    case notFamilyOwner
    
    // CloudKit Errors
    case cloudKitNotAvailable
    case iCloudNotSignedIn
    case iCloudRestricted
    case networkUnavailable
    case quotaExceeded
    case zoneNotFound
    case shareNotFound
    case permissionDenied
    
    // General Errors
    case missingMetadata
    case operationFailed(String)
    case unknown
    
    var userMessage: String {
        switch self {
        case .invalidFamilyName:
            return "Please enter a valid family name (1-100 characters)"
        case .invalidMemberName:
            return "Please enter a valid member name (1-50 characters)"
        case .familyFull:
            return "Family is full (maximum \(FamilyGroup.maxMembers) members)"
        case .duplicateMember:
            return "This member already exists"
        case .noFamilyToLeave:
            return "You're not in a family"
        case .notFamilyOwner:
            return "Only the family owner can perform this action"
        case .cloudKitNotAvailable:
            return "iCloud sync is unavailable. Please try again later."
        case .iCloudNotSignedIn:
            return "Please sign in to iCloud in Settings"
        case .iCloudRestricted:
            return "iCloud access is restricted"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .quotaExceeded:
            return "iCloud storage is full"
        case .zoneNotFound:
            return "Family data not found"
        case .shareNotFound:
            return "Family invitation not found"
        case .permissionDenied:
            return "Permission denied"
        case .missingMetadata:
            return "Family data is incomplete"
        case .operationFailed(let detail):
            return detail
        case .unknown:
            return "An unexpected error occurred"
        }
    }
    
    var shouldRetry: Bool {
        switch self {
        case .networkUnavailable, .cloudKitNotAvailable:
            return true
        default:
            return false
        }
    }
    
    static func from(_ error: Error) -> FamilySyncError {
        if let syncError = error as? FamilySyncError {
            return syncError
        }
        
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return .iCloudNotSignedIn
            case .networkUnavailable, .networkFailure:
                return .networkUnavailable
            case .quotaExceeded:
                return .quotaExceeded
            case .zoneNotFound:
                return .zoneNotFound
            case .permissionFailure:
                return .permissionDenied
            case .unknownItem:
                return .shareNotFound
                
            case .serverRecordChanged:
                return .operationFailed("The record was modified elsewhere. Please try again.")
            case .limitExceeded:
                return .operationFailed("Request limit exceeded. Please try again shortly.")
            case .partialFailure:
                return .operationFailed("Some items failed to sync. Please retry.")
            case .serviceUnavailable, .requestRateLimited:
                return .cloudKitNotAvailable
            case .zoneBusy:
                return .cloudKitNotAvailable
                
            default:
                return .operationFailed(ckError.localizedDescription)
            }
        }
        
        return .unknown
    }
}

// MARK: - FamilySyncService

@Observable
@MainActor
final class FamilySyncService {
    private let familyGroupKey = "freshli_family_group"
    private let inviteCodeKey = "freshli_invite_code"
    private let currentMemberRecordKey = "freshli_current_member_record"
    private let familyZoneName = "FreshliFamily"
    private let logger = PSLogger(category: .sync)

    // CloudKit container
    private let container = CKContainer.default()
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }

    // State
    var currentFamily: FamilyGroup? {
        didSet {
            saveFamily()
        }
    }

    var inviteURL: URL? {
        didSet {
            if let url = inviteURL {
                UserDefaults.standard.set(url.absoluteString, forKey: inviteCodeKey)
            }
        }
    }
    
    var currentMemberRecordName: String? {
        didSet {
            if let name = currentMemberRecordName {
                UserDefaults.standard.set(name, forKey: currentMemberRecordKey)
            } else {
                UserDefaults.standard.removeObject(forKey: currentMemberRecordKey)
            }
        }
    }

    var syncStatus: SyncStatus = .idle {
        didSet {
            logger.info("Sync status changed to: \(syncStatus.displayText)")
        }
    }

    var isFamilyOwner: Bool {
        guard let family = currentFamily else { return false }
        return family.members.contains { $0.role == .admin }
    }
    
    private var lastPantrySyncAt: Date?

    init() {
        loadFamily()
        loadInviteURL()
        loadCurrentMemberRecordName()
        Task {
            await setupCloudKitSubscriptions()
        }
    }

    // MARK: - Computed Properties

    var members: [FamilyMember] {
        currentFamily?.members ?? []
    }

    var memberCount: Int {
        members.count
    }

    // MARK: - Family Management

    func createFamily(name: String, adminName: String = "You") async throws {
        logger.info("Creating family: \(name)")
        
        guard syncStatus != .syncing else {
            logger.warning("Another sync operation is in progress; createFamily aborted")
            endSyncIdle()
            return
        }
        
        // Pre-flight validation
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAdminName = adminName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty,
              trimmedName.count >= FamilyGroup.minNameLength,
              trimmedName.count <= FamilyGroup.maxNameLength else {
            let error = FamilySyncError.invalidFamilyName
            endSyncFailure(error)
            throw error
        }
        
        guard !trimmedAdminName.isEmpty,
              trimmedAdminName.count <= 50 else {
            let error = FamilySyncError.invalidMemberName
            endSyncFailure(error)
            throw error
        }
        
        // Check iCloud availability before attempting operation
        do {
            try await verifyCloudKitAvailability()
        } catch let error as FamilySyncError {
            endSyncFailure(error)
            throw error
        }
        
        beginSync()
        
        // Store original state for rollback
        let originalFamily = currentFamily
        let originalInviteURL = inviteURL
        
        do {
            // Create family group locally with validated data
            let adminMember = FamilyMember(name: trimmedAdminName, role: .admin)
            let family = FamilyGroup(name: trimmedName, members: [adminMember], sharedPantryEnabled: false)
            
            guard family.isValid else {
                throw FamilySyncError.operationFailed("Invalid family configuration")
            }

            // Create CloudKit zone with retry logic
            let zoneID = CKRecordZone.ID(zoneName: familyZoneName, ownerName: CKCurrentUserDefaultName)
            let zone = CKRecordZone(zoneID: zoneID)

            try await withRetry(maxAttempts: 3) {
                try await self.privateDatabase.save(zone)
            }
            logger.info("Created CloudKit zone: \(zoneID)")

            // Create root record for the family
            let familyRecordID = CKRecord.ID(recordName: family.id.uuidString, zoneID: zoneID)
            let familyRecord = CKRecord(recordType: "FamilyGroup", recordID: familyRecordID)
            familyRecord["name"] = trimmedName as CKRecordValue
            familyRecord["createdDate"] = family.createdDate as CKRecordValue
            familyRecord["sharedPantryEnabled"] = (family.sharedPantryEnabled ? 1 : 0) as CKRecordValue
            
            try await withRetry(maxAttempts: 3) {
                try await self.privateDatabase.save(familyRecord)
            }
            logger.info("Created family root record")

            // Create shareable CKShare with proper configuration
            let shareRecord = CKShare(rootRecord: familyRecord)
            shareRecord[CKShare.SystemFieldKey.title] = trimmedName as CKRecordValue
            shareRecord.publicPermission = .none // Security: require explicit invite acceptance
            shareRecord[CKShare.SystemFieldKey.shareType] = "com.freshli.family" as CKRecordValue

            let (savedFamilyRecord, savedShare) = try await withRetry(maxAttempts: 3) {
                try await self.privateDatabase.modifyRecords(
                    saving: [familyRecord, shareRecord],
                    deleting: [],
                    savePolicy: .allKeys,
                    atomically: true
                )
            }
            logger.info("Created CKShare for family: \(family.id)")

            // Generate invite URL with safety
            guard let share = savedShare.first as? CKShare,
                  let shareURL = share.url else {
                throw FamilySyncError.operationFailed("Failed to generate share URL")
            }

            // Optimistically update state
            var updatedFamily = family
            updatedFamily.zoneID = zoneID.zoneName
            updatedFamily.shareRecordName = share.recordID.recordName
            currentFamily = updatedFamily
            inviteURL = shareURL
            currentMemberRecordName = adminMember.id.uuidString

            endSyncSuccess()
            PSHaptics.shared.success()
            
            logger.info("Successfully created family: \(trimmedName)")
            
        } catch {
            // Rollback on failure
            currentFamily = originalFamily
            inviteURL = originalInviteURL
            
            let syncError = FamilySyncError.from(error)
            logger.error("Failed to create family: \(syncError.userMessage)")
            endSyncFailure(syncError)
            PSHaptics.shared.error()
            throw syncError
        }
    }

    func joinFamily(shareURL: URL, memberName: String) async throws {
        logger.info("Joining family with share URL")
        
        guard syncStatus != .syncing else {
            logger.warning("Another sync operation is in progress; joinFamily aborted")
            endSyncIdle()
            return
        }
        
        // Validation
        let trimmedName = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 50 else {
            let error = FamilySyncError.invalidMemberName
            endSyncFailure(error)
            throw error
        }
        
        // Check iCloud availability
        do {
            try await verifyCloudKitAvailability()
        } catch let error as FamilySyncError {
            endSyncFailure(error)
            throw error
        }
        
        beginSync()
        
        // Store original state for rollback
        let originalFamily = currentFamily

        do {
            // Fetch share metadata with timeout protection
            let metadata = try await withTimeout(seconds: 15) {
                try await self.fetchShareMetadata(from: shareURL)
            }
            
            guard let metadata = metadata else {
                throw FamilySyncError.shareNotFound
            }

            // Accept the share
            _ = try await withRetry(maxAttempts: 3) {
                try await self.container.accept(metadata)
            }
            logger.info("Accepted share from URL")

            let shareZoneID = metadata.share.recordID.zoneID

            // Check if family is full before adding member
            let existingMembers = try await fetchMembers(from: shareZoneID)
            guard existingMembers.count < FamilyGroup.maxMembers else {
                throw FamilySyncError.familyFull
            }
            
            // Check for duplicate member names
            let duplicateName = existingMembers.contains { 
                $0.name.lowercased() == trimmedName.lowercased() 
            }
            guard !duplicateName else {
                throw FamilySyncError.duplicateMember
            }

            // Create member record in the shared zone
            let member = FamilyMember(name: trimmedName, role: .member)
            let memberRecord = CKRecord(
                recordType: "FamilyMember", 
                recordID: CKRecord.ID(recordName: member.id.uuidString, zoneID: shareZoneID)
            )
            memberRecord["name"] = member.name as CKRecordValue
            memberRecord["role"] = member.role.rawValue as CKRecordValue
            memberRecord["joinDate"] = member.joinDate as CKRecordValue

            _ = try await withRetry(maxAttempts: 3) {
                try await self.privateDatabase.save(memberRecord)
            }
            logger.info("Added member to family: \(member.name)")
            currentMemberRecordName = member.id.uuidString

            // Fetch updated family data
            try await fetchFamily(from: shareZoneID)

            endSyncSuccess()
            PSHaptics.shared.success()
            
            logger.info("Successfully joined family")
            
        } catch {
            // Rollback on failure
            currentFamily = originalFamily
            
            let syncError = FamilySyncError.from(error)
            logger.error("Failed to join family: \(syncError.userMessage)")
            endSyncFailure(syncError)
            PSHaptics.shared.error()
            throw syncError
        }
    }

    func leaveFamily() async throws {
        logger.info("Leaving family")
        
        guard syncStatus != .syncing else {
            logger.warning("Another sync operation is in progress; leaveFamily aborted")
            endSyncIdle()
            return
        }
        
        guard let family = currentFamily else {
            let error = FamilySyncError.noFamilyToLeave
            endSyncFailure(error)
            throw error
        }
        
        beginSync()
        
        // Store original state for rollback
        let originalFamily = currentFamily
        let originalInviteURL = inviteURL

        do {
            // Remove member record from shared zone (not the zone itself)
            if let zoneIDName = family.zoneID {
                let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)

                if let recordName = currentMemberRecordName {
                    let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
                    _ = try await withRetry(maxAttempts: 3) {
                        try await self.privateDatabase.deleteRecord(withID: recordID)
                    }
                    logger.info("Removed current user's member record: \(recordName)")
                } else {
                    // Fallback: attempt best-effort deletion by matching name
                    let members = try await fetchMembers(from: zoneID)
                    if let currentUserMember = members.first(where: { $0.role == .member }) {
                        if let fallbackRecordName = currentUserMember.cloudKitRecordName {
                            let recordID = CKRecord.ID(recordName: fallbackRecordName, zoneID: zoneID)
                            _ = try await withRetry(maxAttempts: 3) {
                                try await self.privateDatabase.deleteRecord(withID: recordID)
                            }
                            logger.info("Removed member record via fallback: \(fallbackRecordName)")
                        }
                    }
                }
            }

            // Clear local state
            currentFamily = nil
            inviteURL = nil
            currentMemberRecordName = nil
            endSyncSuccess()
            PSHaptics.shared.success()
            
            logger.info("Successfully left family")
            
        } catch {
            // Rollback on failure
            currentFamily = originalFamily
            inviteURL = originalInviteURL
            
            let syncError = FamilySyncError.from(error)
            logger.error("Failed to leave family: \(syncError.userMessage)")
            endSyncFailure(syncError)
            PSHaptics.shared.error()
            throw syncError
        }
    }

    func removeMember(_ member: FamilyMember) async throws {
        logger.info("Removing member: \(member.name)")
        
        // Prevent removing admin member
        if member.role == .admin {
            let error = FamilySyncError.notFamilyOwner
            endSyncFailure(error)
            throw error
        }
        
        guard isFamilyOwner else {
            let error = FamilySyncError.notFamilyOwner
            endSyncFailure(error)
            throw error
        }
        
        beginSync()
        
        // Store original state for rollback
        let originalFamily = currentFamily

        do {
            guard let family = currentFamily,
                  let zoneIDName = family.zoneID,
                  let recordName = member.cloudKitRecordName else {
                throw FamilySyncError.missingMetadata
            }

            let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
            let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

            _ = try await withRetry(maxAttempts: 3) {
                try await self.privateDatabase.deleteRecord(withID: recordID)
            }
            logger.info("Deleted member record: \(recordName)")

            // Update local family
            var updated = family
            updated.members.removeAll { $0.id == member.id }
            currentFamily = updated

            endSyncSuccess()
            PSHaptics.shared.success()
            
            logger.info("Successfully removed member: \(member.name)")
            
        } catch {
            // Rollback on failure
            currentFamily = originalFamily
            
            let syncError = FamilySyncError.from(error)
            logger.error("Failed to remove member: \(syncError.userMessage)")
            endSyncFailure(syncError)
            PSHaptics.shared.error()
            throw syncError
        }
    }

    func fetchMembers() async throws -> [FamilyMember] {
        logger.info("Fetching family members")
        guard let family = currentFamily, let zoneIDName = family.zoneID else {
            return []
        }

        do {
            let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
            return try await fetchMembers(from: zoneID)
        } catch {
            let syncError = FamilySyncError.from(error)
            logger.error("Failed to fetch members: \(syncError.userMessage)")
            return []
        }
    }
    
    // MARK: - Private helper for fetching members from a specific zone
    
    private func fetchMembers(from zoneID: CKRecordZone.ID) async throws -> [FamilyMember] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "FamilyMember", predicate: predicate)

        let (matchResults, _) = try await withRetry(maxAttempts: 3) {
            try await self.privateDatabase.records(matching: query, inZoneWith: zoneID)
        }
        
        var members: [FamilyMember] = []

        for (_, result) in matchResults {
            if let record = try? result.get(),
               let member = parseMemberRecord(record, zoneID: zoneID) {
                members.append(member)
            }
        }

        logger.info("Fetched \(members.count) members")
        return members
    }
    
    // MARK: - Refresh
    func refreshFamilyIfNeeded() async {
        guard let family = currentFamily, let zoneIDName = family.zoneID else { return }
        do {
            let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
            try await fetchFamily(from: zoneID)
        } catch {
            logger.warning("Refresh failed: \(error.localizedDescription)")
        }
    }

    func toggleSharedPantry() async throws {
        logger.info("Toggling shared pantry")
        
        guard syncStatus != .syncing else {
            logger.warning("Another sync operation is in progress; toggleSharedPantry aborted")
            endSyncIdle()
            return
        }
        
        guard var family = currentFamily else { 
            throw FamilySyncError.noFamilyToLeave 
        }
        
        guard isFamilyOwner else {
            let error = FamilySyncError.notFamilyOwner
            endSyncFailure(error)
            throw error
        }

        beginSync()
        
        // Store original state for rollback
        let originalValue = family.sharedPantryEnabled
        
        do {
            family.sharedPantryEnabled.toggle()
            currentFamily = family
            
            // Persist to CloudKit if we have zone info
            if let zoneIDName = family.zoneID {
                let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
                let familyRecordID = CKRecord.ID(recordName: family.id.uuidString, zoneID: zoneID)
                
                // Fetch existing record and update
                if let record = try? await privateDatabase.record(for: familyRecordID) {
                    record["sharedPantryEnabled"] = (family.sharedPantryEnabled ? 1 : 0) as CKRecordValue
                    _ = try await withRetry(maxAttempts: 3) {
                        try await self.privateDatabase.save(record)
                    }
                    logger.info("Updated shared pantry setting in CloudKit")
                }
            }
            
            endSyncSuccess()
            PSHaptics.shared.success()
            
            logger.info("Toggled shared pantry to: \(family.sharedPantryEnabled)")
            
        } catch {
            // Rollback on failure
            if var revertFamily = currentFamily {
                revertFamily.sharedPantryEnabled = originalValue
                currentFamily = revertFamily
            }
            
            let syncError = FamilySyncError.from(error)
            logger.error("Failed to toggle shared pantry: \(syncError.userMessage)")
            endSyncFailure(syncError)
            PSHaptics.shared.error()
            throw syncError
        }
    }

    func syncPantryItems(_ items: [FreshliItem]) async throws {
        logger.info("Syncing \(items.count) pantry items")
        guard let family = currentFamily, family.sharedPantryEnabled else {
            logger.warning("Shared pantry not enabled")
            endSyncIdle()
            return
        }

        guard syncStatus != .syncing else {
            logger.warning("Sync already in progress; skipping request")
            endSyncIdle()
            return
        }
        
        if let last = lastPantrySyncAt, Date().timeIntervalSince(last) < 0.25 {
            logger.debug("Debounced pantry sync request")
            endSyncIdle()
            return
        }
        lastPantrySyncAt = Date()

        beginSync()
        
        do {
            guard let zoneIDName = family.zoneID else {
                throw FamilySyncError.missingMetadata
            }

            let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
            var records: [CKRecord] = []

            for item in items {
                let record = CKRecord(
                    recordType: "FreshliItem", 
                    recordID: CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
                )
                record["name"] = item.name as CKRecordValue
                record["category"] = item.categoryRaw as CKRecordValue
                record["storageLocation"] = item.storageLocationRaw as CKRecordValue
                record["quantity"] = item.quantity as CKRecordValue
                record["unit"] = item.unitRaw as CKRecordValue
                record["expiryDate"] = item.expiryDate as CKRecordValue
                record["dateAdded"] = item.dateAdded as CKRecordValue
                record["notes"] = (item.notes ?? "") as CKRecordValue
                record["isActive"] = (item.isActive ? 1 : 0) as CKRecordValue

                records.append(record)
            }

            // Batch save with retry and proper error handling
            let batchSize = 400 // CloudKit limit
            let batches = stride(from: 0, to: records.count, by: batchSize).map {
                Array(records[$0..<min($0 + batchSize, records.count)])
            }
            
            for (index, batch) in batches.enumerated() {
                logger.info("Syncing batch \(index + 1)/\(batches.count)")
                
                _ = try await withRetry(maxAttempts: 3) {
                    try await self.privateDatabase.modifyRecords(
                        saving: batch,
                        deleting: [],
                        savePolicy: .changedKeys,
                        atomically: false
                    )
                }
            }

            endSyncSuccess()
            PSHaptics.shared.success()
            
            logger.info("Successfully synced \(items.count) items")
            
        } catch {
            let syncError = FamilySyncError.from(error)
            logger.error("Failed to sync pantry items: \(syncError.userMessage)")
            endSyncFailure(syncError)
            PSHaptics.shared.error()
            throw syncError
        }
    }

    // MARK: - Helper Methods
    
    /// Fetch share metadata with proper error handling
    private func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata? {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.perShareMetadataResultBlock = { shareURL, result in
                switch result {
                case .success(let metadata):
                    continuation.resume(returning: metadata)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            operation.qualityOfService = .userInitiated
            container.add(operation)
        }
    }

    private func generateShareURL(for share: CKShare) async throws -> URL {
        // CKShare.url is set by CloudKit after saving the share record
        guard let url = share.url else {
            throw FamilySyncError.operationFailed("Share URL not available yet. Please try again.")
        }
        return url
    }

    private func fetchFamily(from zoneID: CKRecordZone.ID) async throws {
        logger.info("Fetching family from zone: \(zoneID)")

        do {
            let members = try await fetchMembers(from: zoneID)

            if var family = currentFamily {
                family.members = members
                currentFamily = family
            }

            logger.info("Updated family with \(members.count) members")
        } catch {
            logger.error("Failed to fetch family: \(error.localizedDescription)")
            throw error
        }
    }

    private func parseMemberRecord(_ record: CKRecord, zoneID: CKRecordZone.ID) -> FamilyMember? {
        guard let name = record["name"] as? String,
              let roleString = record["role"] as? String,
              let role = FamilyMember.FamilyRole(rawValue: roleString),
              let joinDate = record["joinDate"] as? Date else {
            logger.warning("Failed to parse member record - missing fields")
            return nil
        }

        guard let uuid = UUID(uuidString: record.recordID.recordName) else {
            logger.warning("Failed to parse member record - invalid UUID")
            return nil
        }

        return FamilyMember(
            id: uuid,
            name: name,
            role: role,
            joinDate: joinDate,
            cloudKitRecordName: record.recordID.recordName
        )
    }
    
    // MARK: - CloudKit Availability & Error Handling
    
    /// Verify CloudKit is available and user is signed in
    private func verifyCloudKitAvailability() async throws {
        let accountStatus = try await container.accountStatus()
        
        switch accountStatus {
        case .available:
            logger.debug("iCloud account available")
            
        case .noAccount:
            logger.error("No iCloud account signed in")
            throw FamilySyncError.iCloudNotSignedIn
            
        case .restricted:
            logger.error("iCloud access restricted")
            throw FamilySyncError.iCloudRestricted
            
        case .couldNotDetermine:
            logger.error("Could not determine iCloud status")
            throw FamilySyncError.cloudKitNotAvailable
            
        case .temporarilyUnavailable:
            logger.error("iCloud temporarily unavailable")
            throw FamilySyncError.cloudKitNotAvailable
            
        @unknown default:
            logger.error("Unknown iCloud status")
            throw FamilySyncError.unknown
        }
    }
    
    /// Retry helper for network operations
    private func withRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let syncError = FamilySyncError.from(error)
                
                // Don't retry if error is not retryable
                guard syncError.shouldRetry else {
                    throw syncError
                }
                
                // Don't delay on last attempt
                if attempt < maxAttempts {
                    logger.warning("Retry attempt \(attempt)/\(maxAttempts) after error: \(syncError.userMessage)")
                    try await Task.sleep(nanoseconds: UInt64(delay * Double(attempt) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? FamilySyncError.unknown
    }
    
    /// Timeout wrapper for operations that might hang
    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw FamilySyncError.operationFailed("Operation timed out after \(seconds) seconds")
            }
            
            // Return first completed result and cancel others
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

// MARK: - Sync Status Helpers
    private func beginSync() { syncStatus = .syncing }
    private func endSyncSuccess() { syncStatus = .synced }
    private func endSyncFailure(_ error: FamilySyncError) { syncStatus = .error(error) }
    private func endSyncIdle() { syncStatus = .idle }

    private func setupCloudKitSubscriptions() async {
        logger.info("Setting up CloudKit subscriptions")

        do {
            try await verifyCloudKitAvailability()
            
            // Set up database change subscription for real-time updates
            // This allows the app to receive notifications when family data changes
            
        } catch let error as FamilySyncError {
            logger.error("CloudKit setup failed: \(error.userMessage)")
            endSyncFailure(error)
        } catch {
            let syncError = FamilySyncError.from(error)
            logger.error("CloudKit setup failed: \(syncError.userMessage)")
            endSyncFailure(syncError)
        }
    }

    // MARK: - Persistence
    
    /// Thread-safe persistence using MainActor isolation
    private func saveFamily() {
        guard let family = currentFamily else {
            UserDefaults.standard.removeObject(forKey: familyGroupKey)
            logger.debug("Cleared family from UserDefaults")
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(family)
            UserDefaults.standard.set(encoded, forKey: familyGroupKey)
            logger.debug("Saved family to UserDefaults")
        } catch {
            logger.error("Failed to encode family: \(error.localizedDescription)")
        }
    }

    private func loadFamily() {
        guard let data = UserDefaults.standard.data(forKey: familyGroupKey) else {
            logger.debug("No saved family found")
            return
        }
        
        do {
            let family = try JSONDecoder().decode(FamilyGroup.self, from: data)
            
            // Validate loaded data
            guard family.isValid else {
                logger.error("Loaded family data is invalid, clearing")
                UserDefaults.standard.removeObject(forKey: familyGroupKey)
                return
            }
            
            currentFamily = family
            logger.debug("Loaded family from UserDefaults: \(family.name)")
        } catch {
            logger.error("Failed to decode family: \(error.localizedDescription)")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: familyGroupKey)
        }
    }

    private func loadInviteURL() {
        guard let urlString = UserDefaults.standard.string(forKey: inviteCodeKey),
              let url = URL(string: urlString) else {
            logger.debug("No saved invite URL found")
            return
        }
        
        inviteURL = url
        logger.debug("Loaded invite URL")
    }
    
    private func loadCurrentMemberRecordName() {
        if let name = UserDefaults.standard.string(forKey: currentMemberRecordKey) {
            currentMemberRecordName = name
            logger.debug("Loaded current member record name")
        } else {
            logger.debug("No saved current member record name found")
        }
    }
}

