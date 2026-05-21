import Foundation

@MainActor
final class CompanionStore: ObservableObject {
    // Singleton handle is nonisolated so other singletons (e.g. WatchConnectivityManager)
    // can construct themselves with this reference during their own static init.
    // Instance methods/properties remain main-actor isolated.
    nonisolated static let shared = CompanionStore()

    @Published private(set) var snapshot: CompanionStateSnapshot?
    @Published private(set) var sessionEvents: [CompanionSessionEvent] = []
    @Published private(set) var pendingCommands: [CompanionCommandPayload] = []

    private let snapshotKey = "companion.snapshot.json"
    private let eventsKey = "companion.events.json"
    private let pendingCommandsKey = "companion.pending.commands.json"
    private let defaults = UserDefaults.standard
    private let ioQueue = DispatchQueue(label: "CompanionStore.io")

    private nonisolated init() {
        // Defer state hydration to the main actor.
        Task { @MainActor in self.load() }
    }

    // Callable from any thread; hops to main if needed.
    nonisolated func ingestSnapshot(_ incoming: CompanionStateSnapshot) {
        Task { @MainActor in self.ingestSnapshotOnMain(incoming) }
    }

    nonisolated func ingestSessionEvent(_ event: CompanionSessionEvent) {
        Task { @MainActor in self.ingestSessionEventOnMain(event) }
    }

    private func ingestSnapshotOnMain(_ incoming: CompanionStateSnapshot) {
        if let current = self.snapshot {
            // Tie-break order: prefer larger sequence; if both unset, fall back to date.
            if current.sequence > 0 || incoming.sequence > 0 {
                if current.sequence >= incoming.sequence { return }
            } else if current.generatedAt > incoming.generatedAt {
                return
            }
        }
        self.snapshot = incoming
        self.persist()
    }

    private func ingestSessionEventOnMain(_ event: CompanionSessionEvent) {
        if self.sessionEvents.contains(where: { $0.id == event.id }) { return }
        self.sessionEvents.insert(event, at: 0)
        if self.sessionEvents.count > 500 {
            self.sessionEvents = Array(self.sessionEvents.prefix(500))
        }
        self.persist()
    }

    func enqueueCommand(_ command: CompanionCommandPayload) {
        self.pendingCommands.append(command)
        self.persist()
    }

    func markCommandDispatched(_ commandID: String) {
        self.pendingCommands.removeAll { $0.id == commandID }
        self.persist()
    }

    func clearPendingCommands() {
        self.pendingCommands.removeAll()
        self.persist()
    }

    func clearSessionHistory() {
        self.sessionEvents.removeAll()
        self.persist()
    }

    private func load() {
        snapshot = decode(CompanionStateSnapshot.self, key: snapshotKey)
        sessionEvents = decode([CompanionSessionEvent].self, key: eventsKey) ?? []
        pendingCommands = decode([CompanionCommandPayload].self, key: pendingCommandsKey) ?? []
    }

    private func persist() {
        let snap = snapshot
        let events = sessionEvents
        let pending = pendingCommands
        let snapKey = snapshotKey
        let evKey = eventsKey
        let pKey = pendingCommandsKey
        // UserDefaults is documented as thread-safe; mark capture nonisolated-unsafe
        // to silence the Sendable warning without wrapping at every call site.
        nonisolated(unsafe) let defaultsRef = defaults
        ioQueue.async {
            Self.encode(snap, key: snapKey, defaults: defaultsRef)
            Self.encode(events, key: evKey, defaults: defaultsRef)
            Self.encode(pending, key: pKey, defaults: defaultsRef)
        }
    }

    private nonisolated static func encode<T: Encodable>(_ value: T?, key: String, defaults: UserDefaults) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
