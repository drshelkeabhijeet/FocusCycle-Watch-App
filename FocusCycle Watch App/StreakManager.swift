import Foundation

// MARK: - Activity Types
enum ActivityType: String, CaseIterable, Codable {
    case yoga = "yoga"
    case pranayama = "pranayama"
    case meditation = "meditation"
    
    var displayName: String {
        switch self {
        case .yoga: return "Yoga"
        case .pranayama: return "Pranayama"
        case .meditation: return "Meditation"
        }
    }
    
    var icon: String {
        switch self {
        case .yoga: return "figure.yoga"
        case .pranayama: return "wind"
        case .meditation: return "brain.head.profile"
        }
    }
}

// MARK: - Session Record
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let activityType: ActivityType
    let date: Date
    let duration: Int // seconds
    let pattern: String? // for pranayama (e.g., "anulom")
    // Optional health metrics; nil when HealthKit unavailable.
    var avgHeartRate: Double?
    var avgRespiratoryRate: Double?
    var activeEnergyKcal: Double?
    var hrvPreSdnnMs: Double?
    var hrvPostSdnnMs: Double?
    var spo2PrePercent: Double?
    var spo2PostPercent: Double?
    /// Downsampled HR timeseries (typically 1/5s) captured during the session.
    var hrSamples: [HRSamplePoint]?

    init(activityType: ActivityType,
         duration: Int,
         pattern: String? = nil,
         metrics: SessionHealthMetrics? = nil) {
        self.id = UUID()
        self.activityType = activityType
        self.date = Date()
        self.duration = duration
        self.pattern = pattern
        self.avgHeartRate = metrics?.avgHeartRate
        self.avgRespiratoryRate = metrics?.avgRespiratoryRate
        self.activeEnergyKcal = metrics?.activeEnergyKcal
        self.hrvPreSdnnMs = metrics?.hrvPreSdnnMs
        self.hrvPostSdnnMs = metrics?.hrvPostSdnnMs
        self.spo2PrePercent = metrics?.spo2PrePercent
        self.spo2PostPercent = metrics?.spo2PostPercent
        self.hrSamples = metrics?.hrSamples
    }
}

struct HRSamplePoint: Codable, Equatable {
    let t: Int
    let bpm: Int
}

/// Plain bag of optional values collected during a practice.
struct SessionHealthMetrics {
    var avgHeartRate: Double?
    var avgRespiratoryRate: Double?
    var activeEnergyKcal: Double?
    var hrvPreSdnnMs: Double?
    var hrvPostSdnnMs: Double?
    var spo2PrePercent: Double?
    var spo2PostPercent: Double?
    var hrSamples: [HRSamplePoint]?
}

// MARK: - Streak Data
struct StreakData: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalSessions: Int = 0
    var lastSessionDate: Date?
    var sessions: [SessionRecord] = []
    
    var hasSessionToday: Bool {
        guard let lastDate = lastSessionDate else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }
    
    var daysSinceLastSession: Int {
        guard let lastDate = lastSessionDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
    }
}

// MARK: - Streak Manager
class StreakManager: ObservableObject {
    static let shared = StreakManager()
    
    @Published var streaks: [ActivityType: StreakData] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let streaksKey = "FocusCycle_Streaks"
    
    private init() {
        loadStreaks()
        initializeStreaks()
    }
    
    // MARK: - Data Persistence
    private func loadStreaks() {
        if let data = userDefaults.data(forKey: streaksKey),
           let decoded = try? JSONDecoder().decode([ActivityType: StreakData].self, from: data) {
            streaks = decoded
        }
    }
    
    private func saveStreaks() {
        if let encoded = try? JSONEncoder().encode(streaks) {
            userDefaults.set(encoded, forKey: streaksKey)
        }
    }
    
    private func initializeStreaks() {
        for activityType in ActivityType.allCases {
            if streaks[activityType] == nil {
                streaks[activityType] = StreakData()
            }
        }
    }
    
    // MARK: - Session Recording
    func recordSession(_ activityType: ActivityType,
                       duration: Int,
                       pattern: String? = nil,
                       metrics: SessionHealthMetrics? = nil) {
        let session = SessionRecord(activityType: activityType,
                                    duration: duration,
                                    pattern: pattern,
                                    metrics: metrics)
        
        var streakData = streaks[activityType] ?? StreakData()
        
        // Add session
        streakData.sessions.append(session)
        streakData.totalSessions += 1
        streakData.lastSessionDate = session.date
        
        // Update streaks
        updateStreaks(for: &streakData)
        
        // Save
        streaks[activityType] = streakData
        saveStreaks()
        WatchConnectivityManager.shared.pushSessionEvent(session)
        WatchConnectivityManager.shared.pushLatestSnapshot()
    }
    
    private func updateStreaks(for streakData: inout StreakData) {
        let calendar = Calendar.current
        let uniqueDays = Set(streakData.sessions.map { calendar.startOfDay(for: $0.date) })

        // Current streak counts consecutive calendar days (not sessions),
        // anchored at today if present, otherwise yesterday.
        var currentStreak = 0
        var cursor = calendar.startOfDay(for: Date())

        if !uniqueDays.contains(cursor) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), uniqueDays.contains(yesterday) {
                cursor = yesterday
            } else {
                streakData.currentStreak = 0
                streakData.longestStreak = max(streakData.longestStreak, longestStreak(in: uniqueDays, calendar: calendar))
                return
            }
        }

        while uniqueDays.contains(cursor) {
            currentStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        streakData.currentStreak = currentStreak
        streakData.longestStreak = max(streakData.longestStreak, longestStreak(in: uniqueDays, calendar: calendar))
    }

    private func longestStreak(in uniqueDays: Set<Date>, calendar: Calendar) -> Int {
        let sortedDays = uniqueDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var longest = 1
        var run = 1

        for idx in 1..<sortedDays.count {
            let prev = sortedDays[idx - 1]
            let current = sortedDays[idx]
            let delta = calendar.dateComponents([.day], from: prev, to: current).day ?? 0
            if delta == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }
    
    // MARK: - Streak Queries
    func getStreakData(for activityType: ActivityType) -> StreakData {
        return streaks[activityType] ?? StreakData()
    }
    
    func getCurrentStreak(for activityType: ActivityType) -> Int {
        return getStreakData(for: activityType).currentStreak
    }
    
    func getLongestStreak(for activityType: ActivityType) -> Int {
        return getStreakData(for: activityType).longestStreak
    }
    
    func getTotalSessions(for activityType: ActivityType) -> Int {
        return getStreakData(for: activityType).totalSessions
    }
    
    func hasSessionToday(for activityType: ActivityType) -> Bool {
        return getStreakData(for: activityType).hasSessionToday
    }
    
    // MARK: - Recent Sessions
    func getRecentSessions(for activityType: ActivityType, limit: Int = 7) -> [SessionRecord] {
        let streakData = getStreakData(for: activityType)
        return Array(streakData.sessions.sorted { $0.date > $1.date }.prefix(limit))
    }
    
    // MARK: - Statistics
    func getTotalMinutes(for activityType: ActivityType) -> Int {
        // Sum seconds first, then divide — otherwise short sessions
        // (each < 60s) are floored to 0 and never contribute.
        let streakData = getStreakData(for: activityType)
        let totalSeconds = streakData.sessions.reduce(0) { $0 + $1.duration }
        return totalSeconds / 60
    }
    
    func getAverageSessionDuration(for activityType: ActivityType) -> Int {
        let streakData = getStreakData(for: activityType)
        guard !streakData.sessions.isEmpty else { return 0 }
        let totalSeconds = streakData.sessions.reduce(0) { $0 + $1.duration }
        return totalSeconds / streakData.sessions.count
    }
    
    // MARK: - Reset (for testing)
    func resetStreaks() {
        streaks.removeAll()
        initializeStreaks()
        saveStreaks()
        WatchConnectivityManager.shared.pushLatestSnapshot()
    }

    func companionStreakSummaries() -> [String: CompanionStreakSummary] {
        var result: [String: CompanionStreakSummary] = [:]
        for activity in ActivityType.allCases {
            let data = getStreakData(for: activity)
            result[activity.rawValue] = CompanionStreakSummary(
                currentStreak: data.currentStreak,
                longestStreak: data.longestStreak,
                totalSessions: data.totalSessions,
                totalMinutes: getTotalMinutes(for: activity)
            )
        }
        return result
    }
}
