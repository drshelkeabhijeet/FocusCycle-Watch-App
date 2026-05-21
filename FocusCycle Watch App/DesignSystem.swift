import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary brand colors with semantic meaning
        static let focusBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
        static let focusIndigo = Color(red: 0.345, green: 0.337, blue: 0.839)
        static let focusPurple = Color(red: 0.686, green: 0.321, blue: 0.871)
        
        // Gradient for visual interest
        static let focusGradient = LinearGradient(
            colors: [focusBlue, focusIndigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let backgroundGradient = LinearGradient(
            colors: [Color.black, Color(white: 0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Semantic colors
        static let playGreen = Color(red: 0.0, green: 0.875, blue: 0.416)
        static let pauseOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
        static let stopRed = Color(red: 1.0, green: 0.231, blue: 0.188)
        
        // Surface colors
        static let cardBackground = Color(white: 0.15)
        static let cardBackgroundHighlight = Color(white: 0.2)
        static let textPrimary = Color.white
        static let textSecondary = Color(white: 0.7)
        static let textTertiary = Color(white: 0.5)

        static func timerStateColor(isRunning: Bool, isPaused: Bool = false) -> Color {
            if isRunning { return playGreen }
            if isPaused { return pauseOrange }
            return textTertiary
        }
    }
    
    // MARK: - Typography
    struct Typography {
        static let heroTitle = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let largeTimer = Font.system(size: 52, weight: .medium, design: .rounded)
        static let mediumTimer = Font.system(size: 42, weight: .medium, design: .rounded)
        static let heading = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let subheading = Font.system(size: 17, weight: .medium, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 10, weight: .medium, design: .rounded)
        static let micro = Font.system(size: 9, weight: .medium, design: .rounded)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let xsPlus: CGFloat = 6
        static let sm: CGFloat = 8
        static let smPlus: CGFloat = 10
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let bounce = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let phaseTransition = SwiftUI.Animation.spring(response: 0.34, dampingFraction: 0.8)
        static let progressTransition = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let sheetTransition = SwiftUI.Animation.easeInOut(duration: 0.28)
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let circular: CGFloat = 100
    }
}

// MARK: - Custom View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    var isHighlighted: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(isHighlighted ? DesignSystem.Colors.cardBackgroundHighlight : DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .strokeBorder(
                                isLuminanceReduced ? Color.clear : Color.white.opacity(0.14),
                                lineWidth: 1
                            )
                    )
            )
    }
}

extension View {
    func cardStyle(isHighlighted: Bool = false) -> some View {
        modifier(CardStyle(isHighlighted: isHighlighted))
    }
}

// MARK: - Progress Ring Component
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    var color: Color = DesignSystem.Colors.focusBlue
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.7), color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.progressTransition, value: progress)
        }
    }
}

// MARK: - Haptic Icon View
struct HapticIconView: View {
    let hapticType: String
    var size: CGFloat = 24
    
    var iconName: String {
        switch hapticType.lowercased() {
        case "click": return "hand.tap.fill"
        case "notification": return "bell.fill"
        case "success": return "checkmark.circle.fill"
        case "failure": return "xmark.circle.fill"
        case "start": return "play.circle.fill"
        case "stop": return "stop.circle.fill"
        case "retry": return "arrow.clockwise.circle.fill"
        case "direction up": return "arrow.up.circle.fill"
        case "direction down": return "arrow.down.circle.fill"
        default: return "waveform.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch hapticType.lowercased() {
        case "success", "start": return DesignSystem.Colors.playGreen
        case "failure", "stop": return DesignSystem.Colors.stopRed
        case "notification": return DesignSystem.Colors.focusBlue
        default: return DesignSystem.Colors.textSecondary
        }
    }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size))
            .foregroundColor(iconColor)
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - Animated Button Style
struct AnimatedButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var foregroundColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}