import SwiftUI


struct SettingsView: View {
    // Bindings from ContentView
    @Binding var operatingMode: OperatingMode

    // Single Interval Bindings (kept for source compatibility; not edited from this screen)
    @Binding var singleIntervalDurationSeconds: Int
    @Binding var singleIntervalSequenceDurationMinutes: Int
    @Binding var singleIntervalHaptic: AppHaptic

    // Multiple Interval Bindings
    @Binding var multipleIntervals: [CustomIntervalSetting]
    @Binding var multipleIntervalsSequenceDurationMinutes: Int

    @Environment(\.dismiss) var dismiss

    // Yoga presets for Multiple Intervals mode
    struct YogaPreset: Identifiable {
        let id = UUID()
        let name: String
        let totalMinutes: Int
        let holdSeconds: Int
        let restSeconds: Int
        let icon: String
    }

    let yogaPresets: [YogaPreset] = [
        YogaPreset(name: "Yoga Starter", totalMinutes: 30, holdSeconds: 30, restSeconds: 20, icon: "figure.mind.and.body"),
        YogaPreset(name: "Yoga Master", totalMinutes: 45, holdSeconds: 60, restSeconds: 20, icon: "crown.fill"),
        YogaPreset(name: "Yoga Guru", totalMinutes: 45, holdSeconds: 90, restSeconds: 10, icon: "star.circle.fill")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    sectionLabel("Quick Presets")
                    presetsButtonSection

                    sectionLabel("Advanced")
                    intervalSettingsButtonSection

                    aboutButtonSection
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
            }
        }
        .onAppear {
            // Ensure exactly two intervals exist: Hold (index 0) and Rest (index 1)
            if multipleIntervals.count < 1 {
                multipleIntervals.append(CustomIntervalSetting(durationSeconds: 60, haptic: .default))
            }
            if multipleIntervals.count < 2 {
                multipleIntervals.append(CustomIntervalSetting(durationSeconds: 20, haptic: .default))
            }
            if multipleIntervals.count > 2 {
                multipleIntervals = Array(multipleIntervals.prefix(2))
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignSystem.Spacing.xs)
    }

    private var aboutButtonSection: some View {
        NavigationLink(destination: AboutFocusCycleView()) {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            navRow(
                icon: "info.circle",
                iconColor: DesignSystem.Colors.textSecondary,
                title: "About",
                subtitle: "Version \(version)"
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var presetsButtonSection: some View {
        NavigationLink(
            destination: PresetsView(
                operatingMode: $operatingMode,
                multipleIntervals: $multipleIntervals,
                asanaCount: $multipleIntervalsSequenceDurationMinutes,
                yogaPresets: yogaPresets
            )
        ) {
            navRow(
                icon: "bookmark.fill",
                iconColor: DesignSystem.Colors.focusPurple,
                title: "Presets",
                subtitle: "My preset + 3 yoga presets"
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var intervalSettingsButtonSection: some View {
        NavigationLink(
            destination: IntervalSettingsDetailView(
                multipleIntervals: $multipleIntervals,
                multipleIntervalsSequenceDurationMinutes: $multipleIntervalsSequenceDurationMinutes
            )
        ) {
            navRow(
                icon: "square.stack.3d.up",
                iconColor: DesignSystem.Colors.focusBlue,
                title: "Interval Settings",
                subtitle: "Hold & Rest • Asanas"
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func navRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(subtitle)
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    // MARK: - About View
    struct AboutFocusCycleView: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Yoga Timer")
                        .font(DesignSystem.Typography.heading)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("A simple Apple Watch yoga timer. Set your asana count and customize two phases for each asana — Hold (pose) and Rest — with gentle haptic alerts. Track recent heart rate sessions from Settings.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    aboutBlock(title: "Asanas, Hold & Rest",
                               body: "One asana = Hold + Rest. You set the Hold and Rest durations and the total number of asanas. The app cycles through these phases until the asana count completes.")

                    aboutBlock(title: "Health & Privacy",
                               body: "The app can save mindful minutes when you end a session and can read live heart rate during practice. All data stays on your device.")

                    aboutBlock(title: "Support",
                               body: "For help or feedback, contact support.")
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }

        private func aboutBlock(title: String, body: String) -> some View {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.subheading)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(body)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Supporting Views
struct StepperCard: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    let icon: String
    var showIndefinite: Bool = false
    @AppStorage("compactSettings") private var compactSettings: Bool = true

    var displayValue: String {
        if showIndefinite && value == 0 {
            return "Indefinite"
        }
        return "\(value) \(unit)"
    }

    var body: some View {
        let ctrlFont: CGFloat = compactSettings ? 32 : 36
        let ctrlFrame: CGFloat = compactSettings ? 40 : 44
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.focusBlue)

                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Text(displayValue)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)

            HStack(alignment: .center) {
                Spacer(minLength: DesignSystem.Spacing.sm)
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Button(action: {
                        withAnimation(DesignSystem.Animation.quick) {
                            value = min(range.upperBound, value + step)
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: ctrlFont))
                            .foregroundColor(value < range.upperBound ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.textTertiary)
                            .frame(width: ctrlFrame, height: ctrlFrame)
                    }
                    .disabled(value >= range.upperBound)
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Increase \(title)")

                    Button(action: {
                        withAnimation(DesignSystem.Animation.quick) {
                            value = max(range.lowerBound, value - step)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: ctrlFont))
                            .foregroundColor(value > range.lowerBound ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.textTertiary)
                            .frame(width: ctrlFrame, height: ctrlFrame)
                    }
                    .disabled(value <= range.lowerBound)
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Decrease \(title)")
                }
                Spacer(minLength: DesignSystem.Spacing.sm)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .cardStyle()
    }
}

// MARK: - Time Stepper (seconds with mm:ss display)
struct TimeStepperCard: View {
    let title: String
    @Binding var seconds: Int
    let range: ClosedRange<Int>
    let stepSeconds: Int
    let icon: String
    @AppStorage("compactSettings") private var compactSettings: Bool = true

    private func formatted(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        let ctrlFont: CGFloat = compactSettings ? 32 : 36
        let ctrlFrame: CGFloat = compactSettings ? 40 : 44
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.focusBlue)

                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Text(formatted(seconds))
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)

            HStack(alignment: .center) {
                Spacer(minLength: DesignSystem.Spacing.sm)
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Button(action: {
                        withAnimation(DesignSystem.Animation.quick) {
                            seconds = min(range.upperBound, seconds + stepSeconds)
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: ctrlFont))
                            .foregroundColor(seconds < range.upperBound ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.textTertiary)
                            .frame(width: ctrlFrame, height: ctrlFrame)
                    }
                    .disabled(seconds >= range.upperBound)
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Increase \(title)")

                    Button(action: {
                        withAnimation(DesignSystem.Animation.quick) {
                            seconds = max(range.lowerBound, seconds - stepSeconds)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: ctrlFont))
                            .foregroundColor(seconds > range.lowerBound ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.textTertiary)
                            .frame(width: ctrlFrame, height: ctrlFrame)
                    }
                    .disabled(seconds <= range.lowerBound)
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Decrease \(title)")
                }
                Spacer(minLength: DesignSystem.Spacing.sm)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .cardStyle()
    }
}

struct IntervalCard: View {
    @Binding var interval: CustomIntervalSetting
    let onDelete: () -> Void
    var roleLabel: String? = nil
    var showDelete: Bool = true
    @State private var showingHapticPicker = false
    @AppStorage("compactSettings") private var compactSettings: Bool = true

    private var controlFontSize: CGFloat { compactSettings ? 30 : 34 }
    private var controlFrame: CGFloat { compactSettings ? 36 : 44 }
    private var cardPadding: CGFloat { compactSettings ? DesignSystem.Spacing.md : DesignSystem.Spacing.lg }
    private var accentColor: Color {
        if let role = roleLabel?.lowercased() {
            if role.contains("hold") { return DesignSystem.Colors.focusBlue }
            if role.contains("rest") { return DesignSystem.Colors.playGreen }
        }
        return DesignSystem.Colors.focusPurple
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if let role = roleLabel {
                Text(role)
                    .font(DesignSystem.Typography.subheading)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignSystem.Colors.cardBackgroundHighlight))
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Duration")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                HStack(alignment: .center) {
                    Text(String(format: "%d:%02d", interval.durationSeconds/60, interval.durationSeconds%60))
                        .font(DesignSystem.Typography.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: DesignSystem.Spacing.xs)
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Button(action: {
                            withAnimation(DesignSystem.Animation.quick) {
                                interval.durationSeconds = min(7200, interval.durationSeconds + 10)
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: controlFontSize))
                                .frame(width: controlFrame, height: controlFrame)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Increase duration")

                        Button(action: {
                            withAnimation(DesignSystem.Animation.quick) {
                                interval.durationSeconds = max(10, interval.durationSeconds - 10)
                            }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: controlFontSize))
                                .frame(width: controlFrame, height: controlFrame)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Decrease duration")
                    }
                }
                .foregroundColor(DesignSystem.Colors.focusBlue)
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                HapticIconView(hapticType: interval.haptic.name, size: 16)
                Button(action: { showingHapticPicker = true }) {
                    Text(interval.haptic.name)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Spacer()
                if showDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                Button("Preview") {
                    HapticFeedbackManager.shared.playHaptic(interval.haptic.type)
                }
                .font(DesignSystem.Typography.micro)
                .foregroundColor(DesignSystem.Colors.focusBlue)
            }
        }
        .padding(cardPadding)
        .cardStyle()
        .overlay(alignment: .leading) {
            Capsule()
                .fill(accentColor.opacity(0.9))
                .frame(width: 3)
        }
        .sheet(isPresented: $showingHapticPicker) {
            NavigationView {
                HapticSelectionView(selectedHaptic: $interval.haptic)
            }
        }
    }
}

struct EmptyIntervalsView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("No intervals yet")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Add intervals to create custom focus patterns")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxl)
        .cardStyle()
    }
}

// MARK: - Interval Settings Detail Screen
struct IntervalSettingsDetailView: View {
    @Binding var multipleIntervals: [CustomIntervalSetting]
    @Binding var multipleIntervalsSequenceDurationMinutes: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                BigStepperRow(
                    title: "Asanas",
                    value: $multipleIntervalsSequenceDurationMinutes,
                    range: 1...240,
                    step: 1,
                    unit: "",
                    color: DesignSystem.Colors.focusPurple
                )

                if multipleIntervals.count >= 2 {
                    BigStepperRow(
                        title: "Hold",
                        value: Binding(
                            get: { multipleIntervals[0].durationSeconds },
                            set: { multipleIntervals[0].durationSeconds = $0 }
                        ),
                        range: 10...7200,
                        step: 10,
                        unit: "s",
                        color: DesignSystem.Colors.focusBlue
                    )
                    BigStepperRow(
                        title: "Rest",
                        value: Binding(
                            get: { multipleIntervals[1].durationSeconds },
                            set: { multipleIntervals[1].durationSeconds = $0 }
                        ),
                        range: 0...7200,
                        step: 10,
                        unit: "s",
                        color: DesignSystem.Colors.playGreen
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Intervals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Same large-stepper card used by the Pranayama editor, so both timer settings
/// share a consistent, easy-to-read shape across the app.
struct BigStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    let color: Color

    private var displayValue: String {
        if unit == "s" && value >= 60 {
            let m = value / 60
            let s = value % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(value)\(unit)"
    }

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
                Text(displayValue)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.snappy(duration: 0.15), value: value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Button {
                    value = max(range.lowerBound, value - step)
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
                    value = min(range.upperBound, value + step)
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

// MARK: - Presets Screen
struct PresetsView: View {
    @Binding var operatingMode: OperatingMode
    @Binding var multipleIntervals: [CustomIntervalSetting]
    @Binding var asanaCount: Int
    let yogaPresets: [SettingsView.YogaPreset]

    @AppStorage("userPresetJSON") private var userPresetJSON: String = ""
    @State private var showingFullPresetEditor = false
    @State private var editName: String = "My Preset"
    @State private var editAsanas: Int = 10
    @State private var editHold: Int = 60
    @State private var editRest: Int = 20

    struct UserPreset: Codable, Identifiable {
        let id: UUID
        var name: String
        var totalMinutes: Int // interpreted as asana count
        var holdSeconds: Int
        var restSeconds: Int
    }

    private func currentUserPreset() -> UserPreset? {
        guard !userPresetJSON.isEmpty, let data = userPresetJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(UserPreset.self, from: data)
    }

    private func saveUserPreset(_ preset: UserPreset?) {
        if let preset, let data = try? JSONEncoder().encode(preset), let str = String(data: data, encoding: .utf8) {
            userPresetJSON = str
        } else {
            userPresetJSON = ""
        }
    }

    private func applyPreset(asanas: Int, hold: Int, rest: Int) {
        withAnimation(DesignSystem.Animation.bounce) {
            asanaCount = asanas
            multipleIntervals = [
                CustomIntervalSetting(durationSeconds: hold, haptic: .default),
                CustomIntervalSetting(durationSeconds: rest, haptic: .default)
            ]
            operatingMode = .multipleIntervals
        }
    }

    private func isSelected(asanas: Int, hold: Int, rest: Int) -> Bool {
        guard multipleIntervals.count >= 2 else { return false }
        let holdNow = multipleIntervals[0].durationSeconds
        let restNow = multipleIntervals[1].durationSeconds
        return asanaCount == asanas && holdNow == hold && restNow == rest
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if let preset = currentUserPreset() {
                    let selected = isSelected(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds)
                    presetCard(
                        name: preset.name,
                        subtitle: "\(preset.totalMinutes) asanas • Hold \(preset.holdSeconds)s / Rest \(preset.restSeconds)s",
                        icon: "bookmark.fill",
                        highlight: selected,
                        onApply: { applyPreset(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds) }
                    )
                    Button(action: { openFullPresetEditor(existing: preset) }) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(DesignSystem.Colors.focusBlue)
                            Text("Edit My Preset")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .cardStyle()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button(action: { openFullPresetEditor(existing: nil) }) {
                        presetCardContent(
                            name: "Create My Preset",
                            subtitle: "Save from current settings",
                            icon: "plus.circle.fill",
                            highlight: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                ForEach(yogaPresets) { preset in
                    let selected = isSelected(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds)
                    Button(action: {
                        applyPreset(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds)
                    }) {
                        presetCardContent(
                            name: preset.name,
                            subtitle: "\(preset.totalMinutes) asanas • Hold \(preset.holdSeconds)s / Rest \(preset.restSeconds)s",
                            icon: preset.icon,
                            highlight: selected
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Presets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFullPresetEditor) { fullPresetEditor }
    }

    @ViewBuilder
    private func presetCard(name: String, subtitle: String, icon: String, highlight: Bool, onApply: @escaping () -> Void) -> some View {
        Button(action: onApply) {
            presetCardContent(name: name, subtitle: subtitle, icon: icon, highlight: highlight)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func presetCardContent(name: String, subtitle: String, icon: String, highlight: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(highlight ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.textSecondary)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(name)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(highlight ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.textPrimary)
                Text(subtitle)
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(highlight ? DesignSystem.Colors.focusBlue.opacity(0.9) : DesignSystem.Colors.textSecondary)
            }
            Spacer()
            if highlight {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.focusBlue)
                    .font(.system(size: 16))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(highlight ? DesignSystem.Colors.focusBlue.opacity(0.18) : DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Preset Editing Helpers
extension PresetsView {
    fileprivate func openFullPresetEditor(existing: UserPreset?) {
        if let p = existing {
            editName = p.name
            editAsanas = max(1, p.totalMinutes)
            editHold = max(10, p.holdSeconds)
            editRest = max(0, p.restSeconds)
        } else {
            editAsanas = max(1, asanaCount)
            editHold = multipleIntervals.first?.durationSeconds ?? 60
            editRest = multipleIntervals.dropFirst().first?.durationSeconds ?? 20
            editName = "My Preset"
        }
        showingFullPresetEditor = true
    }

    @ViewBuilder
    fileprivate var fullPresetEditor: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Preset Name")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        TextField("My Preset", text: $editName)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .cardStyle()

                    StepperCard(
                        title: "Number of Asanas",
                        value: $editAsanas,
                        range: 1...240,
                        step: 1,
                        unit: "asana(s)",
                        icon: "figure.yoga"
                    )

                    TimeStepperCard(
                        title: "Hold Duration",
                        seconds: $editHold,
                        range: 10...7200,
                        stepSeconds: 10,
                        icon: "timer"
                    )

                    TimeStepperCard(
                        title: "Rest Duration",
                        seconds: $editRest,
                        range: 0...7200,
                        stepSeconds: 10,
                        icon: "bed.double"
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingFullPresetEditor = false }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = editName.isEmpty ? "My Preset" : editName
                        let p = UserPreset(id: UUID(), name: name, totalMinutes: editAsanas, holdSeconds: editHold, restSeconds: editRest)
                        saveUserPreset(p)
                        applyPreset(asanas: editAsanas, hold: editHold, rest: editRest)
                        showingFullPresetEditor = false
                    }
                    .foregroundColor(DesignSystem.Colors.focusBlue)
                }
            }
        }
    }
}
