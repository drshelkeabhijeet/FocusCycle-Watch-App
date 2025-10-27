import SwiftUI

struct PranayamaView: View {
    @StateObject private var settingsManager = PranayamaSettingsManager.shared
    @State private var selectedPattern: PranayamaType?
    @State private var showingAllSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text("Pranayama")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAllSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(DesignSystem.Colors.focusBlue.opacity(0.8))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.top, 8)
                    
                    // Pattern Selection
                    VStack(spacing: 6) {
                        ForEach(settingsManager.allPatterns, id: \.type) { pattern in
                            Button(action: {
                                selectedPattern = pattern.type
                            }) {
                                PatternButtonContent(pattern: pattern)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                    }
                    .padding(.horizontal, M.hPad)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedPattern) { patternType in
            PranayamaPatternSettingsView(patternType: patternType)
        }
        .sheet(isPresented: $showingAllSettings) {
            PranayamaSettingsView()
        }
    }
}

struct PatternButtonContent: View {
    let pattern: PranayamaPattern
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pattern.type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(pattern.type.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Text(pattern.type.description)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct PranayamaView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PranayamaView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            PranayamaView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
