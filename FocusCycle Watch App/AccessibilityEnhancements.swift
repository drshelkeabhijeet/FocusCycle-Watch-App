import SwiftUI
import WatchKit

// MARK: - Accessibility Extensions
extension View {
    func accessibilityFocusTimer(time: String, isRunning: Bool) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Focus timer")
            .accessibilityValue("\(time), \(isRunning ? "running" : "paused")")
            .accessibilityAddTraits(isRunning ? .updatesFrequently : [])
    }
    
    func accessibilityProgressRing(progress: Double, label: String) -> some View {
        self
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(progress * 100))% complete")
    }
    
    func accessibilityControlButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(hint ?? "")
    }
    
    func accessibilityHapticOption(name: String, priority: Int, isSelected: Bool) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(name) haptic, priority \(priority)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap to select and preview")
    }
    
    func accessibilityIntervalSetting(title: String, value: Int, unit: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue("\(value) \(unit)")
            .accessibilityAdjustableAction { direction in
                // This would be implemented in the actual stepper component
            }
    }
}

// MARK: - Accessibility Announcements
struct AccessibilityAnnouncer {
    static func announceIntervalComplete(hapticName: String) {
        post("Interval complete. \(hapticName) alert played.")
    }

    static func announceTimerStateChange(isRunning: Bool) {
        post(isRunning ? "Timer started" : "Timer paused")
    }

    static func announceTimerReset() {
        post("Timer reset")
    }

    static func announceModeChange(mode: OperatingMode) {
        post("Switched to \(mode.displayName) mode")
    }

    private static func post(_ message: String) {
        if #available(watchOS 10.0, *) {
            SwiftUI.AccessibilityNotification.Announcement(message).post()
        }
    }
}

// MARK: - High Contrast Support
struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    func body(content: Content) -> some View {
        content
            .environment(\.isHighContrast, colorSchemeContrast == .increased)
            .environment(\.reduceTransparency, reduceTransparency)
    }
}

// MARK: - Environment Keys
private struct HighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ReduceTransparencyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isHighContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
    
    var reduceTransparency: Bool {
        get { self[ReduceTransparencyKey.self] }
        set { self[ReduceTransparencyKey.self] = newValue }
    }
}

// MARK: - Accessible Design System Colors
extension DesignSystem.Colors {
    static func adaptiveBackground(reduceTransparency: Bool) -> Color {
        reduceTransparency ? Color.black : Color(white: 0.05)
    }
    
    static func adaptiveCard(reduceTransparency: Bool, isHighContrast: Bool) -> Color {
        if reduceTransparency {
            return isHighContrast ? Color(white: 0.2) : cardBackground
        }
        return cardBackground.opacity(0.95)
    }
    
    static func adaptiveText(level: TextLevel, isHighContrast: Bool) -> Color {
        switch level {
        case .primary:
            return textPrimary
        case .secondary:
            return isHighContrast ? textPrimary.opacity(0.9) : textSecondary
        case .tertiary:
            return isHighContrast ? textSecondary : textTertiary
        }
    }
    
    enum TextLevel {
        case primary, secondary, tertiary
    }
}

// MARK: - Haptic Feedback Manager
class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    @AppStorage("hapticFeedbackEnabled") private var isEnabled = true
    @AppStorage("hapticIntensity") private var intensity: Double = 1.0
    
    func playHaptic(_ type: WKHapticType) {
        guard isEnabled else { return }
        
        #if os(watchOS)
        WKInterfaceDevice.current().play(type)
        #endif
    }
    
    func playCustomHaptic(pattern: [Double]) {
        guard isEnabled else { return }
        
        // Custom haptic implementation would go here
        // This is a placeholder for more complex haptic patterns
    }
}