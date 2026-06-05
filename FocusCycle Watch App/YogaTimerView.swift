import SwiftUI
import WatchKit

struct YogaTimerView: View {
    var initiallyShowSettings: Bool = false
    @State var elapsedSeconds: Int = 0
    @State private var baseStartDate: Date? = nil
    @State private var accumulatedPausedSeconds: Int = 0
    @State var isTimerRunning: Bool = false
    @State private var showingSettings: Bool = false
    @StateObject private var heart = HeartRateManager()
    @StateObject private var prefs = YogaPreferences.shared
    // MARK: - App Mode
    @State private var operatingMode: OperatingMode = .multipleIntervals

    // MARK: - Single Interval Settings
    // Store single interval duration in seconds (10s increments)
    @State private var singleIntervalDurationSeconds: Int = 60
    @State private var singleIntervalSequenceDurationMinutes: Int = 30
    @State private var singleIntervalHaptic: AppHaptic = AppHaptic.notification

    // MARK: - Multiple Interval Settings
    @State private var multipleIntervals: [CustomIntervalSetting] = []
    // Interpreted as number of asanas (each asana = Hold + Rest)
    @State private var multipleIntervalsSequenceDurationMinutes: Int = 10
    // Asana slideshow assets to cycle while running
    @State var asanaImageNames: [String] = AsanaCatalog.names
    @State var currentAsanaIndex: Int = 0
    @State private var lastAsanaChangeSecond: Int = 0
    
    // Internal state
    @State private var lastHapticTriggerSecond: Int = -1
    @State private var mindfulStartDate: Date? = nil
    private let healthCoordinator = SessionHealthCoordinator()
    // Multiple interval sequencing (0 = Asana Hold, 1 = Rest)
    @State private var multiPhaseIndex: Int = 0
    @State private var multiPhaseStartElapsed: Int = 0
    @State private var hasPresentedInitialSettings = false
    @State private var completionSummary = ""
    @State private var showingCompletionSummary = false
    @State private var statusMessage: String?
    @State private var dismissAfterSummary = false

    private var hasProgress: Bool { isTimerRunning || elapsedSeconds > 0 }
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let asanaCycleIntervalSeconds: Int = 8
    
    // MARK: - Computed Properties
    private var currentIntervalProgress: Double {
        // Compute progress from elapsedSeconds regardless of running state so it "freezes" on pause
        if operatingMode == .singleInterval {
            let intervalSeconds = singleIntervalDurationSeconds
            guard intervalSeconds > 0 else { return 0 }
            return Double(elapsedSeconds % intervalSeconds) / Double(intervalSeconds)
        } else {
            // For multiple intervals, show progress of the soonest interval
            guard !multipleIntervals.isEmpty else { return 0 }
            var minProgress: Double = 1.0
            for interval in multipleIntervals {
                let intervalSeconds = interval.durationSeconds
                guard intervalSeconds > 0 else { continue }
                let progress = Double(elapsedSeconds % intervalSeconds) / Double(intervalSeconds)
                minProgress = min(minProgress, progress)
            }
            return minProgress
        }
    }
    
    private var sessionProgress: Double {
        if operatingMode == .singleInterval {
            let totalMinutes = singleIntervalSequenceDurationMinutes
            guard totalMinutes > 0 else { return 0 }
            return min(Double(elapsedSeconds) / Double(totalMinutes * 60), 1.0)
        } else {
            // Total session = asanaCount * (hold + rest)
            let asanaCount = multipleIntervalsSequenceDurationMinutes
            guard asanaCount > 0, multipleIntervals.count >= 1 else { return 0 }
            let hold = multipleIntervals.first?.durationSeconds ?? 0
            let rest = multipleIntervals.dropFirst().first?.durationSeconds ?? 0
            let cycle = max(1, hold + rest)
            let total = asanaCount * cycle
            return min(Double(elapsedSeconds) / Double(total), 1.0)
        }
    }
    
    private var nextIntervalIn: String? {
        if operatingMode == .singleInterval {
            let intervalSeconds = singleIntervalDurationSeconds
            guard intervalSeconds > 0 else { return nil }
            let secondsUntilNext = intervalSeconds - (elapsedSeconds % intervalSeconds)
            return formatTimeRemaining(secondsUntilNext)
        } else if operatingMode == .multipleIntervals, multipleIntervals.count >= 1 {
            let current = multipleIntervals[min(multiPhaseIndex, multipleIntervals.count - 1)]
            let phaseElapsed = max(0, elapsedSeconds - multiPhaseStartElapsed)
            let remaining = max(0, current.durationSeconds - phaseElapsed)
            return formatTimeRemaining(remaining)
        }
        return nil
    }
    
    private func formatTimeRemaining(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        }
    }
    
    private var singleIntervalSequenceDurationSeconds: Int { singleIntervalSequenceDurationMinutes * 60 }
    // Total session seconds for multiple = asanaCount * (hold + rest)
    private var multipleIntervalsSequenceDurationSeconds: Int {
        let asanaCount = multipleIntervalsSequenceDurationMinutes
        let hold = multipleIntervals.first?.durationSeconds ?? 0
        let rest = multipleIntervals.dropFirst().first?.durationSeconds ?? 0
        let cycle = max(1, hold + rest)
        return max(0, asanaCount) * cycle
    }
    
    // MARK: - Methods
    func startExtendedSession() { RuntimeSessionManager.shared.start() }
    
    func stopExtendedSession() { RuntimeSessionManager.shared.stop() }
    
    func toggleTimer() {
        withAnimation(DesignSystem.Animation.bounce) {
            isTimerRunning.toggle()
            if isTimerRunning {
                LaunchStateStore.remember(.yoga)
                if elapsedSeconds == 0 {
                    // Fresh start of a new session
                    lastHapticTriggerSecond = -1
                    // Initialize sequencing for multiple intervals only on a fresh start
                    if operatingMode == .multipleIntervals {
                        // Ensure exactly two phases exist: Hold and Rest
                        if multipleIntervals.count < 1 {
                            multipleIntervals.append(CustomIntervalSetting(durationSeconds: 60, haptic: .default))
                        }
                        if multipleIntervals.count < 2 {
                            multipleIntervals.append(CustomIntervalSetting(durationSeconds: 20, haptic: .default))
                        }
                        if multipleIntervals.count > 2 {
                            multipleIntervals = Array(multipleIntervals.prefix(2))
                        }
                        // Persist for complication hints
                        let hold = multipleIntervals.first?.durationSeconds ?? 0
                        let rest = multipleIntervals.dropFirst().first?.durationSeconds ?? 0
                        UserDefaults.standard.set(hold, forKey: "userHoldSeconds")
                        UserDefaults.standard.set(rest, forKey: "userRestSeconds")
                        UserDefaults.standard.set(multipleIntervalsSequenceDurationMinutes, forKey: "userAsanaCount")
                        multiPhaseIndex = 0
                        multiPhaseStartElapsed = 0
                    }
                }
                // Initialize timing anchors for wall-clock based elapsed computation
                if baseStartDate == nil { baseStartDate = Date() }
                // If resuming from pause, carry forward current elapsed as accumulated offset
                accumulatedPausedSeconds = elapsedSeconds
                if mindfulStartDate == nil { mindfulStartDate = Date() }
                // Begin asana slideshow timing
                lastAsanaChangeSecond = elapsedSeconds
                // Start extended runtime immediately; request HealthKit in parallel
                startExtendedSession()
                HealthKitManager.shared.requestAuthorizationIfNeeded { granted in
                    DispatchQueue.main.async {
                        statusMessage = granted ? nil : "Health access unavailable"
                    }
                }
                // Start live heart rate streaming
                heart.start(activityType: .yoga)
                healthCoordinator.captureBaseline()

            } else {
                // Pausing the timer should end extended runtime to save battery
                stopExtendedSession()
                // On pause, lock in the current elapsed as accumulated and clear base start date
                accumulatedPausedSeconds = elapsedSeconds
                baseStartDate = nil
                // Stop heart rate streaming when paused
                heart.stop()
                
            }
        }
    }
    
    func resetTimer() {
        endSession(showSummary: true)
    }

    /// Close (X) button: stop the timer, save any in-progress session, reset, and
    /// dismiss. No confirmation dialog — it conflicts with the other presentation
    /// modifiers inside a watchOS sheet and would silently fail to appear.
    private func closeSession() {
        if hasProgress {
            // Stops the timer, records the partial session, and resets state.
            endSession(showSummary: false)
        } else {
            if let start = mindfulStartDate {
                HealthKitManager.shared.saveMindfulSession(start: start, end: Date())
                mindfulStartDate = nil
            }
            stopExtendedSession()
        }
        presentationMode.wrappedValue.dismiss()
    }

    private func endSession(showSummary: Bool, dismissAfter: Bool = false) {
        withAnimation(DesignSystem.Animation.standard) {
            let completedSeconds = elapsedSeconds
            if let start = mindfulStartDate {
                HealthKitManager.shared.saveMindfulSession(start: start, end: Date())
                mindfulStartDate = nil
            }
            isTimerRunning = false
            elapsedSeconds = 0
            accumulatedPausedSeconds = 0
            baseStartDate = nil
            lastHapticTriggerSecond = -1
            stopExtendedSession()

            heart.stop { aggregate in
                guard completedSeconds > 0 else { return }
                healthCoordinator.finalize(aggregate: aggregate) { metrics in
                    StreakManager.shared.recordSession(.yoga, duration: completedSeconds, metrics: metrics)
                }
            }

            if showSummary && completedSeconds > 0 {
                let minutes = completedSeconds / 60
                let seconds = completedSeconds % 60
                completionSummary = minutes > 0 ? "\(minutes)m \(seconds)s completed" : "\(seconds)s completed"
                dismissAfterSummary = dismissAfter
                showingCompletionSummary = true
            }
        }
    }
    
    // MARK: - Body
    @Environment(\.dynamicTypeSize) private var dyn
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()

                let M = WatchMetrics.current(dynamicType: dyn)
                let controlSpacing = max(14, M.buttonSpacing)

                GeometryReader { geo in
                  let controlsH = min(64, max(44, M.buttonSize))
                  let available = geo.size.height
                  // Larger ring, biased toward the top of the screen while still
                  // guaranteeing room for the controls below it (no scrolling, so
                  // taps on the controls are never swallowed by a scroll gesture).
                  let R = max(96, min(available - (controlsH + 38), available * 0.60, 168))
                  let s = R / M.ringDiameter
                  VStack(spacing: 8) {
                    // Ring/sun hug the very top of the screen.
                    // Timer Display with Progress Ring
                    ZStack {
                        ProgressRing(
                            progress: sessionProgress,
                            lineWidth: M.outerLineWidth,
                            color: DesignSystem.Colors.focusPurple.opacity(0.7)
                        )
                        .frame(width: R, height: R)

                        Group {
                            if operatingMode == .singleInterval {
                                ProgressRing(
                                    progress: currentIntervalProgress,
                                    lineWidth: M.singleLineWidth,
                                    color: isTimerRunning ? DesignSystem.Colors.focusBlue : DesignSystem.Colors.textTertiary
                                )
                                .frame(width: M.innerSingleDiameter * s, height: M.innerSingleDiameter * s)
                            } else {
                                let colors: [Color] = [DesignSystem.Colors.focusBlue, DesignSystem.Colors.playGreen]
                                let baseSize: CGFloat = M.multiBaseDiameter * s
                                let step: CGFloat = M.multiStep * s
                                let intervals = Array(multipleIntervals.prefix(2))
                                ForEach(intervals.indices, id: \.self) { idx in
                                    let interval = intervals[idx]
                                    let intervalSeconds = max(1, interval.durationSeconds)
                                    let phaseElapsed = max(0, elapsedSeconds - multiPhaseStartElapsed)
                                    let isActive = idx == multiPhaseIndex
                                    let progress = isActive ? min(1.0, Double(phaseElapsed) / Double(intervalSeconds)) : 0
                                    ProgressRing(
                                        progress: progress,
                                        lineWidth: M.multiLineWidth,
                                        color: colors[min(idx, colors.count - 1)]
                                    )
                                    .frame(width: baseSize - CGFloat(idx) * step, height: baseSize - CGFloat(idx) * step)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, M.hPad)
                    .overlay(alignment: .center) {
                        Button(action: { showingSettings = true }) {
                            Image("Sun1")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: R * 0.46, height: R * 0.46)
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Opens app settings")
                        .buttonStyle(PlainButtonStyle())
                        .zIndex(100)
                    }

                    // Push the ring/sun toward the top; keep controls lower.
                    Spacer(minLength: 6)

                    // Controls with proper spacing
                    VStack(spacing: 10) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: controlSpacing) {
                                controlsPlayButton(buttonSize: controlsH, scale: 1.0, R: R)
                                controlsResetButton(buttonSize: controlsH, scale: 1.0, R: R)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 10) {
                                controlsPlayButton(buttonSize: controlsH, scale: 1.0, R: R)
                                controlsResetButton(buttonSize: controlsH, scale: 1.0, R: R)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, M.hPad)

                    if let effectiveStatus = statusMessage ?? (!heart.statusText.isEmpty ? heart.statusText : nil) {
                        Text(effectiveStatus)
                            .font(DesignSystem.Typography.micro)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, M.hPad)
                    }

                    Spacer().frame(height: 4)
                    }
                    .frame(width: geo.size.width, height: available, alignment: .top)
                }

                // Floating close button — overlay so it doesn't displace timer layout.
                Button {
                    closeSession()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Close")
                .padding(.leading, 6)
                .padding(.top, 4)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                operatingMode: $operatingMode,
                singleIntervalDurationSeconds: $singleIntervalDurationSeconds,
                singleIntervalSequenceDurationMinutes: $singleIntervalSequenceDurationMinutes,
                singleIntervalHaptic: $singleIntervalHaptic,
                multipleIntervals: $multipleIntervals,
                multipleIntervalsSequenceDurationMinutes: $multipleIntervalsSequenceDurationMinutes
            )
            .environmentObject(heart)
        }
        .onAppear {
            LaunchStateStore.remember(.yoga)
            // Seed local state from the shared preferences store the first time the
            // timer appears so customizations made elsewhere are picked up.
            operatingMode = prefs.operatingMode
            singleIntervalDurationSeconds = prefs.singleIntervalDurationSeconds
            singleIntervalSequenceDurationMinutes = prefs.singleIntervalSequenceDurationMinutes
            multipleIntervalsSequenceDurationMinutes = prefs.asanaCount
            multipleIntervals = prefs.makeIntervals()
            if initiallyShowSettings && !hasPresentedInitialSettings {
                hasPresentedInitialSettings = true
                showingSettings = true
            }
        }
        .onChange(of: operatingMode) { _, new in prefs.operatingMode = new }
        .onChange(of: singleIntervalDurationSeconds) { _, new in prefs.singleIntervalDurationSeconds = new }
        .onChange(of: singleIntervalSequenceDurationMinutes) { _, new in prefs.singleIntervalSequenceDurationMinutes = new }
        .onChange(of: multipleIntervalsSequenceDurationMinutes) { _, new in prefs.asanaCount = new }
        .onChange(of: multipleIntervals) { _, new in prefs.updateIntervals(new) }
        .alert("Session Complete", isPresented: $showingCompletionSummary) {
            Button("Done", role: .cancel) {
                if dismissAfterSummary {
                    dismissAfterSummary = false
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(completionSummary)
        }
        .animation(DesignSystem.Animation.sheetTransition, value: showingCompletionSummary)
        .onReceive(timer) { _ in
            guard isTimerRunning else { return }
            let previous = elapsedSeconds
            // Compute elapsed from wall-clock time to avoid drift or pause during sleep
            if let start = baseStartDate {
                let computed = max(0, accumulatedPausedSeconds + Int(Date().timeIntervalSince(start)))
                if computed != elapsedSeconds {
                    elapsedSeconds = computed
                }
            }

            // Advance asana image at a steady cadence, catch up if needed
            if isTimerRunning && !asanaImageNames.isEmpty {
                while (elapsedSeconds - lastAsanaChangeSecond) >= asanaCycleIntervalSeconds {
                    currentAsanaIndex = (currentAsanaIndex + 1) % asanaImageNames.count
                    lastAsanaChangeSecond += asanaCycleIntervalSeconds
                }
            }

            // End of overall session
            let currentOverallSequenceDurationSeconds: Int = (operatingMode == .singleInterval) ?
                singleIntervalSequenceDurationSeconds : multipleIntervalsSequenceDurationSeconds

            if currentOverallSequenceDurationSeconds > 0 && elapsedSeconds >= currentOverallSequenceDurationSeconds {
                endSession(showSummary: true, dismissAfter: true)
                return
            }

            // Haptics / phase changes with catch-up logic
            if operatingMode == .singleInterval {
                let interval = singleIntervalDurationSeconds
                guard interval > 0 else { return }
                // Trigger when we cross a boundary even if we skipped seconds
                if elapsedSeconds > 0 && (elapsedSeconds / interval) > (previous / interval) {
                    if elapsedSeconds != lastHapticTriggerSecond {
                        WKInterfaceDevice.current().play(singleIntervalHaptic.type)
                        lastHapticTriggerSecond = elapsedSeconds
                    }
                }
            } else if operatingMode == .multipleIntervals {
                guard !multipleIntervals.isEmpty else { return }
                // Advance through phases if we crossed one or more boundaries
                var newIndex = multiPhaseIndex
                var newPhaseStart = multiPhaseStartElapsed
                var advanced = 0
                let maxPhases = min(2, max(1, multipleIntervals.count))
                while true {
                    let current = multipleIntervals[min(newIndex, multipleIntervals.count - 1)]
                    let currentDuration = max(1, current.durationSeconds)
                    let phaseElapsed = max(0, elapsedSeconds - newPhaseStart)
                    if phaseElapsed >= currentDuration {
                        newIndex = (newIndex + 1) % maxPhases
                        newPhaseStart += currentDuration
                        advanced += 1
                        continue
                    }
                    break
                }
                if advanced > 0 {
                    multiPhaseIndex = newIndex
                    multiPhaseStartElapsed = newPhaseStart
                    let newPhase = multipleIntervals[min(multiPhaseIndex, multipleIntervals.count - 1)]
                    WKInterfaceDevice.current().play(newPhase.haptic.type)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extendedRuntimeSessionDidInvalidateAppNotification)) { _ in
            // Extended runtime ended by the system; pause UI and timer anchors safely.
            if isTimerRunning {
                isTimerRunning = false
                accumulatedPausedSeconds = elapsedSeconds
                baseStartDate = nil
                heart.stop()
                statusMessage = "Session paused by system"
            }
            // Save mindful session if started
            if let start = mindfulStartDate {
                HealthKitManager.shared.saveMindfulSession(start: start, end: Date())
                mindfulStartDate = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidEnterBackground)) { _ in
            // Ensure extended runtime is active when going to background
            if isTimerRunning {
                startExtendedSession()
            }
        }
        // Prevent an accidental swipe (e.g. a slight drag while tapping pause)
        // from dismissing the session. The X button dismisses programmatically.
        .interactiveDismissDisabled(true)
    }
}

// MARK: - Control Buttons Extension
extension YogaTimerView {
    @ViewBuilder
    func controlsPlayButton(buttonSize: CGFloat, scale: CGFloat, R: CGFloat) -> some View {
        Button(action: toggleTimer) {
            ZStack {
                Circle()
                    .fill(isTimerRunning ? DesignSystem.Colors.pauseOrange : DesignSystem.Colors.playGreen)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.3), lineWidth: max(1, 2 * scale))
                    )
                    .animation(DesignSystem.Animation.phaseTransition, value: isTimerRunning)
                if isTimerRunning {
                    AnyView(
                        ZStack {
                            Image(asanaImageNames[min(currentAsanaIndex, max(0, asanaImageNames.count-1))])
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                // Conservative icon sizing to prevent overflow
                                .frame(width: max(40, min(60, R * 0.35)), height: max(40, min(60, R * 0.35)))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.6), radius: 1.5, x: 0, y: 0)
                        }
                    )
                } else {
                    AnyView(
                        ZStack {
                            Image("Vrikshasana")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: max(40, min(60, R * 0.35)), height: max(40, min(60, R * 0.35)))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.6), radius: 1.5, x: 0, y: 0)
                        }
                    )
                }
            }
            // Always show a clear play/pause glyph so the control's function is
            // obvious even while the asana artwork is animating.
            .overlay(alignment: .bottom) {
                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color.black.opacity(0.4)))
                    .padding(.bottom, 2)
            }
        }
        .accessibilityLabel(isTimerRunning ? "Pause timer" : "Start timer")
        .accessibilityHint(isTimerRunning ? "Pauses the current session" : "Starts the focus session")
        .accessibilityIdentifier("yoga-start-pause")
        .buttonStyle(PlainButtonStyle())
        .animation(DesignSystem.Animation.phaseTransition, value: isTimerRunning)
    }

    @ViewBuilder
    func controlsResetButton(buttonSize: CGFloat, scale: CGFloat, R: CGFloat) -> some View {
        Button(action: resetTimer) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.stopRed.opacity(elapsedSeconds > 0 ? 1 : 0.3))
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.3), lineWidth: max(1, 2 * scale))
                    )
                    .animation(DesignSystem.Animation.phaseTransition, value: elapsedSeconds)
                ZStack {
                    Image("Padmasana")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        // Conservative reset icon sizing
                        .frame(width: max(36, min(54, R * 0.32)), height: max(36, min(54, R * 0.32)))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.6), radius: 1.5, x: 0, y: 0)
                }
            }
            .overlay(alignment: .bottom) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color.black.opacity(0.4)))
                    .padding(.bottom, 2)
            }
        }
        .accessibilityLabel("Reset timer")
        .accessibilityHint("Resets the session and saves mindful minutes")
        .accessibilityIdentifier("yoga-stop-reset")
        .buttonStyle(PlainButtonStyle())
        .disabled(elapsedSeconds == 0 && !isTimerRunning)
    }
}

struct YogaTimerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            YogaTimerView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            YogaTimerView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
            YogaTimerView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Ultra 2 (49mm)"))
        }
    }
}
