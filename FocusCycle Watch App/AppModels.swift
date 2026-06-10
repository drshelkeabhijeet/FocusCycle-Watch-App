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

enum LaunchPractice: String {
    case yoga
    case pranayama
    case meditation

    var displayName: String {
        switch self {
        case .yoga: return "Yoga"
        case .pranayama: return "Pranayama"
        case .meditation: return "Meditation"
        }
    }
}

enum LaunchStateStore {
    private static let practiceKey = "FocusCycle_LastLaunchPractice"
    private static let pranayamaKey = "FocusCycle_LastPranayamaType"

    static func remember(_ practice: LaunchPractice) {
        UserDefaults.standard.set(practice.rawValue, forKey: practiceKey)
    }

    static func lastPractice() -> LaunchPractice? {
        guard let raw = UserDefaults.standard.string(forKey: practiceKey) else { return nil }
        return LaunchPractice(rawValue: raw)
    }

    static func rememberPranayamaType(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: pranayamaKey)
    }

    static func lastPranayamaTypeRawValue() -> String? {
        UserDefaults.standard.string(forKey: pranayamaKey)
    }
}

@MainActor
final class QuickStartCoordinator: ObservableObject {
    static let shared = QuickStartCoordinator()
    @Published var pendingPractice: LaunchPractice?
    private init() {}
}

/// The practice session currently running full-screen at the app root.
enum ActivePracticeSession: Hashable, Identifiable {
    case yoga
    case pranayama(PranayamaType)
    case meditation(Int) // minutes

    var id: String {
        switch self {
        case .yoga: return "yoga"
        case .pranayama(let type): return "pranayama-\(type.rawValue)"
        case .meditation(let minutes): return "meditation-\(minutes)"
        }
    }
}

/// Root-level router for the active practice session.
///
/// Timer screens are swapped in at the app root instead of being presented as
/// sheets from the landing page: on watchOS, a sheet attached to the page-style
/// TabView is torn down whenever the landing page re-renders (streak updates
/// after a session, preset sync from the iPhone, quick-start commands, …),
/// which made pause/stop appear to "exit the app" mid-session.
@MainActor
final class SessionRouter: ObservableObject {
    static let shared = SessionRouter()

    /// Mirror of `active != nil` readable from non-main threads (e.g.
    /// WatchConnectivity callbacks). Written only on the main thread; a stale
    /// read is acceptable for the command gating it backs.
    nonisolated(unsafe) private(set) static var isPracticeActive = false

    @Published var active: ActivePracticeSession? {
        didSet { Self.isPracticeActive = active != nil }
    }

    func start(_ session: ActivePracticeSession) { active = session }
    func end() { active = nil }

    private init() {}
}
