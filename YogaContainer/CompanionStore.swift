import Foundation
import os

@MainActor
final class CompanionStore: ObservableObject {
    // SwiftUI guarantees `@StateObject` initialization on the main actor; the
    // App entry point holds `CompanionStore.shared`, so first access is always
    // main-actor isolated. `assumeIsolated` lets us run a `@MainActor` init
    // synchronously, which is essential — see the persistence race notes below.
    nonisolated(unsafe) static let shared: CompanionStore = MainActor.assumeIsolated {
        CompanionStore()
    }

    @Published private(set) var snapshot: CompanionStateSnapshot?
    @Published private(set) var sessionEvents: [CompanionSessionEvent] = []
    @Published private(set) var pendingCommands: [CompanionCommandPayload] = []

    private let snapshotKey = "companion.snapshot.json"
    private let eventsKey = "companion.events.json"
    private let pendingCommandsKey = "companion.pending.commands.json"
    private let defaults = UserDefaults.standard
    private let ioQueue = DispatchQueue(label: "CompanionStore.io")
    private static let log = Logger(subsystem: "com.abhijeetshelke.Yoga-Timer", category: "ios.store")

    private init() {
        // CRITICAL: load synchronously. An earlier version deferred load() to a
        // Task, which created a window where an incoming snapshot/event would
        // trigger persist() with the in-memory buckets still at their default
        // empty state, overwriting on-disk events/commands with [].
        load()
    }

    nonisolated func ingestSnapshot(_ incoming: CompanionStateSnapshot) {
        Task { @MainActor in self.ingestSnapshotOnMain(incoming) }
    }

    nonisolated func ingestSessionEvent(_ event: CompanionSessionEvent) {
        Task { @MainActor in self.ingestSessionEventOnMain(event) }
    }

    private func ingestSnapshotOnMain(_ incoming: CompanionStateSnapshot) {
        // Merge embedded session history regardless of snapshot freshness —
        // events are immutable and deduped by id, so this can only add ones we
        // missed (e.g. when a transferUserInfo event was delayed or dropped).
        mergeRecentEvents(incoming.recentEvents)

        if let current = self.snapshot, !isNewer(incoming: incoming, than: current) {
            return
        }
        self.snapshot = incoming
        persistSnapshot()
    }

    /// Adds snapshot-embedded events that are missing locally. Existing entries
    /// are kept untouched: the per-event `transferUserInfo` payloads carry the
    /// full HR series, while embedded copies are stripped.
    private func mergeRecentEvents(_ incoming: [CompanionSessionEvent]?) {
        guard let incoming, !incoming.isEmpty else { return }
        let known = Set(sessionEvents.map(\.id))
        let missing = incoming.filter { !known.contains($0.id) }
        guard !missing.isEmpty else { return }
        sessionEvents.append(contentsOf: missing)
        sessionEvents.sort { $0.date > $1.date }
        if sessionEvents.count > 500 {
            sessionEvents = Array(sessionEvents.prefix(500))
        }
        persistEvents()
    }

    /// Newer-wins predicate that is robust to watch reinstalls (sequence reset)
    /// and clock drift: accept if EITHER the sequence advanced OR the timestamp
    /// is newer. This prevents a stale-sequence comparison from permanently
    /// rejecting otherwise-fresh snapshots.
    private func isNewer(incoming: CompanionStateSnapshot, than current: CompanionStateSnapshot) -> Bool {
        if incoming.sequence > current.sequence { return true }
        if incoming.generatedAt > current.generatedAt { return true }
        return false
    }

    private func ingestSessionEventOnMain(_ event: CompanionSessionEvent) {
        if let idx = self.sessionEvents.firstIndex(where: { $0.id == event.id }) {
            // Upgrade a stripped snapshot-embedded copy with the full payload
            // (the userInfo event carries the HR series; embedded copies don't).
            if self.sessionEvents[idx].hrSamples == nil, event.hrSamples != nil {
                self.sessionEvents[idx] = event
                persistEvents()
            }
            return
        }
        self.sessionEvents.insert(event, at: 0)
        self.sessionEvents.sort { $0.date > $1.date }
        if self.sessionEvents.count > 500 {
            self.sessionEvents = Array(self.sessionEvents.prefix(500))
        }
        persistEvents()
    }

    func enqueueCommand(_ command: CompanionCommandPayload) {
        self.pendingCommands.append(command)
        persistPending()
    }

    func markCommandDispatched(_ commandID: String) {
        self.pendingCommands.removeAll { $0.id == commandID }
        persistPending()
    }

    func clearPendingCommands() {
        self.pendingCommands.removeAll()
        persistPending()
    }

    func clearSessionHistory() {
        self.sessionEvents.removeAll()
        persistEvents()
    }

    private func load() {
        if let data = defaults.data(forKey: snapshotKey) {
            do { snapshot = try JSONDecoder().decode(CompanionStateSnapshot.self, from: data) }
            catch { Self.log.error("snapshot decode failed: \(error.localizedDescription, privacy: .public)") }
        }
        if let data = defaults.data(forKey: eventsKey) {
            do { sessionEvents = try JSONDecoder().decode([CompanionSessionEvent].self, from: data) }
            catch { Self.log.error("events decode failed: \(error.localizedDescription, privacy: .public)") }
        }
        if let data = defaults.data(forKey: pendingCommandsKey) {
            do { pendingCommands = try JSONDecoder().decode([CompanionCommandPayload].self, from: data) }
            catch { Self.log.error("pending decode failed: \(error.localizedDescription, privacy: .public)") }
        }
    }

    private func persistSnapshot() {
        let value = snapshot
        let key = snapshotKey
        nonisolated(unsafe) let defaultsRef = defaults
        ioQueue.async { Self.encode(value, key: key, defaults: defaultsRef) }
    }

    private func persistEvents() {
        let value = sessionEvents
        let key = eventsKey
        nonisolated(unsafe) let defaultsRef = defaults
        ioQueue.async { Self.encode(value, key: key, defaults: defaultsRef) }
    }

    private func persistPending() {
        let value = pendingCommands
        let key = pendingCommandsKey
        nonisolated(unsafe) let defaultsRef = defaults
        ioQueue.async { Self.encode(value, key: key, defaults: defaultsRef) }
    }

    private nonisolated static func encode<T: Encodable>(_ value: T?, key: String, defaults: UserDefaults) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            log.error("encode failed for key=\(key, privacy: .public)")
        }
    }
}
