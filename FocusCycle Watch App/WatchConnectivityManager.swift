import Foundation
import WatchConnectivity
import os

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published private(set) var isReachable: Bool = false
    @Published private(set) var activationDescription: String = "inactive"

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    private static let log = Logger(subsystem: "com.abhijeetshelke.Yoga-Timer", category: "watch.wc")

    // De-duplication ring buffer for incoming command IDs. Persisted so a relaunch
    // doesn't re-apply a command that arrived right before termination.
    private let seenIDsKey = "FocusCycle.WC.seenCommandIDs"
    private let seenIDsCap = 128
    private var seenIDs: [String] = []

    // Monotonic per-install snapshot sequence. Used by iOS to break ties when two
    // snapshots share an identical `generatedAt` millisecond.
    private let sequenceKey = "FocusCycle.WC.snapshotSequence"

    // Debounced snapshot push to coalesce rapid setting changes.
    private var snapshotPushWorkItem: DispatchWorkItem?
    private let snapshotPushDelay: TimeInterval = 0.25

    // iOS fires `requestState` on every launch, foreground, and pull-to-refresh.
    // Re-sending the full 90-day session history each time floods the
    // `transferUserInfo` queue, so throttle the heavy resend. The snapshot is
    // still pushed every time (it's a single, cheap applicationContext update).
    private var lastFullEventResend: Date?
    private let fullEventResendMinInterval: TimeInterval = 60

    private override init() {
        super.init()
        seenIDs = UserDefaults.standard.stringArray(forKey: seenIDsKey) ?? []
        // Set delegate eagerly so we don't miss any callbacks that arrive between
        // process launch and the SwiftUI `onAppear` call to `activate()`.
        if let session {
            session.delegate = self
        }
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
        isReachable = session.isReachable
    }

    func pushLatestSnapshot() {
        guard let session else { return }
        let envelope = CompanionEnvelope.snapshot(makeSnapshot())
        guard let context = envelope.toDictionary() else {
            Self.log.error("Snapshot encoding failed")
            return
        }
        do {
            try session.updateApplicationContext(context)
        } catch {
            // updateApplicationContext can fail (rate limit, not paired). Retry on next push.
            Self.log.error("updateApplicationContext failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Coalesces multiple snapshot-push requests fired within `snapshotPushDelay` into one.
    func pushLatestSnapshotDebounced() {
        snapshotPushWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pushLatestSnapshot()
        }
        snapshotPushWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + snapshotPushDelay, execute: work)
    }

    func pushSessionEvent(_ record: SessionRecord) {
        guard let session else { return }
        let event = CompanionSessionEvent(
            id: record.id.uuidString,
            activityTypeRawValue: record.activityType.rawValue,
            durationSeconds: record.duration,
            date: record.date,
            pattern: record.pattern,
            avgHeartRate: record.avgHeartRate,
            avgRespiratoryRate: record.avgRespiratoryRate,
            activeEnergyKcal: record.activeEnergyKcal,
            hrvPreSdnnMs: record.hrvPreSdnnMs,
            hrvPostSdnnMs: record.hrvPostSdnnMs,
            spo2PrePercent: record.spo2PrePercent,
            spo2PostPercent: record.spo2PostPercent,
            hrSamples: record.hrSamples?.map { CompanionHRSample(t: $0.t, bpm: $0.bpm) }
        )
        let envelope = CompanionEnvelope.sessionEvent(event)
        guard let payload = envelope.toDictionary() else { return }
        session.transferUserInfo(payload)
    }

    /// Re-sends all stored session records to the companion iOS app.
    /// Called when iOS explicitly requests a full state sync. Uses the existing
    /// per-event `transferUserInfo` path so iOS can deduplicate by event ID.
    /// Limits to the last 90 days to avoid flooding the transfer queue.
    private func pushStoredSessionEvents() {
        guard let session else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        var allRecords: [SessionRecord] = []
        for activityType in ActivityType.allCases {
            let records = StreakManager.shared.getStreakData(for: activityType).sessions
            allRecords.append(contentsOf: records.filter { $0.date >= cutoff })
        }
        // Sort oldest-first so the iOS store receives them in chronological order.
        let sorted = allRecords.sorted { $0.date < $1.date }
        for record in sorted {
            let event = CompanionSessionEvent(
                id: record.id.uuidString,
                activityTypeRawValue: record.activityType.rawValue,
                durationSeconds: record.duration,
                date: record.date,
                pattern: record.pattern,
                avgHeartRate: record.avgHeartRate,
                avgRespiratoryRate: record.avgRespiratoryRate,
                activeEnergyKcal: record.activeEnergyKcal,
                hrvPreSdnnMs: record.hrvPreSdnnMs,
                hrvPostSdnnMs: record.hrvPostSdnnMs,
                spo2PrePercent: record.spo2PrePercent,
                spo2PostPercent: record.spo2PostPercent,
                hrSamples: record.hrSamples?.map { CompanionHRSample(t: $0.t, bpm: $0.bpm) }
            )
            guard let payload = CompanionEnvelope.sessionEvent(event).toDictionary() else { continue }
            session.transferUserInfo(payload)
        }
    }

    /// Recent sessions embedded in every snapshot so iOS never misses history
    /// even when individual `transferUserInfo` events are delayed or dropped.
    /// HR series are stripped and the list capped to respect the ~64KB
    /// applicationContext limit; full events (with samples) still travel via
    /// the userInfo queue.
    private func makeRecentEvents() -> [CompanionSessionEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        var allRecords: [SessionRecord] = []
        for activityType in ActivityType.allCases {
            let records = StreakManager.shared.getStreakData(for: activityType).sessions
            allRecords.append(contentsOf: records.filter { $0.date >= cutoff })
        }
        return allRecords
            .sorted { $0.date > $1.date }
            .prefix(100)
            .map { record in
                CompanionSessionEvent(
                    id: record.id.uuidString,
                    activityTypeRawValue: record.activityType.rawValue,
                    durationSeconds: record.duration,
                    date: record.date,
                    pattern: record.pattern,
                    avgHeartRate: record.avgHeartRate,
                    avgRespiratoryRate: record.avgRespiratoryRate,
                    activeEnergyKcal: record.activeEnergyKcal,
                    hrvPreSdnnMs: record.hrvPreSdnnMs,
                    hrvPostSdnnMs: record.hrvPostSdnnMs,
                    spo2PrePercent: record.spo2PrePercent,
                    spo2PostPercent: record.spo2PostPercent,
                    hrSamples: nil
                )
            }
    }

    private func makeSnapshot() -> CompanionStateSnapshot {
        let streaks = StreakManager.shared.companionStreakSummaries()

        let yoga = CompanionYogaPreset(
            holdSeconds: UserDefaults.standard.integer(forKey: "userHoldSeconds"),
            restSeconds: UserDefaults.standard.integer(forKey: "userRestSeconds"),
            asanaCount: UserDefaults.standard.integer(forKey: "userAsanaCount")
        )

        // De-dupe by pattern type so the iOS form never sees collisions.
        var seenTypes: Set<String> = []
        let pranayama = PranayamaSettingsManager.shared.allPatterns.compactMap { p -> CompanionPranayamaPreset? in
            guard seenTypes.insert(p.type.rawValue).inserted else { return nil }
            return CompanionPranayamaPreset(
                typeRawValue: p.type.rawValue,
                inhaleDuration: p.inhaleDuration,
                hold1Duration: p.hold1Duration,
                exhaleDuration: p.exhaleDuration,
                hold2Duration: p.hold2Duration,
                cycles: p.cycles
            )
        }

        let meditation = CompanionMeditationPreset(
            durationMinutes: max(1, UserDefaults.standard.integer(forKey: "meditationCustomDurationMinutes"))
        )

        return CompanionStateSnapshot(
            generatedAt: Date(),
            sequence: nextSnapshotSequence(),
            streaksByActivity: streaks,
            presets: CompanionPresetsSnapshot(yoga: yoga, pranayama: pranayama, meditation: meditation),
            recentEvents: makeRecentEvents()
        )
    }

    private func nextSnapshotSequence() -> UInt64 {
        let current = UInt64(UserDefaults.standard.integer(forKey: sequenceKey))
        let next = current &+ 1
        UserDefaults.standard.set(Int(truncatingIfNeeded: next), forKey: sequenceKey)
        return next
    }

    // MARK: - Command application

    /// Returns true when state mutated (caller decides whether to push a fresh snapshot).
    @discardableResult
    private func applyIncomingCommand(_ command: CompanionCommandPayload) -> Bool {
        guard markCommandSeenIfNew(command.id) else { return false }

        switch command.type {
        case "requestState":
            let now = Date()
            if let last = lastFullEventResend, now.timeIntervalSince(last) < fullEventResendMinInterval {
                // Skip the heavy full-history resend; the snapshot push below
                // (triggered by the `true` return) is enough to refresh iOS.
            } else {
                lastFullEventResend = now
                pushStoredSessionEvents()
            }
            return true // caller will push snapshot

        case "quickStart":
            guard let quick = command.quickStart,
                  let practice = LaunchPractice(rawValue: quick.practice) else { return false }
            LaunchStateStore.remember(practice)
            Task { @MainActor in
                QuickStartCoordinator.shared.pendingPractice = practice
            }
            return false

        case "applyPreset":
            guard let apply = command.applyPreset else { return false }
            switch apply.practice {
            case "yoga":
                guard let yoga = apply.yoga else { return false }
                let hold = max(0, yoga.holdSeconds)
                let rest = max(0, yoga.restSeconds)
                let asanas = max(0, yoga.asanaCount)
                guard hold > 0, asanas > 0 else { return false }
                // Write through YogaPreferences (the store the watch timer and
                // customize UI actually read). Its property observers mirror
                // the legacy user* keys and push a fresh snapshot to iOS.
                Task { @MainActor in
                    let prefs = YogaPreferences.shared
                    prefs.holdSeconds = hold
                    prefs.restSeconds = rest
                    prefs.asanaCount = asanas
                }
                return false

            case "pranayama":
                guard let p = apply.pranayama,
                      let type = PranayamaType(rawValue: p.typeRawValue) else { return false }
                let inhale = max(1, p.inhaleDuration)
                let exhale = max(1, p.exhaleDuration)
                let hold1 = max(0, p.hold1Duration)
                let hold2 = max(0, p.hold2Duration)
                let cycles = max(1, p.cycles)
                // updatePattern triggers its own debounced snapshot push.
                PranayamaSettingsManager.shared.updatePattern(
                    PranayamaPattern(
                        type: type,
                        inhaleDuration: inhale,
                        hold1Duration: hold1,
                        exhaleDuration: exhale,
                        hold2Duration: hold2,
                        cycles: cycles
                    )
                )
                return false

            case "meditation":
                guard let m = apply.meditation else { return false }
                let minutes = max(1, min(240, m.durationMinutes))
                UserDefaults.standard.set(minutes, forKey: "meditationCustomDurationMinutes")
                return true

            default:
                return false
            }

        default:
            return false
        }
    }

    private func markCommandSeenIfNew(_ id: String) -> Bool {
        if seenIDs.contains(id) { return false }
        seenIDs.append(id)
        if seenIDs.count > seenIDsCap {
            seenIDs.removeFirst(seenIDs.count - seenIDsCap)
        }
        UserDefaults.standard.set(seenIDs, forKey: seenIDsKey)
        return true
    }

    private func handleIncomingDictionary(_ dictionary: [String: Any]) {
        guard let envelope = CompanionEnvelope.fromDictionary(dictionary),
              envelope.kind == "command",
              let command = envelope.command else { return }
        let mutated = applyIncomingCommand(command)
        if mutated {
            pushLatestSnapshotDebounced()
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.activationDescription = "\(activationState.rawValue)"
            self.isReachable = session.isReachable
            if error == nil {
                self.pushLatestSnapshot()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable {
                self.pushLatestSnapshot()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleIncomingDictionary(message)
        }
    }

    // iOS sends commands via sendMessage WITH a replyHandler. Without this
    // delegate method the message is never delivered to the watch. We handle
    // the command then immediately acknowledge so iOS doesn't time out.
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        replyHandler([:])
        DispatchQueue.main.async {
            self.handleIncomingDictionary(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.handleIncomingDictionary(applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            self.handleIncomingDictionary(userInfo)
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
