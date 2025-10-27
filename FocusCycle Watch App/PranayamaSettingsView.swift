import SwiftUI

struct PranayamaSettingsView: View {
    @StateObject private var settingsManager = PranayamaSettingsManager.shared
    @State private var selectedPattern: PranayamaType = .anulom
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                ScrollView {
                    VStack(spacing: 8) {
                    // Header
                    HStack {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("Settings")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button("Reset") {
                            settingsManager.loadDefaultPatterns()
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.top, 2)
                    
                    // Pattern Selection
                    VStack(spacing: 8) {
                        ForEach(PranayamaType.allCases, id: \.self) { type in
                            Button(action: {
                                selectedPattern = type
                            }) {
                                HStack {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                    
                                    Text(type.displayName)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if selectedPattern == type {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(DesignSystem.Colors.playGreen)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedPattern == type ? DesignSystem.Colors.playGreen.opacity(0.3) : DesignSystem.Colors.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    selectedPattern == type ? DesignSystem.Colors.playGreen : Color.white.opacity(0.2),
                                                    lineWidth: selectedPattern == type ? 2 : 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, M.hPad)
                    
                    // Timing Settings
                    if let pattern = settingsManager.patterns[selectedPattern] {
                        VStack(spacing: 4) {
                            Text("Timing Settings")
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            VStack(spacing: 3) {
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
                                    title: "Hold 1",
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
                                    title: "Hold 2",
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
                        }
                        .padding(.horizontal, M.hPad)
                    }
                    
                    Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
        }
    }
}

struct TimingSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Text("\(value)s")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("\(range.lowerBound)")
                    .font(.system(size: 6, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                .accentColor(color)
                
                Text("\(range.upperBound)")
                    .font(.system(size: 6, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
    }
}

struct PranayamaSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PranayamaSettingsView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            PranayamaSettingsView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
