import SwiftUI

struct AlertSettingsView: View {
    @StateObject private var alertManager = AlertManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                ScrollView {
                    VStack(spacing: 6) {
                    // Header
                    HStack {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("Alert Settings")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button("Test") {
                            print("Testing alert...")
                            alertManager.testAlert()
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.top, 2)
                    
                    // Alert Type Selection
                    VStack(spacing: 3) {
                        Text("Alert Type")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 4) {
                            ForEach(AlertType.allCases, id: \.self) { type in
                                Button(action: {
                                    alertManager.updateAlertType(type)
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(alertManager.settings.alertType == type ? .white : DesignSystem.Colors.textSecondary)
                                        
                                        Text(type.displayName)
                                            .font(.system(size: 6, weight: .medium))
                                            .foregroundColor(alertManager.settings.alertType == type ? .white : DesignSystem.Colors.textSecondary)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(alertManager.settings.alertType == type ? DesignSystem.Colors.focusBlue : Color.clear)
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
                    .padding(.horizontal, M.hPad)
                    
                    // Haptic Settings (if haptic is enabled)
                    if alertManager.settings.alertType == .haptic || alertManager.settings.alertType == .both {
                        VStack(spacing: 4) {
                            Text("Haptic Type")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            ForEach(HapticType.allCases, id: \.self) { type in
                                Button(action: {
                                    alertManager.updateHapticType(type)
                                }) {
                                    HStack(spacing: 6) {
                                        Text(type.displayName)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(alertManager.settings.hapticType == type ? .white : DesignSystem.Colors.textSecondary)
                                        
                                        Spacer()
                                        
                                        if alertManager.settings.hapticType == type {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(alertManager.settings.hapticType == type ? DesignSystem.Colors.playGreen : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, M.hPad)
                    }
                    
                    // Sound Settings (if sound is enabled)
                    if alertManager.settings.alertType == .sound || alertManager.settings.alertType == .both {
                        VStack(spacing: 4) {
                            Text("Sound Type")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            ForEach(SoundType.allCases, id: \.self) { type in
                                Button(action: {
                                    alertManager.updateSoundType(type)
                                }) {
                                    HStack(spacing: 6) {
                                        Text(type.displayName)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(alertManager.settings.soundType == type ? .white : DesignSystem.Colors.textSecondary)
                                        
                                        Spacer()
                                        
                                        if alertManager.settings.soundType == type {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(alertManager.settings.soundType == type ? DesignSystem.Colors.focusPurple : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Volume Slider
                            VStack(spacing: 2) {
                                HStack {
                                    Text("Volume")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(alertManager.settings.volume * 100))%")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Slider(value: Binding(
                                    get: { alertManager.settings.volume },
                                    set: { alertManager.updateVolume($0) }
                                ), in: 0...1, step: 0.1)
                                .accentColor(DesignSystem.Colors.focusPurple)
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, M.hPad)
                    }
                    
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

struct AlertSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AlertSettingsView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            AlertSettingsView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
