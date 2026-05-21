import SwiftUI

struct AlertSettingsView: View {
    @StateObject private var alertManager = AlertManager.shared
    @Environment(\.dismiss) var dismiss

    /// When true, show per-phase pranayama controls below the general settings.
    var includesPhaseAlerts: Bool = true

    private var soundEnabled: Bool { AlertManager.hasBundledSoundAssets }

    private var visibleAlertTypes: [AlertType] {
        soundEnabled ? AlertType.allCases : AlertType.allCases.filter { $0 != .sound && $0 != .both }
    }

    var body: some View {
        NavigationView {
            List {
                Section("Type") {
                    Picker("Alert Type", selection: Binding(
                        get: { alertManager.settings.alertType },
                        set: { alertManager.updateAlertType($0) }
                    )) {
                        ForEach(visibleAlertTypes, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if alertManager.settings.alertType == .haptic || alertManager.settings.alertType == .both {
                    Section("Haptic") {
                        NavigationLink {
                            HapticPickerScreen()
                        } label: {
                            HStack {
                                Text("Style")
                                Spacer()
                                Text(alertManager.settings.hapticType.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if soundEnabled,
                   alertManager.settings.alertType == .sound || alertManager.settings.alertType == .both {
                    Section("Sound") {
                        NavigationLink {
                            SoundPickerScreen()
                        } label: {
                            HStack {
                                Text("Tone")
                                Spacer()
                                Text(alertManager.settings.soundType.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text("\(Int(alertManager.settings.volume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { alertManager.settings.volume },
                            set: { alertManager.updateVolume($0) }
                        ), in: 0...1, step: 0.1)
                        .accentColor(DesignSystem.Colors.focusPurple)
                    }
                }

                if includesPhaseAlerts {
                    Section("Per-phase (Pranayama)") {
                        NavigationLink {
                            PhaseAlertsScreen()
                        } label: {
                            HStack {
                                Text("Per-phase alerts")
                                Spacer()
                                Text(activePhaseSummary)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.carousel)
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { alertManager.testAlert() }) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(DesignSystem.Colors.focusBlue)
                    }
                    .accessibilityLabel("Test alert")
                }
            }
            .onAppear {
                if !soundEnabled,
                   alertManager.settings.alertType == .sound || alertManager.settings.alertType == .both {
                    alertManager.updateAlertType(.haptic)
                }
            }
        }
    }

    private var activePhaseSummary: String {
        let phases = alertManager.settings.phaseAlerts
        let active = [phases.inhaleAlert, phases.hold1Alert, phases.exhaleAlert, phases.hold2Alert]
            .filter { $0 != .none }
            .count
        return active == 0 ? "Off" : "\(active) on"
    }
}

// MARK: - Haptic Picker

private struct HapticPickerScreen: View {
    @StateObject private var alertManager = AlertManager.shared

    var body: some View {
        List {
            ForEach(HapticType.allCases, id: \.self) { type in
                Button {
                    alertManager.updateHapticType(type)
                } label: {
                    HStack {
                        Text(type.displayName)
                            .foregroundColor(.white)
                        Spacer()
                        if alertManager.settings.hapticType == type {
                            Image(systemName: "checkmark")
                                .foregroundColor(DesignSystem.Colors.playGreen)
                        }
                    }
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Haptic")
    }
}

// MARK: - Sound Picker

private struct SoundPickerScreen: View {
    @StateObject private var alertManager = AlertManager.shared

    var body: some View {
        List {
            ForEach(SoundType.allCases, id: \.self) { type in
                Button {
                    alertManager.updateSoundType(type)
                } label: {
                    HStack {
                        Text(type.displayName)
                            .foregroundColor(.white)
                        Spacer()
                        if alertManager.settings.soundType == type {
                            Image(systemName: "checkmark")
                                .foregroundColor(DesignSystem.Colors.focusPurple)
                        }
                    }
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Sound")
    }
}

// MARK: - Per-phase pranayama alerts

private struct PhaseAlertsScreen: View {
    var body: some View {
        List {
            ForEach([BreathingPhase.inhale, .hold1, .exhale, .hold2], id: \.self) { phase in
                Section(phase.displayName) {
                    PhaseAlertRow(phase: phase)
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Per-phase")
    }
}

struct AlertSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AlertSettingsView()
    }
}
