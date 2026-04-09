import Foundation
import CloudKit
import Observation

// MARK: - FamilyMember Model

struct FamilyMember: Identifiable, Codable, Sendable {
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
        self.name = name
        self.role = role
        self.joinDate = joinDate
        self.cloudKitRecordName = cloudKitRecordName
    }
}

// MARK: - FamilyGroup Model

struct FamilyGroup: Identifiable, Codable, Sendable {
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
        self.name = name
        self.members = members
        self.sharedPantryEnabled = sharedPantryEnabled
        self.createdDate = createdDate
        self.zoneID = zoneID
        self.shareRecordName = shareRecordName
    }
}

// MARK: - Sync Status

enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case synced
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

// MARK: - FamilySyncService

@Observable
@MainActor
final class FamilySyncService {
    private let familyGroupKey = "freshli_family_group"
    private let inviteCodeKey = "freshli_invite_code"
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

    var syncStatus: SyncStatus = .idle {
        didSet {
            logger.info("Sync status changed to: \(syncStatus.displayText)")
        }
    }

    var isFamilyOwner: Bool {
        guard let family = currentFamily else { return false }
        return family.members.first?.role == .admin
    }

    init() {
        loadFamily()
        loadInviteURL()
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
        syncStatus = .syncing

        do {
            // Create family group locally
            let adminMember = FamilyMember(name: adminName, role: .admin)
            let family = FamilyGroup(name: name, members: [adminMember], sharedPantryEnabled: false)

            // Create CloudKit zone
            let zoneID = CKRecordZone.ID(zoneName: familyZoneName, ownerName: CKCurrentUserDefaultName)
            let zone = CKRecordZone(zoneID: zoneID)

            try await privateDatabase.save(zone)
            logger.info("Created CloudKit zone: \(zoneID)")

            // Create a shareable record for the zone
            let shareRecord = CKShare(rootRecord: CKRecord(recordType: "FamilyGroup", recordID: CKRecord.ID(recordName: family.id.uuidString, zoneID: zoneID)))
            shareRecord[CKShare.SystemFieldKey.title] = name as CKRecordValue
            shareRecord.publicPermission = .readWrite

            try await privateDatabase.save(shareRecord)
            logger.info("Created CKShare for family: \(family.id)")

            // Save family with CloudKit metadata
            var updatedFamily = family
            updatedFamily.zoneID = zoneID.zoneName
            updatedFamily.shareRecordName = shareRecord.recordID.recordName
            currentFamily = updatedFamily

            // Generate invite URL from share
            inviteURL = try await generateShareURL(for: shareRecord)

            syncStatus = .synced
            PSHaptics.shared.success()
        } catch {
            logger.error("Failed to create family: \(error.localizedDescription)")
            syncStatus = .error("Failed to create family")
            throw error
        }
    }

    func joinFamily(shareURL: URL, memberName: String) async throws {
        logger.info("Joining family with share URL")
        syncStatus = .syncing

        do {
            // Accept the share via metadata lookup
            let metadata = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Metadata, Error>) in
                let operation = CKFetchShareMetadataOperation(shareURLs: [shareURL])
                operation.perShareMetadataResultBlock = { _, result in
                    switch result {
                    case .success(let meta):
                        continuation.resume(returning: meta)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                container.add(operation)
            }

            try await container.accept(metadata)
            logger.info("Accepted share from URL")

            let shareZoneID = metadata.share.recordID.zoneID

            // Create member record in the shared zone
            let member = FamilyMember(name: memberName, role: .member)
            let memberRecord = CKRecord(recordType: "FamilyMember", recordID: CKRecord.ID(recordName: member.id.uuidString, zoneID: shareZoneID))
            memberRecord["name"] = member.name as CKRecordValue
            memberRecord["role"] = member.role.rawValue as CKRecordValue
            memberRecord["joinDate"] = member.joinDate as CKRecordValue

            try await privateDatabase.save(memberRecord)
            logger.info("Added member to family: \(member.name)")

            // Fetch updated family data
            try await fetchFamily(from: shareZoneID)

            syncStatus = .synced
            PSHaptics.shared.success()
        } catch {
            logger.error("Failed to join family: \(error.localizedDescription)")
            syncStatus = .error("Failed to join family")
            throw error
        }
    }

    func leaveFamily() async throws {
        logger.info("Leaving family")
        syncStatus = .syncing

        do {
            guard let family = currentFamily else {
                throw NSError(domain: "FamilySync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No family to leave"])
            }

            // Remove self from the shared zone
            if let zoneIDName = family.zoneID {
                let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
                let deleteOp = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [zoneID])
                deleteOp.qualityOfService = .userInitiated
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    deleteOp.modifyRecordZonesResultBlock = { result in
                        switch result {
                        case .success: continuation.resume()
                        case .failure(let err): continuation.resume(throwing: err)
                        }
                    }
                    self.privateDatabase.add(deleteOp)
                }
                logger.info("Removed zone: \(zoneID)")
            }

            currentFamily = nil
            inviteURL = nil
            syncStatus = .synced
            PSHaptics.shared.success()
        } catch {
            logger.error("Failed to leave family: \(error.localizedDescription)")
            syncStatus = .error("Failed to leave family")
            throw error
        }
    }

    func removeMember(_ member: FamilyMember) async throws {
        logger.info("Removing member: \(member.name)")
        syncStatus = .syncing

        do {
            guard let family = currentFamily,
                  let zoneIDName = family.zoneID,
                  let recordName = member.cloudKitRecordName else {
                throw NSError(domain: "FamilySync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing CloudKit metadata"])
            }

            let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
            let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

            let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
            deleteOp.qualityOfService = .userInitiated
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                deleteOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success: continuation.resume()
                    case .failure(let err): continuation.resume(throwing: err)
                    }
                }
                self.privateDatabase.add(deleteOp)
            }
            logger.info("Deleted member record: \(recordName)")

            // Update local family
            var updated = family
            updated.members.removeAll { $0.id == member.id }
            currentFamily = updated

            syncStatus = .synced
            PSHaptics.shared.success()
        } catch {
            logger.error("Failed to remove member: \(error.localizedDescription)")
            syncStatus = .error("Failed to remove member")
            throw error
        }
    }

    func fetchMembers() async throws -> [FamilyMember] {
        logger.info("Fetching family members")
        guard let family = currentFamily, let zoneIDName = family.zoneID else {
            return []
        }

        do {
            let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "FamilyMember", predicate: predicate)

            let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
            var members: [FamilyMember] = []

            for (_, result) in matchResults {
                if let record = try? result.get(),
                   let member = parseMemberRecord(record, zoneID: zoneID) {
                    members.append(member)
                }
            }

            logger.info("Fetched \(members.count) members")
            return members
        } catch {
            logger.error("Failed to fetch members: \(error.localizedDescription)")
            return []
        }
    }

    func toggleSharedPantry() async throws {
        logger.info("Toggling shared pantry")
        guard var family = currentFamily else { return }

        syncStatus = .syncing
        do {
            family.sharedPantryEnabled.toggle()
            currentFamily = family
            syncStatus = .synced
            PSHaptics.shared.success()
        } catch {
            logger.error("Failed to toggle shared pantry: \(error.localizedDescription)")
            syncStatus = .error("Failed to update setting")
            throw error
        }
    }

    func syncPantryItems(_ items: [FreshliItem]) async throws {
        logger.info("Syncing \(items.count) pantry items")
        guard let family = currentFamily, family.sharedPantryEnabled else {
            logger.warning("Shared pantry not enabled")
            return
        }

        syncStatus = .syncing
        do {
            guard let zoneIDName = family.zoneID else {
                throw NSError(domain: "FamilySync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No family zone"])
            }

            let zoneID = CKRecordZone.ID(zoneName: zoneIDName, ownerName: CKCurrentUserDefaultName)
            var records: [CKRecord] = []

            for item in items {
                let record = CKRecord(recordType: "FreshliItem", recordID: CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID))
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

            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.isAtomic = false
            operation.qualityOfService = .userInitiated

            try await withCheckedThrowingContinuation { continuation in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        self.logger.info("Successfully synced items")
                        continuation.resume()
                    case .failure(let error):
                        self.logger.error("Failed to sync items: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(operation)
            }

            syncStatus = .synced
            PSHaptics.shared.success()
        } catch {
            logger.error("Failed to sync pantry items: \(error.localizedDescription)")
            syncStatus = .error("Sync failed")
            throw error
        }
    }

    // MARK: - Helper Methods

    private func generateShareURL(for share: CKShare) async throws -> URL {
        // CKShare.url is set by CloudKit after saving the share record
        if let url = share.url {
            return url
        }
        // Fallback: construct a deep-link placeholder
        return URL(string: "https://freshli.app/family/\(share.recordID.recordName)")!
    }

    private func fetchFamily(from zoneID: CKRecordZone.ID) async throws {
        logger.info("Fetching family from zone: \(zoneID)")

        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "FamilyMember", predicate: predicate)
            let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)

            var members: [FamilyMember] = []
            for (_, result) in matchResults {
                if let record = try? result.get(),
                   let member = parseMemberRecord(record, zoneID: zoneID) {
                    members.append(member)
                }
            }

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
            return nil
        }

        guard let uuid = UUID(uuidString: record.recordID.recordName) else {
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

    private func setupCloudKitSubscriptions() async {
        logger.info("Setting up CloudKit subscriptions")

        do {
            // Check iCloud status
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available:
                logger.info("iCloud account available")
            case .noAccount:
                logger.warning("No iCloud account signed in")
                syncStatus = .error("iCloud not signed in")
            case .restricted:
                logger.warning("iCloud access restricted")
                syncStatus = .error("iCloud access restricted")
            case .couldNotDetermine:
                logger.warning("Could not determine iCloud status")
            @unknown default:
                logger.warning("Unknown iCloud status")
            }
        } catch {
            logger.error("Failed to check iCloud status: \(error.localizedDescription)")
            syncStatus = .error("iCloud error")
        }
    }

    // MARK: - Persistence

    private func saveFamily() {
        if let family = currentFamily,
           let encoded = try? JSONEncoder().encode(family) {
            UserDefaults.standard.set(encoded, forKey: familyGroupKey)
        } else {
            UserDefaults.standard.removeObject(forKey: familyGroupKey)
        }
    }

    private func loadFamily() {
        if let data = UserDefaults.standard.data(forKey: familyGroupKey),
           let family = try? JSONDecoder().decode(FamilyGroup.self, from: data) {
            currentFamily = family
        }
    }

    private func loadInviteURL() {
        if let urlString = UserDefaults.standard.string(forKey: inviteCodeKey),
           let url = URL(string: urlString) {
            inviteURL = url
        }
    }
}
