import SwiftUI

struct LandingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var streakManager = StreakManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                let M = WatchMetrics.current(dynamicType: dynamicTypeSize)
                
                VStack(spacing: 16) {
                    Spacer()
                    
                    // App Title
                    Text("FocusCycle")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.bottom, 8)
                    
                    // Main Menu Buttons
                    VStack(spacing: 8) {
                        NavigationLink(destination: YogaTimerView()) {
                            MenuButtonWithStreak(
                                title: "Yoga",
                                icon: "figure.yoga",
                                color: DesignSystem.Colors.focusBlue,
                                streak: streakManager.getCurrentStreak(for: .yoga)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: PranayamaView()) {
                            MenuButtonWithStreak(
                                title: "Pranayama",
                                icon: "wind",
                                color: DesignSystem.Colors.playGreen,
                                streak: streakManager.getCurrentStreak(for: .pranayama)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink(destination: MeditationView()) {
                            MenuButtonWithStreak(
                                title: "Meditation",
                                icon: "brain.head.profile",
                                color: DesignSystem.Colors.focusPurple,
                                streak: streakManager.getCurrentStreak(for: .meditation)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, M.hPad)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
        }
    }
}

struct MenuButtonWithStreak: View {
    let title: String
    let icon: String
    let color: Color
    let streak: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                if streak > 0 {
                    Text("\(streak) day streak")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            if streak > 0 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.pauseOrange)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LandingView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            LandingView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
            LandingView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Ultra 2 (49mm)"))
        }
    }
}
