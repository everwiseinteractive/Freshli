import Foundation
import SwiftUI

// MARK: - Karma Credit Service
// "Food as Currency" — earn credits for sharing food with neighbours,
// spend credits when requesting items from your local pod.

// MARK: - Models

enum KarmaTransactionType: String, Codable, CaseIterable {
    case given    = "Given"
    case received = "Received"
    case bonus    = "Bonus"

    var icon: String {
        switch self {
        case .given:    return "arrow.up.circle.fill"
        case .received: return "arrow.down.circle.fill"
        case .bonus:    return "star.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .given:    return PSColors.primaryGreen
        case .received: return Color(hex: 0x3B82F6)
        case .bonus:    return PSColors.secondaryAmber
        }
    }
}

struct KarmaTransaction: Identifiable, Codable {
    let id: UUID
    let date: Date
    let type: KarmaTransactionType
    let amount: Int          // positive = earned, negative = spent
    let itemName: String
    let otherParty: String?  // neighbour name or pod

    init(id: UUID = UUID(), date: Date = Date(), type: KarmaTransactionType, amount: Int, itemName: String, otherParty: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.amount = amount
        self.itemName = itemName
        self.otherParty = otherParty
    }
}

// MARK: - Service

@MainActor
@Observable
final class KarmaCreditService {
    static let shared = KarmaCreditService()
    private init() { loadState() }

    var balance: Int = 0
    var transactions: [KarmaTransaction] = []

    private let balanceKey = "karma_balance"
    private let transactionsKey = "karma_transactions"

    // MARK: - Earn

    /// Earn credits for sharing an item. Default: 5 credits per item.
    func earn(itemName: String, amount: Int = 5, otherParty: String? = nil) {
        balance += amount
        let tx = KarmaTransaction(type: .given, amount: amount, itemName: itemName, otherParty: otherParty)
        transactions.insert(tx, at: 0)
        saveState()
    }

    /// One-time onboarding bonus.
    func awardBonus(amount: Int, reason: String) {
        balance += amount
        let tx = KarmaTransaction(type: .bonus, amount: amount, itemName: reason)
        transactions.insert(tx, at: 0)
        saveState()
    }

    // MARK: - Spend

    /// Spend credits to request an ingredient. Returns true if transaction succeeded.
    @discardableResult
    func spend(itemName: String, amount: Int = 5, otherParty: String? = nil) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        let tx = KarmaTransaction(type: .received, amount: -amount, itemName: itemName, otherParty: otherParty)
        transactions.insert(tx, at: 0)
        saveState()
        return true
    }

    func canAfford(_ amount: Int) -> Bool { balance >= amount }

    // MARK: - Stats

    var totalGiven: Int {
        transactions.filter { $0.type == .given }.reduce(0) { $0 + $1.amount }
    }
    var totalReceived: Int {
        transactions.filter { $0.type == .received }.reduce(0) { $0 + abs($1.amount) }
    }
    var itemsShared: Int { transactions.filter { $0.type == .given }.count }
    var itemsReceived: Int { transactions.filter { $0.type == .received }.count }

    // MARK: - Persistence

    private func saveState() {
        UserDefaults.standard.set(balance, forKey: balanceKey)
        if let data = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(data, forKey: transactionsKey)
        }
    }

    private func loadState() {
        balance = UserDefaults.standard.integer(forKey: balanceKey)
        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([KarmaTransaction].self, from: data) {
            transactions = decoded
        }
        // Welcome bonus for first-time users
        if transactions.isEmpty && balance == 0 {
            awardBonus(amount: 10, reason: "Welcome Bonus")
        }
    }
}
