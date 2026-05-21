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
        didSet { defaults.set(asanaCount, forKey: K.asanaCount) }
    }
    @Published var holdSeconds: Int {
        didSet { defaults.set(holdSeconds, forKey: K.holdSeconds) }
    }
    @Published var restSeconds: Int {
        didSet { defaults.set(restSeconds, forKey: K.restSeconds) }
    }

    private let defaults = UserDefaults.standard

    private init() {
        let modeRaw = defaults.string(forKey: K.mode) ?? OperatingMode.multipleIntervals.rawValue
        self.operatingMode = OperatingMode(rawValue: modeRaw) ?? .multipleIntervals
        let single = defaults.integer(forKey: K.singleDuration)
        self.singleIntervalDurationSeconds = single > 0 ? single : 60
        let singleSeq = defaults.integer(forKey: K.singleSequenceMin)
        self.singleIntervalSequenceDurationMinutes = singleSeq > 0 ? singleSeq : 30
        let asanas = defaults.integer(forKey: K.asanaCount)
        self.asanaCount = asanas > 0 ? asanas : 10
        let hold = defaults.integer(forKey: K.holdSeconds)
        self.holdSeconds = hold > 0 ? hold : 60
        let rest = defaults.integer(forKey: K.restSeconds)
        // rest may legitimately be 0; only treat unset (negative) as default
        self.restSeconds = (rest >= 0 && defaults.object(forKey: K.restSeconds) != nil) ? rest : 20
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
