import SwiftUI

/// Standalone sheet wrapper that lets the user edit Yoga settings without
/// presenting the timer underneath. Backed by `YogaPreferences` so changes
/// persist to the next session.
struct YogaCustomizeView: View {
    @StateObject private var prefs = YogaPreferences.shared
    @State private var operatingMode: OperatingMode = .multipleIntervals
    @State private var singleIntervalDurationSeconds: Int = 60
    @State private var singleIntervalSequenceDurationMinutes: Int = 30
    @State private var singleIntervalHaptic: AppHaptic = .notification
    @State private var multipleIntervals: [CustomIntervalSetting] = []
    @State private var multipleIntervalsSequenceDurationMinutes: Int = 10

    var body: some View {
        SettingsView(
            operatingMode: $operatingMode,
            singleIntervalDurationSeconds: $singleIntervalDurationSeconds,
            singleIntervalSequenceDurationMinutes: $singleIntervalSequenceDurationMinutes,
            singleIntervalHaptic: $singleIntervalHaptic,
            multipleIntervals: $multipleIntervals,
            multipleIntervalsSequenceDurationMinutes: $multipleIntervalsSequenceDurationMinutes
        )
        .onAppear {
            operatingMode = prefs.operatingMode
            singleIntervalDurationSeconds = prefs.singleIntervalDurationSeconds
            singleIntervalSequenceDurationMinutes = prefs.singleIntervalSequenceDurationMinutes
            multipleIntervalsSequenceDurationMinutes = prefs.asanaCount
            multipleIntervals = prefs.makeIntervals()
        }
        .onChange(of: operatingMode) { _, new in prefs.operatingMode = new }
        .onChange(of: singleIntervalDurationSeconds) { _, new in prefs.singleIntervalDurationSeconds = new }
        .onChange(of: singleIntervalSequenceDurationMinutes) { _, new in prefs.singleIntervalSequenceDurationMinutes = new }
        .onChange(of: multipleIntervalsSequenceDurationMinutes) { _, new in prefs.asanaCount = new }
        .onChange(of: multipleIntervals) { _, new in prefs.updateIntervals(new) }
    }
}
