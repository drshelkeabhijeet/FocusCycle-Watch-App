import Foundation
import WatchConnectivity
import os

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager(store: .shared)

    @Published private(set) var isReachable: Bool = false
    @Published private(set) var activationDescription: String = "inactive"
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false

    /// Surface a transient acknowledgement when a command was just dispatched to the watch.
    /// Views observe this and show a toast then clear it.
    @Published var lastDispatch: DispatchAck?

    struct DispatchAck: Equatable {
        let id: String
        let title: String
        let success: Bool
    }

    private let store: CompanionStore
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    private static let log = Logger(subsystem: "com.abhijeetshelke.Yoga-Timer", category: "ios.wc")

    init(store: CompanionStore) {
        self.store = store
        super.init()
        // Set delegate eagerly. WCSession requires the delegate be set before
        // `activate()`; doing it in init guarantees we don't miss a callback
        // delivered between launch and the SwiftUI `onAppear`.
        if let session {
            session.delegate = self
        }
    }

    func activate() {
        guard let session else { return }
        session.activate()
        Task { @MainActor in
            self.refreshPairingState(session)
        }
    }

    @MainActor
    func requestLatestState() {
        send(.init(
            id: UUID().uuidString,
            type: "requestState",
            createdAt: Date(),
            quickStart: nil,
            applyPreset: nil
        ), title: "Sync requested")
    }

    @MainActor
    func sendQuickStart(practice: String) {
        send(.init(
            id: UUID().uuidString,
            type: "quickStart",
            createdAt: Date(),
            quickStart: CompanionQuickStartCommand(practice: practice),
            applyPreset: nil
        ), title: "Start \(practice.capitalized) sent")
    }

    @MainActor
    func sendApplyYogaPreset(holdSeconds: Int, restSeconds: Int, asanaCount: Int) {
        send(.init(
            id: UUID().uuidString,
            type: "applyPreset",
            createdAt: Date(),
            quickStart: nil,
            applyPreset: CompanionApplyPresetCommand(
                practice: "yoga",
                yoga: CompanionYogaPreset(holdSeconds: holdSeconds, restSeconds: restSeconds, asanaCount: asanaCount),
                pranayama: nil,
                meditation: nil
            )
        ), title: "Yoga preset sent")
    }

    @MainActor
    func sendApplyPranayamaPreset(_ preset: CompanionPranayamaPreset) {
        send(.init(
            id: UUID().uuidString,
            type: "applyPreset",
            createdAt: Date(),
            quickStart: nil,
            applyPreset: CompanionApplyPresetCommand(
                practice: "pranayama",
                yoga: nil,
                pranayama: preset,
                meditation: nil
            )
        ), title: "Pranayama preset sent")
    }

    @MainActor
    func sendApplyMeditationPreset(durationMinutes: Int) {
        send(.init(
            id: UUID().uuidString,
            type: "applyPreset",
            createdAt: Date(),
            quickStart: nil,
            applyPreset: CompanionApplyPresetCommand(
                practice: "meditation",
                yoga: nil,
                pranayama: nil,
                meditation: CompanionMeditationPreset(durationMinutes: durationMinutes)
            )
        ), title: "Meditation preset sent")
    }

    /// Retries any commands that are still queued from a previous launch.
    /// Safe to call repeatedly — the watch dedupes by command id.
    @MainActor
    func flushPendingCommands() {
        guard let session else { return }
        let snapshot = store.pendingCommands
        for command in snapshot {
            transport(command, on: session) { [weak self] success in
                guard success else { return }
                Task { @MainActor [weak self] in
                    self?.store.markCommandDispatched(command.id)
                }
            }
        }
    }

    // MARK: - Internal

    @MainActor
    private func send(_ command: CompanionCommandPayload, title: String) {
        store.enqueueCommand(command)
        guard let session else {
            ack(id: command.id, title: title, success: false)
            return
        }
        transport(command, on: session) { [weak self] success in
            Task { @MainActor [weak self] in
                if success { self?.store.markCommandDispatched(command.id) }
                self?.ack(id: command.id, title: title, success: success)
            }
        }
    }

    @MainActor
    private func ack(id: String, title: String, success: Bool) {
        lastDispatch = DispatchAck(id: id, title: title, success: success)
        let captured = id
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self?.lastDispatch?.id == captured {
                self?.lastDispatch = nil
            }
        }
    }

    /// Single transport path. Prefers live `sendMessage` when reachable, otherwise
    /// hands the payload to `transferUserInfo` (system-queued + retried).
    private func transport(_ command: CompanionCommandPayload, on session: WCSession, completion: @escaping (Bool) -> Void) {
        guard let payload = CompanionEnvelope.command(command).toDictionary() else {
            Self.log.error("Command encoding failed: \(command.type, privacy: .public)")
            completion(false)
            return
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { _ in
                completion(true)
            }, errorHandler: { [weak self] error in
                Self.log.error("sendMessage failed: \(error.localizedDescription, privacy: .public); falling back to userInfo")
                self?.queueUserInfo(payload, on: session, completion: completion)
            })
        } else {
            queueUserInfo(payload, on: session, completion: completion)
        }
    }

    private func queueUserInfo(_ payload: [String: Any], on session: WCSession, completion: @escaping (Bool) -> Void) {
        session.transferUserInfo(payload)
        completion(true)
    }

    @MainActor
    private func refreshPairingState(_ session: WCSession) {
        isReachable = session.isReachable
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    // No-op: on single-pair installs we have only one watch. Required by the
    // WCSessionDelegate protocol; the system never tears this down for us.
    func sessionDidBecomeInactive(_ session: WCSession) {}
    // Re-activate to handle a watch switch (rare on iOS, but Apple-recommended).
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            Self.log.error("activation error: \(error.localizedDescription, privacy: .public)")
        }
        Task { @MainActor in
            self.activationDescription = "\(activationState.rawValue)"
            self.refreshPairingState(session)
            self.flushPendingCommands()
            self.requestLatestState()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshPairingState(session)
            if session.isReachable {
                self.flushPendingCommands()
            }
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshPairingState(session)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.handleIncomingDictionary(applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            self.handleIncomingDictionary(userInfo)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.handleIncomingDictionary(message)
        }
    }

    @MainActor
    private func handleIncomingDictionary(_ dictionary: [String: Any]) {
        guard let envelope = CompanionEnvelope.fromDictionary(dictionary) else {
            Self.log.warning("Discarded incoming dict (unparseable)")
            return
        }
        switch envelope.kind {
        case "stateSnapshot":
            if let snapshot = envelope.stateSnapshot {
                store.ingestSnapshot(snapshot)
            }
        case "sessionEvent":
            if let event = envelope.sessionEvent {
                store.ingestSessionEvent(event)
            }
        default:
            break
        }
    }
}

private extension CompanionEnvelope {
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    static func fromDictionary(_ dictionary: [String: Any]) -> CompanionEnvelope? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else { return nil }
        return try? JSONDecoder().decode(CompanionEnvelope.self, from: data)
    }
}
