import SwiftUI

struct PranayamaPatternSettingsView: View {
    let patternType: PranayamaType
    @StateObject private var settingsManager = PranayamaSettingsManager.shared
    @State private var showingTimer = false
    @Environment(\.dismiss) var dismiss

    var pattern: PranayamaPattern {
        settingsManager.getPattern(for: patternType)
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        PhaseStepperRow(
                            title: "Inhale",
                            value: Binding(
                                get: { pattern.inhaleDuration },
                                set: { newValue in
                                    var updated = pattern
                                    updated.inhaleDuration = newValue
                                    settingsManager.updatePattern(updated)
                                }
                            ),
                            range: 1...20,
                            unit: "s",
                            color: DesignSystem.Colors.focusBlue
                        )

                        PhaseStepperRow(
                            title: "Hold",
                            value: Binding(
                                get: { pattern.hold1Duration },
                                set: { newValue in
                                    var updated = pattern
                                    updated.hold1Duration = newValue
                                    settingsManager.updatePattern(updated)
                                }
                            ),
                            range: 0...20,
                            unit: "s",
                            color: DesignSystem.Colors.pauseOrange
                        )

                        PhaseStepperRow(
                            title: "Exhale",
                            value: Binding(
                                get: { pattern.exhaleDuration },
                                set: { newValue in
                                    var updated = pattern
                                    updated.exhaleDuration = newValue
                                    settingsManager.updatePattern(updated)
                                }
                            ),
                            range: 1...20,
                            unit: "s",
                            color: DesignSystem.Colors.playGreen
                        )

                        PhaseStepperRow(
                            title: "Hold",
                            value: Binding(
                                get: { pattern.hold2Duration },
                                set: { newValue in
                                    var updated = pattern
                                    updated.hold2Duration = newValue
                                    settingsManager.updatePattern(updated)
                                }
                            ),
                            range: 0...20,
                            unit: "s",
                            color: DesignSystem.Colors.pauseOrange
                        )

                        PhaseStepperRow(
                            title: "Cycles",
                            value: Binding(
                                get: { pattern.cycles },
                                set: { newValue in
                                    var updated = pattern
                                    updated.cycles = newValue
                                    settingsManager.updatePattern(updated)
                                }
                            ),
                            range: 1...30,
                            unit: "x",
                            color: DesignSystem.Colors.focusPurple
                        )

                        VStack(spacing: 2) {
                            Text("Total")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text(formatTotalDuration(pattern.totalDuration))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.focusPurple)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)

                        Button(action: { showingTimer = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Start")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(DesignSystem.Colors.playGreen)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }
            }
            .navigationTitle(patternType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        settingsManager.loadDefaultPatterns()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .accessibilityLabel("Reset to defaults")
                }
            }
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

/// Roomier replacement for the dense slider rows. Each row shows a large numeric
/// value with +/- buttons that are easy to hit on a watch face. Digital crown
/// users can also focus the value via `.focusable()` semantics.
struct PhaseStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(color)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("\(value)\(unit)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.snappy(duration: 0.15), value: value)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Button {
                    value = max(range.lowerBound, value - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DesignSystem.Colors.cardBackgroundHighlight))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.4 : 1.0)
                .accessibilityLabel("Decrease \(title)")

                Button {
                    value = min(range.upperBound, value + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(color))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.4 : 1.0)
                .accessibilityLabel("Increase \(title)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
        )
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
