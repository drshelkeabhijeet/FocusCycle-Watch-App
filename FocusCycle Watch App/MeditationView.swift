import SwiftUI

struct MeditationView: View {
    @State private var selectedDuration: Int = 10 // minutes
    @State private var showingTimer = false
    @AppStorage("meditationCustomDurationMinutes") private var customDuration: Int = 12
    @AppStorage("meditationUserPresetJSON") private var userPresetJSON: String = ""
    @State private var showingPresetEditor = false
    @State private var draftPresetName = ""
    @Environment(\.dismiss) private var dismiss

    private let presetDurations = [5, 10, 20, 30]

    struct MeditationPreset: Codable, Identifiable {
        let id: UUID
        var name: String
        var durationMinutes: Int
    }

    private func currentUserPreset() -> MeditationPreset? {
        guard !userPresetJSON.isEmpty, let data = userPresetJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MeditationPreset.self, from: data)
    }

    private func saveUserPreset(_ preset: MeditationPreset?) {
        if let preset, let data = try? JSONEncoder().encode(preset), let str = String(data: data, encoding: .utf8) {
            userPresetJSON = str
        } else {
            userPresetJSON = ""
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                ScrollView {
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            ForEach(presetDurations, id: \.self) { duration in
                                Button(action: { selectedDuration = duration }) {
                                    Text("\(duration)m")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(selectedDuration == duration ? .white : DesignSystem.Colors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedDuration == duration ? DesignSystem.Colors.focusPurple : DesignSystem.Colors.cardBackground)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        HStack(spacing: 8) {
                            Button(action: {
                                customDuration = max(1, customDuration - 1)
                                selectedDuration = customDuration
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(DesignSystem.Colors.focusBlue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Decrease duration")

                            Text("\(customDuration)m")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(minWidth: 64)

                            Button(action: {
                                customDuration = min(120, customDuration + 1)
                                selectedDuration = customDuration
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(DesignSystem.Colors.focusBlue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Increase duration")
                        }

                        if let preset = currentUserPreset() {
                            HStack(spacing: 6) {
                                Button(action: {
                                    selectedDuration = preset.durationMinutes
                                    customDuration = preset.durationMinutes
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bookmark.fill")
                                        Text("\(preset.name) · \(preset.durationMinutes)m")
                                            .lineLimit(1)
                                    }
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(DesignSystem.Colors.focusBlue.opacity(0.85))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    draftPresetName = preset.name
                                    showingPresetEditor = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Edit preset")
                            }
                        } else {
                            Button(action: {
                                draftPresetName = "My Meditation"
                                showingPresetEditor = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Save as preset")
                                }
                                .font(DesignSystem.Typography.micro)
                                .foregroundColor(DesignSystem.Colors.focusBlue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Button(action: { showingTimer = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Start \(selectedDuration)m")
                            }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignSystem.Colors.focusPurple)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("meditation-start")
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Meditation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
            }
        }
        .sheet(isPresented: $showingTimer) {
            MeditationTimerView(duration: selectedDuration)
        }
        .sheet(isPresented: $showingPresetEditor) {
            MeditationPresetEditor(
                presetName: $draftPresetName,
                durationMinutes: selectedDuration,
                onCancel: { showingPresetEditor = false },
                onSave: { name in
                    let preset = MeditationPreset(
                        id: UUID(),
                        name: name.isEmpty ? "My Meditation" : name,
                        durationMinutes: selectedDuration
                    )
                    saveUserPreset(preset)
                    showingPresetEditor = false
                }
            )
        }
    }
}

struct MeditationPresetEditor: View {
    @Binding var presetName: String
    let durationMinutes: Int
    let onCancel: () -> Void
    let onSave: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Preset Name")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    TextField("My Meditation", text: $presetName)
                }
                .padding(DesignSystem.Spacing.md)
                .cardStyle()

                Text("Duration: \(durationMinutes)m")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Meditation Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(presetName) }
                        .foregroundColor(DesignSystem.Colors.focusBlue)
                }
            }
        }
    }
}

struct MeditationTimerView: View {
    let duration: Int // minutes
    @State private var remainingTime: Int
    @State private var isActive: Bool = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @StateObject private var streakManager = StreakManager.shared
    @State private var showingAlertSettings = false
    @StateObject private var alertManager = AlertManager.shared
    @State private var showingCompletionSummary = false
    @State private var completionSummary = ""
    @State private var runtimeStatus = ""
    @State private var sessionStartDate: Date?
    @State private var sessionStartRemainingSeconds: Int = 0
    @State private var mindfulStartDate: Date?
    @State private var statusMessage: String?
    @StateObject private var heart = HeartRateManager()
    private let healthCoordinator = SessionHealthCoordinator()
    @Environment(\.presentationMode) var presentationMode

    private func startExtendedSession() {
        RuntimeSessionManager.shared.start()
    }

    private func stopExtendedSession() {
        RuntimeSessionManager.shared.stop()
    }

    private func saveMindfulSessionIfNeeded() {
        guard let start = mindfulStartDate else { return }
        HealthKitManager.shared.saveMindfulSession(start: start, end: Date())
        mindfulStartDate = nil
    }
    
    init(duration: Int) {
        self.duration = duration
        self._remainingTime = State(initialValue: duration * 60)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                VStack(spacing: 10) {
                    HStack(alignment: .center) {
                        Button(action: {
                            isActive = false
                            sessionStartDate = nil
                            saveMindfulSessionIfNeeded()
                            stopExtendedSession()
                            heart.stop()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(DesignSystem.Colors.cardBackgroundHighlight))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Close")

                        Spacer()

                        VStack(spacing: 0) {
                            Text("Meditation")
                                .font(DesignSystem.Typography.heading)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            HStack(spacing: 4) {
                                Text("\(duration)m")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                if streakManager.getCurrentStreak(for: .meditation) > 0 {
                                    Text("·")
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(DesignSystem.Colors.pauseOrange)
                                    Text("\(streakManager.getCurrentStreak(for: .meditation))")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }

                        Spacer()

                        Button(action: { showingAlertSettings = true }) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(DesignSystem.Colors.focusBlue))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Alerts")
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.top, 2)
                    
                    // Timer Display
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 4)
                            .frame(width: M.ringDiameter * 0.8, height: M.ringDiameter * 0.8)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                DesignSystem.Colors.focusPurple,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: M.ringDiameter * 0.8, height: M.ringDiameter * 0.8)
                            .animation(DesignSystem.Animation.progressTransition, value: progress)
                        
                        // Time display
                        VStack(spacing: 2) {
                            Text(formatTime(remainingTime))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("remaining")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .accessibilityFocusTimer(time: formatTime(remainingTime), isRunning: isActive)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, M.hPad)
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            if isActive {
                                isActive = false
                                sessionStartDate = nil
                                stopExtendedSession()
                                heart.stop()
                            } else {
                                runtimeStatus = ""
                                if remainingTime <= 0 {
                                    remainingTime = duration * 60
                                }
                                sessionStartRemainingSeconds = remainingTime
                                sessionStartDate = Date()
                                if mindfulStartDate == nil { mindfulStartDate = Date() }
                                isActive = true
                                startExtendedSession()
                                HealthKitManager.shared.requestAuthorizationIfNeeded { granted in
                                    DispatchQueue.main.async {
                                        statusMessage = granted ? nil : "Health access unavailable"
                                    }
                                }
                                heart.start(activityType: .mindAndBody)
                                healthCoordinator.captureBaseline()
                            }
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: isActive ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(isActive ? "Pause" : "Start")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(isActive ? DesignSystem.Colors.pauseOrange : DesignSystem.Colors.playGreen)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                    .animation(DesignSystem.Animation.phaseTransition, value: isActive)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("meditation-start-pause")
                        
                        Button(action: {
                            remainingTime = duration * 60
                            isActive = false
                            sessionStartDate = nil
                            saveMindfulSessionIfNeeded()
                            stopExtendedSession()
                            heart.stop()
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Stop")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.stopRed)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("meditation-stop")
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.bottom, 4)

                    if let effectiveStatus = statusMessage ?? (runtimeStatus.isEmpty ? nil : runtimeStatus) {
                        Text(effectiveStatus)
                            .font(DesignSystem.Typography.micro)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .opacity(0.85)
                            .padding(.horizontal, M.hPad)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
        }
        .onReceive(timer) { _ in
            if isActive, let start = sessionStartDate {
                let elapsed = max(0, Int(Date().timeIntervalSince(start)))
                let computed = max(0, sessionStartRemainingSeconds - elapsed)
                if computed != remainingTime {
                    remainingTime = computed
                }
            }

            if remainingTime <= 0 && isActive {
                let totalDuration = duration * 60
                isActive = false
                sessionStartDate = nil
                saveMindfulSessionIfNeeded()
                stopExtendedSession()
                heart.stop { aggregate in
                    healthCoordinator.finalize(aggregate: aggregate) { metrics in
                        StreakManager.shared.recordSession(.meditation, duration: totalDuration, metrics: metrics)
                    }
                }
                completionSummary = "\(duration)m meditation completed"
                showingCompletionSummary = true
            }
        }
        .sheet(isPresented: $showingAlertSettings) {
            AlertSettingsView()
        }
        .onAppear {
            LaunchStateStore.remember(.meditation)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidEnterBackground)) { _ in
            if isActive {
                startExtendedSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extendedRuntimeSessionDidInvalidateAppNotification)) { _ in
            if isActive {
                isActive = false
                sessionStartDate = nil
                saveMindfulSessionIfNeeded()
                heart.stop()
                runtimeStatus = "Session paused by system"
            }
        }
        .alert("Session Complete", isPresented: $showingCompletionSummary) {
            Button("Done", role: .cancel) { }
        } message: {
            Text(completionSummary)
        }
        .animation(DesignSystem.Animation.sheetTransition, value: showingCompletionSummary)
        .onDisappear {
            if !isActive {
                saveMindfulSessionIfNeeded()
                stopExtendedSession()
                heart.stop()
            }
        }
    }
    
    private var progress: Double {
        let totalSeconds = duration * 60
        return Double(totalSeconds - remainingTime) / Double(totalSeconds)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct MeditationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MeditationView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            MeditationView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
