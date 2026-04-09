import Foundation
import GroupActivities
import Combine
import os

// MARK: - SharePlay Manager
// Manages a GroupActivities session for live-syncing grocery lists and pantry views
// within a Freshli Circle during FaceTime.

@Observable @MainActor
final class SharePlayManager {
    var isSessionActive = false
    var sharedItems: [SharedFreshliItem] = []
    var participantCount = 0

    private var groupSession: GroupSession<FreshliCircleActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var tasks = Set<Task<Void, Never>>()
    private let logger = Logger(subsystem: "com.freshli.app", category: "SharePlayManager")

    // MARK: - Start Activity

    func startSession(circleId: UUID, circleName: String) async {
        let activity = FreshliCircleActivity(circleId: circleId, circleName: circleName)

        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
                logger.info("SharePlay: Activity activated for circle \(circleName)")
            } catch {
                logger.error("SharePlay: Activation failed — \(error.localizedDescription)")
            }
        case .activationDisabled:
            logger.info("SharePlay: Activation disabled by user")
        case .cancelled:
            logger.info("SharePlay: Activation cancelled")
        @unknown default:
            break
        }
    }

    // MARK: - Session Configuration

    func configureGroupSession(_ session: GroupSession<FreshliCircleActivity>) {
        groupSession = session
        let messenger = GroupSessionMessenger(session: session)
        self.messenger = messenger

        session.$state.sink { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .joined:
                    self.isSessionActive = true
                case .invalidated:
                    self.isSessionActive = false
                    self.reset()
                default:
                    break
                }
            }
        }
        .store(in: &subscriptions)

        session.$activeParticipants.sink { [weak self] participants in
            guard let self else { return }
            Task { @MainActor in
                self.participantCount = participants.count
            }
        }
        .store(in: &subscriptions)

        let groceryTask = Task { [weak self] in
            guard let self else { return }
            for await (message, _) in messenger.messages(of: GroceryListMessage.self) {
                await MainActor.run {
                    self.sharedItems = message.items
                }
            }
        }
        tasks.insert(groceryTask)

        let claimTask = Task { [weak self] in
            guard let self else { return }
            for await (message, _) in messenger.messages(of: ItemClaimMessage.self) {
                await MainActor.run {
                    if let index = self.sharedItems.firstIndex(where: { $0.id == message.itemId }) {
                        self.sharedItems[index].isCheckedOff = true
                    }
                }
            }
        }
        tasks.insert(claimTask)

        session.join()
        logger.info("SharePlay: Session configured and joined")
    }

    // MARK: - Send Messages

    func sendGroceryList(items: [SharedFreshliItem], senderId: String) async {
        guard let messenger else { return }

        let message = GroceryListMessage(items: items, senderId: senderId, timestamp: Date())
        do {
            try await messenger.send(message)
            sharedItems = items
            logger.info("SharePlay: Sent grocery list with \(items.count) items")
        } catch {
            logger.error("SharePlay: Failed to send grocery list — \(error.localizedDescription)")
        }
    }

    func sendItemClaim(itemId: UUID, claimedBy: String) async {
        guard let messenger else { return }

        let message = ItemClaimMessage(itemId: itemId, claimedBy: claimedBy, timestamp: Date())
        do {
            try await messenger.send(message)
            if let index = sharedItems.firstIndex(where: { $0.id == itemId }) {
                sharedItems[index].isCheckedOff = true
            }
            logger.info("SharePlay: Sent item claim for \(itemId)")
        } catch {
            logger.error("SharePlay: Failed to send claim — \(error.localizedDescription)")
        }
    }

    // MARK: - Add Item Live

    func addSharedItem(name: String, quantity: String, addedBy: String) async {
        let item = SharedFreshliItem(name: name, quantity: quantity, addedBy: addedBy)
        sharedItems.append(item)
        await sendGroceryList(items: sharedItems, senderId: addedBy)
    }

    // MARK: - End Session

    func endSession() {
        groupSession?.end()
        reset()
        logger.info("SharePlay: Session ended")
    }

    private func reset() {
        groupSession = nil
        messenger = nil
        subscriptions.removeAll()
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        sharedItems = []
        participantCount = 0
        isSessionActive = false
    }
}
