import SwiftUI

/// Compact per-phase alert chooser embedded inside the unified `AlertSettingsView`.
/// Each row is a native Picker so it adapts to watchOS list styling and stays large enough to tap.
struct PhaseAlertRow: View {
    let phase: BreathingPhase
    @StateObject private var alertManager = AlertManager.shared

    private var currentAlertType: AlertType {
        switch phase {
        case .inhale: return alertManager.settings.phaseAlerts.inhaleAlert
        case .hold1: return alertManager.settings.phaseAlerts.hold1Alert
        case .exhale: return alertManager.settings.phaseAlerts.exhaleAlert
        case .hold2: return alertManager.settings.phaseAlerts.hold2Alert
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Type", selection: Binding(
                get: { currentAlertType },
                set: { alertManager.updatePhaseAlert(for: phase, alertType: $0) }
            )) {
                ForEach(AlertType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.navigationLink)

            Button {
                alertManager.testPhaseAlert(for: phase)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text("Preview")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(DesignSystem.Colors.focusBlue)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Preview \(phase.displayName) alert")
        }
    }
}
