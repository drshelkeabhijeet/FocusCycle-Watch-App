import SwiftUI

struct PranayamaTimerView: View {
    let pattern: PranayamaPattern
    @StateObject private var session: PranayamaSession
    @State private var showingAlertSettings = false
    @StateObject private var alertManager = AlertManager.shared
    @State private var showingCompletionSummary = false
    @State private var completionSummary = ""
    @State private var runtimeStatus = ""
    @State private var statusMessage: String?
    @State private var mindfulStartDate: Date?
    @StateObject private var heart = HeartRateManager()
    private let healthCoordinator = SessionHealthCoordinator()
    @Environment(\.presentationMode) var presentationMode
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // MARK: - Extended Runtime Session Management
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
    
    init(pattern: PranayamaPattern) {
        self.pattern = pattern
        self._session = StateObject(wrappedValue: PranayamaSession(pattern: pattern))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                VStack(spacing: 6) {
                    // Header
                    HStack(alignment: .center) {
                        Button(action: {
                            session.reset()
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
                            Text(pattern.type.displayName)
                                .font(DesignSystem.Typography.heading)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("\(session.currentCycle)/\(pattern.cycles)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
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
                    
                    // Breathing Visualization
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 2)
                            .frame(width: M.ringDiameter * 0.6, height: M.ringDiameter * 0.6)
                        
                        // Breathing circle that expands/contracts
                        Circle()
                            .fill(phaseColor.opacity(0.6))
                            .frame(
                                width: breathingSize * 0.6,
                                height: breathingSize * 0.6
                            )
                            .animation(DesignSystem.Animation.phaseTransition, value: breathingSize)
                        
                        // Phase indicator
                        VStack(spacing: 2) {
                            Text(session.currentPhase.displayName)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("\(Int(session.phaseProgress * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Breathing phase")
                        .accessibilityValue("\(session.currentPhase.displayName), \(Int(session.phaseProgress * 100)) percent")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, M.hPad)
                    
                    // Time remaining
                    HStack {
                        Text("Time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(formatTime(session.remainingTime))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, M.hPad)
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            if session.isActive {
                                session.pause()
                                stopExtendedSession()
                                heart.stop()
                            } else {
                                runtimeStatus = ""
                                session.start()
                                if mindfulStartDate == nil { mindfulStartDate = Date() }
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
                                Image(systemName: session.isActive ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(session.isActive ? "Pause" : "Start")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(session.isActive ? DesignSystem.Colors.pauseOrange : DesignSystem.Colors.playGreen)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                    .animation(DesignSystem.Animation.phaseTransition, value: session.isActive)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("pranayama-start-pause")
                        
                        Button(action: {
                            session.reset()
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
                        .accessibilityIdentifier("pranayama-stop")
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
        .sheet(isPresented: $showingAlertSettings) {
            AlertSettingsView()
        }
        .onReceive(timer) { _ in
            guard session.isActive else { return }
            session.updateProgress()

            if session.remainingTime <= 0 {
                let totalDuration = pattern.totalDuration
                let patternRaw = pattern.type.rawValue
                session.reset()
                saveMindfulSessionIfNeeded()
                stopExtendedSession()
                heart.stop { aggregate in
                    healthCoordinator.finalize(aggregate: aggregate) { metrics in
                        StreakManager.shared.recordSession(.pranayama, duration: totalDuration, pattern: patternRaw, metrics: metrics)
                    }
                }
                completionSummary = "\(pattern.type.displayName) finished"
                showingCompletionSummary = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidEnterBackground)) { _ in
            if session.isActive {
                startExtendedSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extendedRuntimeSessionDidInvalidateAppNotification)) { _ in
            if session.isActive {
                session.pause()
                saveMindfulSessionIfNeeded()
                heart.stop()
                runtimeStatus = "Session paused by system"
            }
        }
        .onAppear {
            LaunchStateStore.remember(.pranayama)
            LaunchStateStore.rememberPranayamaType(pattern.type.rawValue)
        }
        .alert("Session Complete", isPresented: $showingCompletionSummary) {
            Button("Done", role: .cancel) { }
        } message: {
            Text(completionSummary)
        }
        .animation(DesignSystem.Animation.sheetTransition, value: showingCompletionSummary)
        .onDisappear {
            if !session.isActive {
                saveMindfulSessionIfNeeded()
                stopExtendedSession()
                heart.stop()
            }
        }
    }
    
    private var phaseColor: Color {
        switch session.currentPhase {
        case .inhale:
            return DesignSystem.Colors.focusBlue
        case .hold1, .hold2:
            return DesignSystem.Colors.pauseOrange
        case .exhale:
            return DesignSystem.Colors.playGreen
        }
    }
    
    private var breathingSize: CGFloat {
        let M = WatchMetrics.current(dynamicType: .medium)
        let baseSize: CGFloat = 30
        let maxSize: CGFloat = M.ringDiameter * 0.4
        
        switch session.currentPhase {
        case .inhale:
            return baseSize + (maxSize - baseSize) * session.phaseProgress
        case .hold1, .hold2:
            return maxSize
        case .exhale:
            return maxSize - (maxSize - baseSize) * session.phaseProgress
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct PranayamaTimerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PranayamaTimerView(pattern: PranayamaPattern(
                type: .anulom,
                inhaleDuration: 4,
                hold1Duration: 4,
                exhaleDuration: 4,
                hold2Duration: 4,
                cycles: 10
            ))
            .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            PranayamaTimerView(pattern: PranayamaPattern(
                type: .ujjayi,
                inhaleDuration: 6,
                hold1Duration: 2,
                exhaleDuration: 6,
                hold2Duration: 2,
                cycles: 8
            ))
            .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
