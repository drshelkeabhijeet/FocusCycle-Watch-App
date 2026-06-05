import SwiftUI

struct PranayamaView: View {
    @StateObject private var settingsManager = PranayamaSettingsManager.shared
    @State private var selectedPatternForTimer: PranayamaType?
    @State private var selectedPatternForSettings: PranayamaType?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()

                let M = WatchMetrics.current(dynamicType: .medium)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(settingsManager.allPatterns, id: \.type) { pattern in
                            PatternRow(
                                pattern: pattern,
                                onStart: {
                                    LaunchStateStore.rememberPranayamaType(pattern.type.rawValue)
                                    selectedPatternForTimer = pattern.type
                                },
                                onCustomize: {
                                    LaunchStateStore.rememberPranayamaType(pattern.type.rawValue)
                                    selectedPatternForSettings = pattern.type
                                }
                            )
                        }
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Pranayama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
            }
        }
        .sheet(item: $selectedPatternForSettings) { patternType in
            PranayamaPatternSettingsView(patternType: patternType)
        }
        .sheet(item: $selectedPatternForTimer) { patternType in
            PranayamaTimerView(pattern: settingsManager.getPattern(for: patternType))
        }
    }
}

struct PatternRow: View {
    let pattern: PranayamaPattern
    let onStart: () -> Void
    let onCustomize: () -> Void

    private var rhythmText: String {
        "\(pattern.inhaleDuration)·\(pattern.hold1Duration)·\(pattern.exhaleDuration)·\(pattern.hold2Duration) · \(pattern.cycles)x"
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onStart) {
                HStack(spacing: 10) {
                    Image(systemName: pattern.type.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(pattern.type.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(rhythmText)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    Spacer()

                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.playGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Start \(pattern.type.displayName)")

            Button(action: onCustomize) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.cardBackgroundHighlight)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Customize \(pattern.type.displayName)")
        }
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
