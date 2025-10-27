import SwiftUI

struct PranayamaPatternSettingsView: View {
    let patternType: PranayamaType
    @StateObject private var settingsManager = PranayamaSettingsManager.shared
    @State private var showingTimer = false
    @Environment(\.presentationMode) var presentationMode
    
    var pattern: PranayamaPattern {
        settingsManager.getPattern(for: patternType)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Header
                        HStack {
                            Button("Back") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            Text(patternType.displayName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            Button("Reset") {
                                settingsManager.loadDefaultPatterns()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.horizontal, M.hPad)
                        .padding(.top, 8)
                        
                        // Description
                        Text(patternType.description)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, M.hPad)
                        
                        // Timing Settings
                        VStack(spacing: 10) {
                            TimingSlider(
                                title: "Inhale",
                                value: Binding(
                                    get: { pattern.inhaleDuration },
                                    set: { newValue in
                                        var updatedPattern = pattern
                                        updatedPattern.inhaleDuration = newValue
                                        settingsManager.updatePattern(updatedPattern)
                                    }
                                ),
                                range: 1...20,
                                color: DesignSystem.Colors.focusBlue
                            )
                            
                            TimingSlider(
                                title: "Hold",
                                value: Binding(
                                    get: { pattern.hold1Duration },
                                    set: { newValue in
                                        var updatedPattern = pattern
                                        updatedPattern.hold1Duration = newValue
                                        settingsManager.updatePattern(updatedPattern)
                                    }
                                ),
                                range: 0...20,
                                color: DesignSystem.Colors.pauseOrange
                            )
                            
                            TimingSlider(
                                title: "Exhale",
                                value: Binding(
                                    get: { pattern.exhaleDuration },
                                    set: { newValue in
                                        var updatedPattern = pattern
                                        updatedPattern.exhaleDuration = newValue
                                        settingsManager.updatePattern(updatedPattern)
                                    }
                                ),
                                range: 1...20,
                                color: DesignSystem.Colors.playGreen
                            )
                            
                            TimingSlider(
                                title: "Hold",
                                value: Binding(
                                    get: { pattern.hold2Duration },
                                    set: { newValue in
                                        var updatedPattern = pattern
                                        updatedPattern.hold2Duration = newValue
                                        settingsManager.updatePattern(updatedPattern)
                                    }
                                ),
                                range: 0...20,
                                color: DesignSystem.Colors.pauseOrange
                            )
                            
                            TimingSlider(
                                title: "Cycles",
                                value: Binding(
                                    get: { pattern.cycles },
                                    set: { newValue in
                                        var updatedPattern = pattern
                                        updatedPattern.cycles = newValue
                                        settingsManager.updatePattern(updatedPattern)
                                    }
                                ),
                                range: 1...30,
                                color: DesignSystem.Colors.focusPurple
                            )
                        }
                        .padding(.horizontal, M.hPad)
                        
                        // Total Duration Info
                        VStack(spacing: 4) {
                            Text("Total Duration")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Text(formatTotalDuration(pattern.totalDuration))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.focusPurple)
                        }
                        .padding(.vertical, 8)
                        
                        // Start Button
                        Button(action: {
                            showingTimer = true
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Start Session")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(DesignSystem.Colors.playGreen)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, M.hPad)
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingTimer) {
            PranayamaTimerView(pattern: settingsManager.getPattern(for: patternType))
        }
    }
    
    private func formatTotalDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 && remainingSeconds > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

struct PranayamaPatternSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PranayamaPatternSettingsView(patternType: .anulom)
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            PranayamaPatternSettingsView(patternType: .ujjayi)
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
