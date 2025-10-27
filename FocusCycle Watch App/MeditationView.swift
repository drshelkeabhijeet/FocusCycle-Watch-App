import SwiftUI

struct MeditationView: View {
    @State private var selectedDuration: Int = 10 // minutes
    @State private var showingTimer = false
    
    let durations = [5, 10, 15, 20, 30, 45, 60]
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                VStack(spacing: 16) {
                    Spacer()
                    
                    // Title
                    Text("Meditation")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    // Duration Selection
                    VStack(spacing: 8) {
                        Text("Duration")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 8) {
                            ForEach(durations, id: \.self) { duration in
                                Button(action: {
                                    selectedDuration = duration
                                }) {
                                    Text("\(duration)m")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(selectedDuration == duration ? .white : DesignSystem.Colors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedDuration == duration ? DesignSystem.Colors.focusPurple : DesignSystem.Colors.cardBackground)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, M.hPad)
                    
                    // Start Button
                    Button(action: {
                        showingTimer = true
                    }) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 16, weight: .medium))
                            Text("Start Meditation")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignSystem.Colors.focusPurple)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingTimer) {
            MeditationTimerView(duration: selectedDuration)
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
    @Environment(\.presentationMode) var presentationMode
    
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
                
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        VStack(spacing: 1) {
                            Text("Meditation")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("\(duration)m")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 1) {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.pauseOrange)
                                
                                Text("\(streakManager.getCurrentStreak(for: .meditation))")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
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
                        }
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
                        
                        // Time display
                        VStack(spacing: 2) {
                            Text(formatTime(remainingTime))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("remaining")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, M.hPad)
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            print("Meditation Start/Pause button pressed")
                            isActive.toggle()
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: isActive ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(isActive ? "Pause" : "Start")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
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
                            )
                        }
                        .buttonStyle(.plain)
                        .onTapGesture {
                            print("Meditation tap gesture triggered")
                            isActive.toggle()
                        }
                        
                        Button(action: {
                            print("Meditation Stop button pressed")
                            remainingTime = duration * 60
                            isActive = false
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
                            print("Meditation Stop tap gesture triggered")
                            remainingTime = duration * 60
                            isActive = false
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
        .onReceive(timer) { _ in
            if isActive && remainingTime > 0 {
                remainingTime -= 1
            } else if remainingTime <= 0 && isActive {
                // Record session for streak tracking
                let totalDuration = duration * 60
                StreakManager.shared.recordSession(.meditation, duration: totalDuration)
                
                isActive = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .sheet(isPresented: $showingAlertSettings) {
            AlertSettingsView()
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
