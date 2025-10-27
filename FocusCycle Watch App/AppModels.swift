import Foundation
import WatchKit // Required for WKHapticType

// Enum for the operating mode of the app
enum OperatingMode: String, CaseIterable, Identifiable {
    case singleInterval = "Single"
    case multipleIntervals = "Multiple"
    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .singleInterval:
            return "Single Interval"
        case .multipleIntervals:
            return "Multiple Intervals"
        }
    }
}

// Wrapper for WKHapticType to make it Identifiable and provide display names and priority
struct AppHaptic: Identifiable, Hashable, Equatable {
    let name: String // User-facing name
    let type: WKHapticType
    let priority: Int // Higher number means higher priority
    var id: String { name }

    // Define static instances with priorities
    static let click = AppHaptic(name: "Click", type: .click, priority: 1) // Lowest
    static let retry = AppHaptic(name: "Retry", type: .retry, priority: 2)
    static let notification = AppHaptic(name: "Notification", type: .notification, priority: 3)
    static let directionUp = AppHaptic(name: "Direction Up", type: .directionUp, priority: 3)
    static let directionDown = AppHaptic(name: "Direction Down", type: .directionDown, priority: 3)
    static let start = AppHaptic(name: "Start", type: .start, priority: 4)
    static let success = AppHaptic(name: "Success", type: .success, priority: 4)
    static let stop = AppHaptic(name: "Stop", type: .stop, priority: 5) // Highest
    static let failure = AppHaptic(name: "Failure", type: .failure, priority: 5) // Highest
    

    static let all: [AppHaptic] = [
        // Intentionally ordered here from highest to lowest priority for potential UI sorting
        // The logic itself will find the max priority regardless of this array's order.
        failure,
        stop,
        success,
        start,
        notification,
        directionUp,
        directionDown,
        retry,
        click
    ]

    // Default haptic
    static let `default`: AppHaptic = notification
}

// Struct for defining a single custom interval in Multiple Interval Mode
struct CustomIntervalSetting: Identifiable, Hashable, Equatable {
    var id = UUID()
    var durationSeconds: Int = 60 // default 1 minute
    var haptic: AppHaptic = AppHaptic.default // Will use the default haptic which now has priority
}
