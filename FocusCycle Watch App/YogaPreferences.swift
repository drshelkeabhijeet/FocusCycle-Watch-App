import Foundation
import Combine

/// Shared in-memory + UserDefaults-backed store for the Yoga practice configuration.
/// Both `YogaTimerView` (when run) and `SettingsView` (when customizing) read from
/// and write to this store so changes made in one surface are reflected in the other.
@MainActor
final class YogaPreferences: ObservableObject {
    static let shared = YogaPreferences()

    // Storage keys
    private enum K {
        static let mode = "yoga.operatingMode"
        static let singleDuration = "yoga.singleDurationSeconds"
        static let singleSequenceMin = "yoga.singleSequenceMinutes"
        static let asanaCount = "yoga.asanaCount"
        static let holdSeconds = "yoga.holdSeconds"
        static let restSeconds = "yoga.restSeconds"
    }

    // Legacy/mirror keys read by the landing page chip, the complication, and
    // the companion snapshot (`makeSnapshot()`). Kept in sync on every write so
    // the iOS app always sees the current preset.
    private enum Mirror {
        static let holdSeconds = "userHoldSeconds"
        static let restSeconds = "userRestSeconds"
        static let asanaCount = "userAsanaCount"
    }

    @Published var operatingMode: OperatingMode {
        didSet { defaults.set(operatingMode.rawValue, forKey: K.mode) }
    }
    @Published var singleIntervalDurationSeconds: Int {
        didSet { defaults.set(singleIntervalDurationSeconds, forKey: K.singleDuration) }
    }
    @Published var singleIntervalSequenceDurationMinutes: Int {
        didSet { defaults.set(singleIntervalSequenceDurationMinutes, forKey: K.singleSequenceMin) }
    }
    @Published var asanaCount: Int {
        didSet {
            defaults.set(asanaCount, forKey: K.asanaCount)
            defaults.set(asanaCount, forKey: Mirror.asanaCount)
            pushSnapshotIfChanged(oldValue, asanaCount)
        }
    }
    @Published var holdSeconds: Int {
        didSet {
            defaults.set(holdSeconds, forKey: K.holdSeconds)
            defaults.set(holdSeconds, forKey: Mirror.holdSeconds)
            pushSnapshotIfChanged(oldValue, holdSeconds)
        }
    }
    @Published var restSeconds: Int {
        didSet {
            defaults.set(restSeconds, forKey: K.restSeconds)
            defaults.set(restSeconds, forKey: Mirror.restSeconds)
            pushSnapshotIfChanged(oldValue, restSeconds)
        }
    }

    private func pushSnapshotIfChanged(_ old: Int, _ new: Int) {
        guard old != new else { return }
        WatchConnectivityManager.shared.pushLatestSnapshotDebounced()
    }

    private let defaults = UserDefaults.standard

    private init() {
        let modeRaw = defaults.string(forKey: K.mode) ?? OperatingMode.multipleIntervals.rawValue
        self.operatingMode = OperatingMode(rawValue: modeRaw) ?? .multipleIntervals
        let single = defaults.integer(forKey: K.singleDuration)
        self.singleIntervalDurationSeconds = single > 0 ? single : 60
        let singleSeq = defaults.integer(forKey: K.singleSequenceMin)
        self.singleIntervalSequenceDurationMinutes = singleSeq > 0 ? singleSeq : 30
        // Prefer the canonical yoga.* keys; fall back to the legacy mirror keys
        // (written by older builds and by iOS preset commands) before defaults.
        let asanas = defaults.integer(forKey: K.asanaCount)
        let mirrorAsanas = defaults.integer(forKey: Mirror.asanaCount)
        self.asanaCount = asanas > 0 ? asanas : (mirrorAsanas > 0 ? mirrorAsanas : 10)
        let hold = defaults.integer(forKey: K.holdSeconds)
        let mirrorHold = defaults.integer(forKey: Mirror.holdSeconds)
        self.holdSeconds = hold > 0 ? hold : (mirrorHold > 0 ? mirrorHold : 60)
        let rest = defaults.integer(forKey: K.restSeconds)
        // rest may legitimately be 0; only treat unset as default
        if defaults.object(forKey: K.restSeconds) != nil, rest >= 0 {
            self.restSeconds = rest
        } else if defaults.object(forKey: Mirror.restSeconds) != nil {
            self.restSeconds = max(0, defaults.integer(forKey: Mirror.restSeconds))
        } else {
            self.restSeconds = 20
        }

        // Property observers don't fire during init — sync the mirror keys
        // explicitly so the landing chip, complication, and companion snapshot
        // see consistent values from first launch.
        defaults.set(self.asanaCount, forKey: Mirror.asanaCount)
        defaults.set(self.holdSeconds, forKey: Mirror.holdSeconds)
        defaults.set(self.restSeconds, forKey: Mirror.restSeconds)
    }

    /// Build the timer's two-phase interval array from the persisted hold/rest seconds.
    func makeIntervals() -> [CustomIntervalSetting] {
        [
            CustomIntervalSetting(durationSeconds: max(10, holdSeconds), haptic: .default),
            CustomIntervalSetting(durationSeconds: max(0, restSeconds), haptic: .default)
        ]
    }

    /// Update hold/rest from an interval array (used when the timer mutates them locally).
    func updateIntervals(_ intervals: [CustomIntervalSetting]) {
        if intervals.indices.contains(0) {
            holdSeconds = intervals[0].durationSeconds
        }
        if intervals.indices.contains(1) {
            restSeconds = intervals[1].durationSeconds
        }
    }
}
