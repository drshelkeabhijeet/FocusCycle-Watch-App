import SwiftUI

struct PranayamaTimerView: View {
    let pattern: PranayamaPattern
    @StateObject private var session: PranayamaSession
    @State private var showingSettings = false
    @State private var showingAlertSettings = false
    @State private var showingPhaseAlertSettings = false
    @StateObject private var alertManager = AlertManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // MARK: - Extended Runtime Session Management
    private func startExtendedSession() {
        RuntimeSessionManager.shared.start()
    }
    
    private func stopExtendedSession() {
        RuntimeSessionManager.shared.stop()
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
                
                VStack(spacing: 4) {
                    // Header
                    HStack {
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text(pattern.type.displayName)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        VStack(spacing: 1) {
                            Text("\(session.currentCycle)/\(pattern.cycles)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    showingAlertSettings = true
                                }) {
                                    VStack(spacing: 1) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text("Alert")
                                            .font(.system(size: 6, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(DesignSystem.Colors.focusBlue)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    showingPhaseAlertSettings = true
                                }) {
                                    VStack(spacing: 1) {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text("Phase")
                                            .font(.system(size: 6, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(DesignSystem.Colors.playGreen)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
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
                            .animation(.easeInOut(duration: 0.5), value: breathingSize)
                        
                        // Phase indicator
                        VStack(spacing: 2) {
                            Text(session.currentPhase.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("\(Int(session.phaseProgress * 100))%")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, M.hPad)
                    
                    // Time remaining
                    HStack {
                        Text("Time")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(formatTime(session.remainingTime))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, M.hPad)
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            print("Start/Pause button pressed")
                            if session.isActive {
                                session.pause()
                                stopExtendedSession()
                            } else {
                                session.start()
                                startExtendedSession()
                            }
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: session.isActive ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(session.isActive ? "Pause" : "Start")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
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
                            )
                        }
                        .buttonStyle(.plain)
                        .onTapGesture {
                            print("Tap gesture triggered")
                            if session.isActive {
                                session.pause()
                                stopExtendedSession()
                            } else {
                                session.start()
                                startExtendedSession()
                            }
                        }
                        
                        Button(action: {
                            print("Stop button pressed")
                            session.reset()
                            stopExtendedSession()
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Stop")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
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
                        .onTapGesture {
                            print("Stop tap gesture triggered")
                            session.reset()
                        }
                    }
                    .padding(.horizontal, M.hPad)
                    .padding(.bottom, 4)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            PranayamaSettingsView()
        }
        .sheet(isPresented: $showingAlertSettings) {
            AlertSettingsView()
        }
        .sheet(isPresented: $showingPhaseAlertSettings) {
            PhaseAlertSettingsView()
        }
        .onReceive(timer) { _ in
            guard session.isActive else { return }
            session.updateProgress()
            
            // Auto-dismiss when session completes
            if session.remainingTime <= 0 {
                // Record session for streak tracking
                let totalDuration = pattern.totalDuration
                StreakManager.shared.recordSession(.pranayama, duration: totalDuration, pattern: pattern.type.rawValue)
                
                session.reset()
                stopExtendedSession()
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidEnterBackground)) { _ in
            // Ensure extended runtime is active when going to background
            if session.isActive {
                startExtendedSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extendedRuntimeSessionDidInvalidateAppNotification)) { _ in
            // Handle extended runtime session invalidation
            if session.isActive {
                // Try to restart the session
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startExtendedSession()
                }
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
