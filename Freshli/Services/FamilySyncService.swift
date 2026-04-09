import Foundation
import Observation

// MARK: - FamilyMember Model

struct FamilyMember: Identifiable, Codable {
    let id: UUID
    var name: String
    var role: FamilyRole
    let joinDate: Date

    enum FamilyRole: String, Codable {
        case admin
        case member

        var displayName: String {
            switch self {
            case .admin: return "Admin"
            case .member: return "Member"
            }
        }
    }

    init(id: UUID = UUID(), name: String, role: FamilyRole = .member, joinDate: Date = Date()) {
        self.id = id
        self.name = name
        self.role = role
        self.joinDate = joinDate
    }
}

// MARK: - FamilyGroup Model

struct FamilyGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var members: [FamilyMember]
    var sharedPantryEnabled: Bool
    let createdDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        members: [FamilyMember] = [],
        sharedPantryEnabled: Bool = false,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.sharedPantryEnabled = sharedPantryEnabled
        self.createdDate = createdDate
    }
}

// MARK: - FamilySyncService

@Observable
final class FamilySyncService {
    private let familyGroupKey = "freshli_family_group"
    private let inviteCodeKey = "freshli_invite_code"
    private let syncStatusKey = "freshli_sync_status"

    var currentFamily: FamilyGroup? {
        didSet {
            saveFamily()
        }
    }

    var inviteCode: String? {
        didSet {
            if let code = inviteCode {
                UserDefaults.standard.set(code, forKey: inviteCodeKey)
            }
        }
    }

    var syncStatus: SyncStatus = .idle {
        didSet {
            UserDefaults.standard.set(syncStatus.rawValue, forKey: syncStatusKey)
        }
    }

    enum SyncStatus: String, Codable {
        case idle
        case syncing
        case success
        case error
    }

    init() {
        loadFamily()
        loadInviteCode()
    }

    // MARK: - Computed Properties

    var members: [FamilyMember] {
        currentFamily?.members ?? []
    }

    var isAdmin: Bool {
        // Check if current user is admin (for now, first member is admin)
        guard let family = currentFamily else { return false }
        return family.members.first?.role == .admin
    }

    var memberCount: Int {
        members.count
    }

    // MARK: - Family Management

    func createFamily(name: String, adminName: String = "You") {
        let adminMember = FamilyMember(name: adminName, role: .admin)
        let family = FamilyGroup(name: name, members: [adminMember], sharedPantryEnabled: false)

        currentFamily = family
        generateInviteCode()
    }

    func joinFamily(code: String, memberName: String) {
        // TODO: CloudKit Integration - validate code and join family
        // In production, this would:
        // 1. Query CloudKit for family with matching invite code
        // 2. Add current user as member to that family
        // 3. Sync family data to device

        guard var family = currentFamily else {
            print("Cannot join family: no family context")
            return
        }

        let newMember = FamilyMember(name: memberName, role: .member)
        if !family.members.contains(where: { $0.id == newMember.id }) {
            family.members.append(newMember)
            currentFamily = family
        }
    }

    func leaveFamily() {
        // TODO: CloudKit Integration - remove user from family
        currentFamily = nil
        inviteCode = nil
    }

    func generateInviteCode() {
        // Generate a simple 6-character alphanumeric code
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<6).map { _ in characters.randomElement()! })
        inviteCode = code
    }

    func toggleSharedPantry() {
        guard var family = currentFamily else { return }
        family.sharedPantryEnabled.toggle()
        currentFamily = family

        // TODO: CloudKit Integration - sync shared pantry state
    }

    func removeMember(_ member: FamilyMember) {
        guard var family = currentFamily else { return }
        family.members.removeAll { $0.id == member.id }
        currentFamily = family

        // TODO: CloudKit Integration - remove member from family on cloud
    }

    func updateMember(id: UUID, name: String? = nil, role: FamilyMember.FamilyRole? = nil) {
        guard var family = currentFamily else { return }

        if let index = family.members.firstIndex(where: { $0.id == id }) {
            if let name = name {
                family.members[index].name = name
            }
            if let role = role {
                family.members[index].role = role
            }
            currentFamily = family
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

    private func loadInviteCode() {
        if let code = UserDefaults.standard.string(forKey: inviteCodeKey) {
            inviteCode = code
        }
    }
}
