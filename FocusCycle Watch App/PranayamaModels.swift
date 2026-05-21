import Foundation

// MARK: - Pranayama Types
enum PranayamaType: String, CaseIterable, Identifiable {
    case anulom = "Anulom"
    case ujjayi = "Ujjayi"
    case bhastrika = "Bhastrika"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .anulom:
            return "Alternate nostril breathing"
        case .ujjayi:
            return "Victorious breath"
        case .bhastrika:
            return "Bellows breath"
        }
    }
    
    var icon: String {
        switch self {
        case .anulom:
            return "wind"
        case .ujjayi:
            return "lungs"
        case .bhastrika:
            return "flame"
        }
    }
}

// MARK: - Breathing Phase
enum BreathingPhase: String, CaseIterable {
    case inhale = "Inhale"
    case hold1 = "Hold 1"
    case exhale = "Exhale"
    case hold2 = "Hold 2"
    
    var displayName: String { rawValue }
    
    var color: String {
        switch self {
        case .inhale:
            return "focusBlue"
        case .hold1, .hold2:
            return "pauseOrange"
        case .exhale:
            return "playGreen"
        }
    }
}

// MARK: - Pranayama Pattern
struct PranayamaPattern {
    let type: PranayamaType
    var inhaleDuration: Int // seconds
    var hold1Duration: Int // seconds
    var exhaleDuration: Int // seconds
    var hold2Duration: Int // seconds
    var cycles: Int // number of complete breathing cycles
    
    var totalDuration: Int {
        let cycleDuration = inhaleDuration + hold1Duration + exhaleDuration + hold2Duration
        return cycleDuration * cycles
    }
    
    var phases: [(BreathingPhase, Int)] {
        return [
            (.inhale, inhaleDuration),
            (.hold1, hold1Duration),
            (.exhale, exhaleDuration),
            (.hold2, hold2Duration)
        ]
    }
}

// MARK: - Pranayama Settings Manager
class PranayamaSettingsManager: ObservableObject {
    static let shared = PranayamaSettingsManager()
    
    @Published var patterns: [PranayamaType: PranayamaPattern] = [:]
    private let storageKey = "FocusCycle_PranayamaPatterns"
    
    private init() {
        loadPatterns()
    }
    
    func loadDefaultPatterns() {
        patterns[.anulom] = PranayamaPattern(
            type: .anulom,
            inhaleDuration: 4,
            hold1Duration: 4,
            exhaleDuration: 4,
            hold2Duration: 4,
            cycles: 10
        )
        
        patterns[.ujjayi] = PranayamaPattern(
            type: .ujjayi,
            inhaleDuration: 6,
            hold1Duration: 2,
            exhaleDuration: 6,
            hold2Duration: 2,
            cycles: 8
        )
        
        patterns[.bhastrika] = PranayamaPattern(
            type: .bhastrika,
            inhaleDuration: 2,
            hold1Duration: 1,
            exhaleDuration: 2,
            hold2Duration: 1,
            cycles: 12
        )
        savePatterns()
    }
    
    func getPattern(for type: PranayamaType) -> PranayamaPattern {
        return patterns[type] ?? PranayamaPattern(
            type: type,
            inhaleDuration: 4,
            hold1Duration: 4,
            exhaleDuration: 4,
            hold2Duration: 4,
            cycles: 10
        )
    }
    
    func updatePattern(_ pattern: PranayamaPattern) {
        patterns[pattern.type] = pattern
        savePatterns()
        WatchConnectivityManager.shared.pushLatestSnapshotDebounced()
    }
    
    var allPatterns: [PranayamaPattern] {
        return PranayamaType.allCases.map { getPattern(for: $0) }
    }

    private func loadPatterns() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            loadDefaultPatterns()
            return
        }
        guard let decoded = try? JSONDecoder().decode([String: PranayamaPatternValue].self, from: data) else {
            loadDefaultPatterns()
            return
        }
        var rebuilt: [PranayamaType: PranayamaPattern] = [:]
        for (key, value) in decoded {
            guard let type = PranayamaType(rawValue: key) else { continue }
            rebuilt[type] = value.toPattern(type: type)
        }
        if rebuilt.isEmpty {
            loadDefaultPatterns()
        } else {
            patterns = rebuilt
        }
    }

    private func savePatterns() {
        let encoded = patterns.reduce(into: [String: PranayamaPatternValue]()) { result, pair in
            result[pair.key.rawValue] = PranayamaPatternValue(from: pair.value)
        }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

private struct PranayamaPatternValue: Codable {
    let inhaleDuration: Int
    let hold1Duration: Int
    let exhaleDuration: Int
    let hold2Duration: Int
    let cycles: Int

    init(from pattern: PranayamaPattern) {
        inhaleDuration = pattern.inhaleDuration
        hold1Duration = pattern.hold1Duration
        exhaleDuration = pattern.exhaleDuration
        hold2Duration = pattern.hold2Duration
        cycles = pattern.cycles
    }

    func toPattern(type: PranayamaType) -> PranayamaPattern {
        PranayamaPattern(
            type: type,
            inhaleDuration: inhaleDuration,
            hold1Duration: hold1Duration,
            exhaleDuration: exhaleDuration,
            hold2Duration: hold2Duration,
            cycles: cycles
        )
    }
}

// MARK: - Pranayama Session State
class PranayamaSession: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentPhase: BreathingPhase = .inhale
    @Published var phaseProgress: Double = 0.0
    @Published var cycleProgress: Double = 0.0
    @Published var currentCycle: Int = 1
    @Published var elapsedTime: Int = 0
    @Published var remainingTime: Int = 0
    
    private var pattern: PranayamaPattern
    private var phaseStartTime: Date?
    private var sessionStartTime: Date?
    private var currentPhaseIndex: Int = 0
    private var currentPhaseDuration: Int = 0
    private var pausedElapsedTime: Int = 0
    
    init(pattern: PranayamaPattern) {
        self.pattern = pattern
        self.remainingTime = pattern.totalDuration
    }
    
    func start() {
        guard !isActive else { return }

        isActive = true

        if sessionStartTime == nil && elapsedTime == 0 {
            // Fresh session start.
            sessionStartTime = Date()
            phaseStartTime = Date()
            currentPhaseIndex = 0
            currentCycle = 1
            elapsedTime = 0
            pausedElapsedTime = 0
            remainingTime = pattern.totalDuration

            let firstPhase = pattern.phases[0]
            currentPhase = firstPhase.0
            currentPhaseDuration = firstPhase.1
            phaseProgress = 0.0
            cycleProgress = 0.0
        } else {
            // Resume: move start time so elapsed continues from pause point.
            sessionStartTime = Date().addingTimeInterval(TimeInterval(-pausedElapsedTime))
            phaseStartTime = Date()
            updateProgress()
        }
    }

    func pause() {
        // Snapshot the precise elapsed at the moment of pause rather than relying on
        // the most recent `updateProgress` tick (which may be up to 100ms stale).
        if let startTime = sessionStartTime, isActive {
            let precise = max(0, Int(Date().timeIntervalSince(startTime)))
            pausedElapsedTime = precise
            elapsedTime = precise
        } else {
            pausedElapsedTime = elapsedTime
        }
        isActive = false
    }
    
    func reset() {
        isActive = false
        currentPhase = .inhale
        phaseProgress = 0.0
        cycleProgress = 0.0
        currentCycle = 1
        elapsedTime = 0
        remainingTime = pattern.totalDuration
        currentPhaseIndex = 0
        phaseStartTime = nil
        sessionStartTime = nil
        pausedElapsedTime = 0
    }
    
    func updateProgress() {
        guard isActive, let startTime = sessionStartTime else { return }
        
        let totalElapsed = Int(Date().timeIntervalSince(startTime))
        elapsedTime = totalElapsed
        remainingTime = max(0, pattern.totalDuration - totalElapsed)
        
        // Calculate cycle progress
        let cycleDuration = pattern.phases.reduce(0) { $0 + $1.1 }
        let cycleElapsed = totalElapsed % cycleDuration
        cycleProgress = Double(cycleElapsed) / Double(cycleDuration)
        
        // Calculate current cycle
        currentCycle = (totalElapsed / cycleDuration) + 1
        
        // Update current phase
        updateCurrentPhase()
    }
    
    private func updateCurrentPhase() {
        guard let startTime = sessionStartTime else { return }
        
        let totalElapsed = Int(Date().timeIntervalSince(startTime))
        let cycleDuration = pattern.phases.reduce(0) { $0 + $1.1 }
        let cycleElapsed = totalElapsed % cycleDuration
        
        let previousPhase = currentPhase
        
        var accumulatedTime = 0
        for (index, (phase, duration)) in pattern.phases.enumerated() {
            if cycleElapsed < accumulatedTime + duration {
                currentPhase = phase
                currentPhaseIndex = index
                let phaseElapsed = cycleElapsed - accumulatedTime
                phaseProgress = Double(phaseElapsed) / Double(duration)
                
                // Trigger phase alert when phase changes
                if previousPhase != currentPhase {
                    AlertManager.shared.triggerPhaseAlert(for: currentPhase)
                }
                return
            }
            accumulatedTime += duration
        }
    }
}
