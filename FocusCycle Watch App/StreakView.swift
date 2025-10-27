import SwiftUI

struct StreakView: View {
    let activityType: ActivityType
    @StateObject private var streakManager = StreakManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var streakData: StreakData {
        streakManager.getStreakData(for: activityType)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: .medium)
                
                ScrollView {
                    VStack(spacing: 8) {
                        // Header
                        HStack {
                            Button("Close") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            Text("\(activityType.displayName) Streak")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text("")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, M.hPad)
                        .padding(.top, 2)
                        
                        // Current Streak
                        VStack(spacing: 4) {
                            Text("Current Streak")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Text("\(streakData.currentStreak)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.focusBlue)
                            
                            Text("days")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.vertical, 4)
                        
                        // Stats Grid
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                StatCard(
                                    title: "Longest",
                                    value: "\(streakData.longestStreak)",
                                    subtitle: "days",
                                    color: DesignSystem.Colors.focusPurple
                                )
                                
                                StatCard(
                                    title: "Total",
                                    value: "\(streakData.totalSessions)",
                                    subtitle: "sessions",
                                    color: DesignSystem.Colors.playGreen
                                )
                            }
                            
                            HStack(spacing: 8) {
                                StatCard(
                                    title: "Minutes",
                                    value: "\(streakManager.getTotalMinutes(for: activityType))",
                                    subtitle: "total",
                                    color: DesignSystem.Colors.pauseOrange
                                )
                                
                                StatCard(
                                    title: "Avg",
                                    value: "\(streakManager.getAverageSessionDuration(for: activityType) / 60)",
                                    subtitle: "min",
                                    color: DesignSystem.Colors.focusBlue
                                )
                            }
                        }
                        .padding(.horizontal, M.hPad)
                        
                        // Recent Sessions
                        if !streakData.sessions.isEmpty {
                            VStack(spacing: 4) {
                                Text("Recent Sessions")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(.top, 4)
                                
                                ForEach(streakManager.getRecentSessions(for: activityType, limit: 5)) { session in
                                    SessionRow(session: session)
                                }
                            }
                            .padding(.horizontal, M.hPad)
                        }
                        
                        Spacer(minLength: 4)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct SessionRow: View {
    let session: SessionRecord
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: activityIcon)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(activityColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(dateText)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                if let pattern = session.pattern {
                    Text(pattern.capitalized)
                        .font(.system(size: 6, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            Text(durationText)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.Colors.cardBackground.opacity(0.5))
        )
    }
    
    private var activityIcon: String {
        switch session.activityType {
        case .yoga: return "figure.yoga"
        case .pranayama: return "wind"
        case .meditation: return "brain.head.profile"
        }
    }
    
    private var activityColor: Color {
        switch session.activityType {
        case .yoga: return DesignSystem.Colors.focusBlue
        case .pranayama: return DesignSystem.Colors.playGreen
        case .meditation: return DesignSystem.Colors.focusPurple
        }
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(session.date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(session.date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: session.date)
        }
    }
    
    private var durationText: String {
        let minutes = session.duration / 60
        let seconds = session.duration % 60
        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

struct StreakView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StreakView(activityType: .yoga)
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            StreakView(activityType: .pranayama)
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
        }
    }
}
