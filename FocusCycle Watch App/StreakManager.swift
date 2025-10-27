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
    
    init(activityType: ActivityType, duration: Int, pattern: String? = nil) {
        self.id = UUID()
        self.activityType = activityType
        self.date = Date()
        self.duration = duration
        self.pattern = pattern
    }
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
    func recordSession(_ activityType: ActivityType, duration: Int, pattern: String? = nil) {
        let session = SessionRecord(activityType: activityType, duration: duration, pattern: pattern)
        
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
    }
    
    private func updateStreaks(for streakData: inout StreakData) {
        let calendar = Calendar.current
        let today = Date()
        
        // Sort sessions by date (newest first)
        let sortedSessions = streakData.sessions.sorted { $0.date > $1.date }
        
        // Calculate current streak
        var currentStreak = 0
        var checkDate = today
        
        for session in sortedSessions {
            if calendar.isDate(session.date, inSameDayAs: checkDate) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if calendar.isDate(session.date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        
        streakData.currentStreak = currentStreak
        streakData.longestStreak = max(streakData.longestStreak, currentStreak)
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
        let streakData = getStreakData(for: activityType)
        return streakData.sessions.reduce(0) { $0 + ($1.duration / 60) }
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
    }
}
