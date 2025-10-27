import SwiftUI

struct PhaseAlertSettingsView: View {
    @StateObject private var alertManager = AlertManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                ScrollView {
                    VStack(spacing: 4) {
                        // Header
                        HStack {
                            Button("Done") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            Text("Phase Alerts")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            Button("Test") {
                                alertManager.testPhaseAlert(for: .inhale)
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.focusBlue)
                        }
                        .padding(.horizontal, M.hPad)
                        .padding(.top, 2)
                        
                        // Phase Alert Settings
                        VStack(spacing: 3) {
                            ForEach([BreathingPhase.inhale, .hold1, .exhale, .hold2], id: \.self) { phase in
                                PhaseAlertRow(phase: phase)
                            }
                        }
                        .padding(.horizontal, M.hPad)
                        
                        // Global Phase Settings
                        VStack(spacing: 4) {
                            Text("Global Settings")
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            // Haptic Type
                            VStack(spacing: 2) {
                                Text("Haptic Type")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                ForEach(HapticType.allCases, id: \.self) { type in
                                    Button(action: {
                                        alertManager.updatePhaseHapticType(type)
                                    }) {
                                        HStack {
                                            Text(type.displayName)
                                                .font(.system(size: 8, weight: .medium))
                                                .foregroundColor(alertManager.settings.phaseAlerts.phaseHapticType == type ? .white : DesignSystem.Colors.textSecondary)
                                            
                                            Spacer()
                                            
                                            if alertManager.settings.phaseAlerts.phaseHapticType == type {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(alertManager.settings.phaseAlerts.phaseHapticType == type ? DesignSystem.Colors.playGreen : Color.clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            // Sound Type
                            VStack(spacing: 2) {
                                Text("Sound Type")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                ForEach(SoundType.allCases, id: \.self) { type in
                                    Button(action: {
                                        alertManager.updatePhaseSoundType(type)
                                    }) {
                                        HStack {
                                            Text(type.displayName)
                                                .font(.system(size: 8, weight: .medium))
                                                .foregroundColor(alertManager.settings.phaseAlerts.phaseSoundType == type ? .white : DesignSystem.Colors.textSecondary)
                                            
                                            Spacer()
                                            
                                            if alertManager.settings.phaseAlerts.phaseSoundType == type {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(alertManager.settings.phaseAlerts.phaseSoundType == type ? DesignSystem.Colors.focusPurple : Color.clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            // Volume
                            VStack(spacing: 2) {
                                HStack {
                                    Text("Volume")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(alertManager.settings.phaseAlerts.phaseVolume * 100))%")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Slider(value: Binding(
                                    get: { alertManager.settings.phaseAlerts.phaseVolume },
                                    set: { alertManager.updatePhaseVolume($0) }
                                ), in: 0...1, step: 0.1)
                                .accentColor(DesignSystem.Colors.focusPurple)
                            }
                            .padding(.horizontal, 6)
                        }
                        .padding(.horizontal, M.hPad)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

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
        VStack(spacing: 2) {
            HStack {
                Text(phase.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    alertManager.testPhaseAlert(for: phase)
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            HStack(spacing: 4) {
                ForEach(AlertType.allCases, id: \.self) { alertType in
                    Button(action: {
                        alertManager.updatePhaseAlert(for: phase, alertType: alertType)
                    }) {
                        VStack(spacing: 1) {
                            Image(systemName: alertType.icon)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(currentAlertType == alertType ? .white : DesignSystem.Colors.textSecondary)
                            
                            Text(alertType.displayName)
                                .font(.system(size: 6, weight: .medium))
                                .foregroundColor(currentAlertType == alertType ? .white : DesignSystem.Colors.textSecondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(currentAlertType == alertType ? DesignSystem.Colors.focusBlue : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.5))
        )
    }
}

struct PhaseAlertSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PhaseAlertSettingsView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            PhaseAlertSettingsView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
