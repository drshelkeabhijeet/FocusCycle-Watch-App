import SwiftUI


struct SettingsView: View {
    // Bindings from ContentView
    @Binding var operatingMode: OperatingMode
    
    // Single Interval Bindings
    @Binding var singleIntervalDurationSeconds: Int
    @Binding var singleIntervalSequenceDurationMinutes: Int
    @Binding var singleIntervalHaptic: AppHaptic
    
    // Multiple Interval Bindings
    @Binding var multipleIntervals: [CustomIntervalSetting]
    @Binding var multipleIntervalsSequenceDurationMinutes: Int
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var heart: HeartRateManager
    @AppStorage("compactSettings") private var compactSettings: Bool = true
    @State private var showingModeInfo = false
    @State private var showingMyPresetEditor = false
    // Companion iPhone sync removed
    
    // Ranges for minutes
    let durationSecondsRange = 10...7200 // 10s to 120 minutes
    let sequenceDurationRange = 0...240
    
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

    // MARK: - User Preset Storage
    struct UserPreset: Codable, Identifiable {
        let id: UUID
        var name: String
        var totalMinutes: Int
        var holdSeconds: Int
        var restSeconds: Int
        init(id: UUID = UUID(), name: String, totalMinutes: Int, holdSeconds: Int, restSeconds: Int) {
            self.id = id
            self.name = name
            self.totalMinutes = totalMinutes
            self.holdSeconds = holdSeconds
            self.restSeconds = restSeconds
        }
    }

    @AppStorage("userPresetJSON") private var userPresetJSON: String = ""
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
    @State private var draftPresetName: String = ""
    
    private func captureCurrentAsUserPreset(named name: String) {
        // Prefer multiple intervals (Hold/Rest) if available
        let total = (operatingMode == .multipleIntervals) ? multipleIntervalsSequenceDurationMinutes : singleIntervalSequenceDurationMinutes
        let hold: Int
        let rest: Int
        if operatingMode == .multipleIntervals {
            hold = multipleIntervals.first?.durationSeconds ?? 60
            rest = multipleIntervals.dropFirst().first?.durationSeconds ?? 0
        } else {
            hold = singleIntervalDurationSeconds
            rest = 0
        }
        saveUserPreset(UserPreset(name: name, totalMinutes: total, holdSeconds: hold, restSeconds: rest))
    }
    
    private func addInterval() {
        withAnimation(DesignSystem.Animation.bounce) {
            multipleIntervals.append(CustomIntervalSetting())
        }
    }
    
    private func deleteInterval(at offsets: IndexSet) {
        withAnimation(DesignSystem.Animation.standard) {
            multipleIntervals.remove(atOffsets: offsets)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: compactSettings ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md) {
                    // 1) About Heart Rate (past 5 sessions)
                    heartRateButtonSection

                    // 2) Presets (My preset + 3 yoga presets)
                    presetsButtonSection

                    // 2) Interval Settings (navigates to detail)
                    intervalSettingsButtonSection

                    // 3) About
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
        // Mode info no longer needed (single mode removed)
        // No sync alert or connectivity updates needed
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
            operatingMode = .multipleIntervals
        }
    }

    // MARK: - Heart Rate
    private var heartRateButtonSection: some View {
        NavigationLink(destination: HeartRateHistoryView()) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heart Rate")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Past 5 sessions")
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
        .buttonStyle(PlainButtonStyle())
    }

    // Legacy live graph (no longer shown)
    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Heart Rate (live)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.xs)

            HeartRateGraph(samples: heart.samples)
                .frame(height: 80)
                .cardStyle()
        }
    }

    // MARK: - About Button
    private var aboutButtonSection: some View {
        NavigationLink(destination: AboutFocusCycleView()) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "info.circle")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("About")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    Text("Version \(version)")
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
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Presets Button
    private var presetsButtonSection: some View {
        NavigationLink(
            destination: PresetsView(
                operatingMode: $operatingMode,
                multipleIntervals: $multipleIntervals,
                asanaCount: $multipleIntervalsSequenceDurationMinutes,
                yogaPresets: yogaPresets
            )
        ) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(DesignSystem.Colors.focusPurple)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Presets")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("My preset + 3 yoga presets")
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
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Interval Settings Button
    private var intervalSettingsButtonSection: some View {
        NavigationLink(
            destination: IntervalSettingsDetailView(
                multipleIntervals: $multipleIntervals,
                multipleIntervalsSequenceDurationMinutes: $multipleIntervalsSequenceDurationMinutes
            )
        ) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundColor(DesignSystem.Colors.focusBlue)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interval Settings")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Hold & Rest • Asanas")
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
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Yoga Presets Section
    private var yogaPresetsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Quick Presets")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.xs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // My Preset (first)
                    if let preset = currentUserPreset() {
                        presetButtonView(
                            name: preset.name,
                            totalMinutes: preset.totalMinutes,
                            holdSeconds: preset.holdSeconds,
                            restSeconds: preset.restSeconds,
                            icon: "bookmark.fill",
                            isSelected: {
                                if multipleIntervals.count >= 2 {
                                    return multipleIntervalsSequenceDurationMinutes == preset.totalMinutes &&
                                           multipleIntervals[0].durationSeconds == preset.holdSeconds &&
                                           multipleIntervals[1].durationSeconds == preset.restSeconds
                                }
                                return false
                            }(),
                            onApply: {
                                withAnimation(DesignSystem.Animation.bounce) {
                                    multipleIntervalsSequenceDurationMinutes = preset.totalMinutes
                                    multipleIntervals = [
                                        CustomIntervalSetting(durationSeconds: preset.holdSeconds, haptic: .default),
                                        CustomIntervalSetting(durationSeconds: preset.restSeconds, haptic: .default)
                                    ]
                                    operatingMode = .multipleIntervals
                                }
                            },
                            onEdit: { draftPresetName = preset.name; showingMyPresetEditor = true }
                        )
                    } else {
                        Button(action: { draftPresetName = ""; showingMyPresetEditor = true }) {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Create My Preset")
                                    .font(DesignSystem.Typography.micro)
                                    .lineLimit(1)
                                Text("Save from current settings")
                                    .font(DesignSystem.Typography.micro)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .frame(width: 120)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .fill(DesignSystem.Colors.cardBackground)
                            )
                            .foregroundColor(DesignSystem.Colors.focusBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    ForEach(yogaPresets) { preset in
                        let isSelected: Bool = {
                            if multipleIntervals.count >= 2 {
                                return multipleIntervalsSequenceDurationMinutes == preset.totalMinutes &&
                                       multipleIntervals[0].durationSeconds == preset.holdSeconds &&
                                       multipleIntervals[1].durationSeconds == preset.restSeconds
                            }
                            return false
                        }()

                        Button(action: {
                            withAnimation(DesignSystem.Animation.bounce) {
                                // Apply total session and two-phase intervals: Hold, Rest
                                multipleIntervalsSequenceDurationMinutes = preset.totalMinutes
                                multipleIntervals = [
                                    CustomIntervalSetting(durationSeconds: preset.holdSeconds, haptic: .default),
                                    CustomIntervalSetting(durationSeconds: preset.restSeconds, haptic: .default)
                                ]
                                operatingMode = .multipleIntervals
                            }
                        }) {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 20))
                                Text(preset.name)
                                    .font(DesignSystem.Typography.micro)
                                    .lineLimit(1)
                                Text("\(preset.totalMinutes)m • Hold \(preset.holdSeconds)s / Rest \(preset.restSeconds)s")
                                    .font(DesignSystem.Typography.micro)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .frame(width: 120)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .fill(isSelected ? DesignSystem.Colors.focusBlue.opacity(0.2)
                                                     : DesignSystem.Colors.cardBackground)
                            )
                            .foregroundColor(isSelected ? DesignSystem.Colors.focusBlue
                                                        : DesignSystem.Colors.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showingMyPresetEditor) {
            MyPresetEditor(
                presetName: $draftPresetName,
                onCancel: { showingMyPresetEditor = false },
                onSave: { name in
                    captureCurrentAsUserPreset(named: name.isEmpty ? "My Preset" : name)
                    showingMyPresetEditor = false
                }
            )
        }
    }

    // MARK: - Preset Button View
    private func presetButtonView(name: String, totalMinutes: Int, holdSeconds: Int, restSeconds: Int, icon: String, isSelected: Bool, onApply: @escaping () -> Void, onEdit: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onApply) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                    Text(name)
                        .font(DesignSystem.Typography.micro)
                        .lineLimit(1)
                    Text("\(totalMinutes)m • Hold \(holdSeconds)s / Rest \(restSeconds)s")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(width: 120)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(isSelected ? DesignSystem.Colors.focusBlue.opacity(0.2)
                                         : DesignSystem.Colors.cardBackground)
                )
                .foregroundColor(isSelected ? DesignSystem.Colors.focusBlue
                                            : DesignSystem.Colors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 120)
    }

    // MARK: - My Preset Editor
    struct MyPresetEditor: View {
        @Binding var presetName: String
        let onCancel: () -> Void
        let onSave: (String) -> Void

        var body: some View {
            NavigationView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Preset Name")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        TextField("My Preset", text: $presetName)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .cardStyle()

                    Text("Saves current settings as your preset")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Spacer()
                }
                .padding()
                .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
                .navigationTitle("My Preset")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onCancel() }
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { onSave(presetName) }
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.focusBlue)
                    }
                }
            }
        }
    }
    
    // MARK: - Single Interval Settings
    private var singleIntervalSettingsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // (Removed single-interval quick presets per request)
            
            // Interval Duration
            VStack(spacing: DesignSystem.Spacing.lg) {
                TimeStepperCard(
                    title: "Interval Duration",
                    seconds: $singleIntervalDurationSeconds,
                    range: durationSecondsRange,
                    stepSeconds: 10,
                    icon: "timer"
                )
                
                StepperCard(
                    title: "Total Session",
                    value: $singleIntervalSequenceDurationMinutes,
                    range: sequenceDurationRange,
                    step: 5,
                    unit: "min",
                    icon: "clock.fill",
                    showIndefinite: true
                )
                
                // Haptic Selection
                NavigationLink(destination: HapticSelectionView(selectedHaptic: $singleIntervalHaptic)) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        HapticIconView(hapticType: singleIntervalHaptic.name, size: 20)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Interval Alert")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(singleIntervalHaptic.name)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .cardStyle()
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Multiple Intervals Settings
    private var multipleIntervalsSettingsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Number of Asanas (each asana = Hold + Rest)
            StepperCard(
                title: "Number of Asanas",
                value: $multipleIntervalsSequenceDurationMinutes,
                range: 1...240,
                step: 1,
                unit: "asana(s)",
                icon: "figure.yoga"
            )
            
            // Intervals List
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("Asana Phases")
                        .font(DesignSystem.Typography.subheading)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.xs)
                
                // Exactly two phases: Hold and Rest
                if multipleIntervals.count >= 2 {
                    IntervalCard(
                        interval: $multipleIntervals[0],
                        onDelete: {},
                        roleLabel: "Hold",
                        showDelete: false
                    )
                    IntervalCard(
                        interval: $multipleIntervals[1],
                        onDelete: {},
                        roleLabel: "Rest",
                        showDelete: false
                    )
                } else {
                    EmptyIntervalsView(onAdd: { /* no-op; auto-initialized on appear */ })
                }
            }
        }
    }

    // (Layout toggle removed per request)
    
    // MARK: - Extracted View Components
    
    private var modeSelectionCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Focus Mode")
                    .font(DesignSystem.Typography.subheading)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { showingModeInfo = true }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
            }
            
            // Mode Toggle Buttons - Simplified for performance
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: {
                    operatingMode = .singleInterval
                }) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "timer")
                            .font(.system(size: 20))
                        Text("Single")
                            .font(DesignSystem.Typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .foregroundColor(operatingMode == .singleInterval ? .white : DesignSystem.Colors.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .fill(operatingMode == .singleInterval ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Button(action: {
                    operatingMode = .multipleIntervals
                }) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 20))
                        Text("Multiple")
                            .font(DesignSystem.Typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .foregroundColor(operatingMode == .multipleIntervals ? .white : DesignSystem.Colors.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .fill(operatingMode == .multipleIntervals ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .cardStyle()
    }
    
    // Sync UI removed for watch-only app
    
    private var aboutSection: some View {
        NavigationLink(destination: AboutFocusCycleView()) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("About FocusCycle")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    Text("Version \(version)")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .cardStyle()
        }
        .buttonStyle(PlainButtonStyle())
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

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Asanas, Hold & Rest")
                            .font(DesignSystem.Typography.subheading)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("One asana = Hold + Rest. You set the Hold and Rest durations and the total number of asanas. The app cycles through these phases until the asana count completes.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Health & Privacy")
                            .font(DesignSystem.Typography.subheading)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("The app can save mindful minutes when you end a session and can read live heart rate during practice. All data stays on your device.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Support")
                            .font(DesignSystem.Typography.subheading)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("For help or feedback, contact support.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
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

    // Sizing based on compact layout preference
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
            // Role pill
            if let role = roleLabel {
                Text(role)
                    .font(DesignSystem.Typography.subheading)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignSystem.Colors.cardBackgroundHighlight))
            }

            // Duration row
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

            // Haptic selector row
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
// (Quick duration chips removed per request)

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

struct ModeInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Single Interval Mode
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "timer")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.focusBlue)
                            Text("Single Interval")
                                .font(DesignSystem.Typography.heading)
                        }
                        
                        Text("Perfect for consistent focus sessions like Pomodoro. Set one interval that repeats throughout your session.")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .cardStyle()
                    
                    // Multiple Intervals Mode
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.focusPurple)
                            Text("Multiple Intervals")
                                .font(DesignSystem.Typography.heading)
                        }
                        
                        Text("Create complex focus patterns with different intervals. Each interval can have its own duration and haptic alert.")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("When intervals overlap, the highest priority haptic plays.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .padding(.top, DesignSystem.Spacing.xs)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .cardStyle()
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Focus Modes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
            }
        }
    }
}

// MARK: - Interval Settings Detail Screen
struct IntervalSettingsDetailView: View {
    @Binding var multipleIntervals: [CustomIntervalSetting]
    @Binding var multipleIntervalsSequenceDurationMinutes: Int
    @AppStorage("compactSettings") private var compactSettings: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Number of Asanas (each asana = Hold + Rest)
                StepperCard(
                    title: "Number of Asanas",
                    value: $multipleIntervalsSequenceDurationMinutes,
                    range: 1...240,
                    step: 1,
                    unit: "asana(s)",
                    icon: "figure.yoga"
                )

                // Intervals List
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Asana Phases")
                            .font(DesignSystem.Typography.subheading)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xs)

                    if multipleIntervals.count >= 2 {
                        IntervalCard(
                            interval: $multipleIntervals[0],
                            onDelete: {},
                            roleLabel: "Hold",
                            showDelete: false
                        )
                        IntervalCard(
                            interval: $multipleIntervals[1],
                            onDelete: {},
                            roleLabel: "Rest",
                            showDelete: false
                        )
                    } else {
                        EmptyIntervalsView(onAdd: { })
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Interval Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Presets Screen
struct PresetsView: View {
    @Binding var operatingMode: OperatingMode
    @Binding var multipleIntervals: [CustomIntervalSetting]
    @Binding var asanaCount: Int
    let yogaPresets: [SettingsView.YogaPreset]

    @AppStorage("userPresetJSON") private var userPresetJSON: String = ""
    // Full preset editor state
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

    private func captureCurrentAsUserPreset(named name: String) {
        let hold = multipleIntervals.first?.durationSeconds ?? 60
        let rest = multipleIntervals.dropFirst().first?.durationSeconds ?? 20
        let preset = UserPreset(id: UUID(), name: name, totalMinutes: asanaCount, holdSeconds: hold, restSeconds: rest)
        saveUserPreset(preset)
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
                // My Preset
                if let preset = currentUserPreset() {
                    let selected = isSelected(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds)
                    presetCard(name: preset.name,
                               subtitle: "\(preset.totalMinutes) asanas • Hold \(preset.holdSeconds)s / Rest \(preset.restSeconds)s",
                               icon: "bookmark.fill",
                               highlight: selected,
                               onApply: { applyPreset(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds) })
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
                        presetCardContent(name: "Create My Preset",
                                          subtitle: "Save from current settings",
                                          icon: "plus.circle.fill",
                                          highlight: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Yoga Presets
                ForEach(yogaPresets) { preset in
                    let selected = isSelected(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds)
                    Button(action: {
                        applyPreset(asanas: preset.totalMinutes, hold: preset.holdSeconds, rest: preset.restSeconds)
                    }) {
                        presetCardContent(name: preset.name,
                                          subtitle: "\(preset.totalMinutes) asanas • Hold \(preset.holdSeconds)s / Rest \(preset.restSeconds)s",
                                          icon: preset.icon,
                                          highlight: selected)
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

    // MARK: - Card helpers
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
    private func openFullPresetEditor(existing: UserPreset?) {
        if let p = existing {
            editName = p.name
            editAsanas = max(1, p.totalMinutes)
            editHold = max(10, p.holdSeconds)
            editRest = max(0, p.restSeconds)
        } else {
            // Seed with current settings if no preset exists yet
            editAsanas = max(1, asanaCount)
            editHold = multipleIntervals.first?.durationSeconds ?? 60
            editRest = multipleIntervals.dropFirst().first?.durationSeconds ?? 20
            editName = "My Preset"
        }
        showingFullPresetEditor = true
    }

    @ViewBuilder
    var fullPresetEditor: some View {
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
