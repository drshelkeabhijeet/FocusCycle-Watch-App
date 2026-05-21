import Foundation
import WatchKit
import AVFoundation

// MARK: - Alert Types
enum AlertType: String, CaseIterable, Codable {
    case haptic = "haptic"
    case sound = "sound"
    case both = "both"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .haptic: return "Haptic Only"
        case .sound: return "Sound Only"
        case .both: return "Haptic + Sound"
        case .none: return "No Alert"
        }
    }
    
    var icon: String {
        switch self {
        case .haptic: return "hand.tap"
        case .sound: return "speaker.wave.2"
        case .both: return "hand.tap.fill"
        case .none: return "speaker.slash"
        }
    }
}

// MARK: - Haptic Types
enum HapticType: String, CaseIterable, Codable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    case success = "success"
    case warning = "warning"
    case error = "error"
    case selection = "selection"
    case notification = "notification"
    
    var displayName: String {
        switch self {
        case .light: return "Light Tap"
        case .medium: return "Medium Tap"
        case .heavy: return "Heavy Tap"
        case .success: return "Success"
        case .warning: return "Warning"
        case .error: return "Error"
        case .selection: return "Selection"
        case .notification: return "Notification"
        }
    }
    
    var hapticType: WKHapticType {
        switch self {
        case .light: return .click
        case .medium: return .notification
        case .heavy: return .start
        case .success: return .success
        case .warning: return .notification
        case .error: return .failure
        case .selection: return .directionUp
        case .notification: return .notification
        }
    }
}

// MARK: - Sound Types
enum SoundType: String, CaseIterable, Codable {
    case bell = "bell"
    case chime = "chime"
    case ding = "ding"
    case tone = "tone"
    case gong = "gong"
    case chakra = "chakra"
    case om = "om"
    case crystal = "crystal"
    
    var displayName: String {
        switch self {
        case .bell: return "Bell"
        case .chime: return "Chime"
        case .ding: return "Ding"
        case .tone: return "Tone"
        case .gong: return "Gong"
        case .chakra: return "Chakra"
        case .om: return "Om"
        case .crystal: return "Crystal"
        }
    }
    
    var fileName: String {
        switch self {
        case .bell: return "bell.wav"
        case .chime: return "chime.wav"
        case .ding: return "ding.wav"
        case .tone: return "tone.wav"
        case .gong: return "gong.wav"
        case .chakra: return "chakra.wav"
        case .om: return "om.wav"
        case .crystal: return "crystal.wav"
        }
    }
}

// MARK: - Phase Alert Settings
struct PhaseAlertSettings: Codable {
    var inhaleAlert: AlertType = .haptic
    var hold1Alert: AlertType = .haptic
    var exhaleAlert: AlertType = .haptic
    var hold2Alert: AlertType = .haptic
    var phaseHapticType: HapticType = .medium
    var phaseSoundType: SoundType = .bell
    var phaseVolume: Float = 0.7
    var isEnabled: Bool = true
}

// MARK: - Alert Settings
struct AlertSettings: Codable {
    var alertType: AlertType = .haptic
    var hapticType: HapticType = .medium
    var soundType: SoundType = .bell
    var volume: Float = 0.7
    var isEnabled: Bool = true
    var phaseAlerts: PhaseAlertSettings = PhaseAlertSettings()
    
    var hapticIntensity: Float {
        switch hapticType {
        case .light: return 0.3
        case .medium: return 0.6
        case .heavy: return 1.0
        case .success: return 0.8
        case .warning: return 0.7
        case .error: return 0.9
        case .selection: return 0.4
        case .notification: return 0.6
        }
    }
}

// MARK: - Alert Manager
class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var settings: AlertSettings = AlertSettings()
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "FocusCycle_AlertSettings"
    private var audioPlayer: AVAudioPlayer?

    /// True when at least one bundled sound asset is shipped with the app.
    /// Used by Settings UI to hide non-functional sound pickers when no audio assets exist.
    static var hasBundledSoundAssets: Bool = {
        SoundType.allCases.contains { Bundle.main.url(forResource: $0.fileName, withExtension: nil) != nil }
    }()
    private var audioSessionConfigured = false

    private init() {
        loadSettings()
    }

    // MARK: - Data Persistence
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AlertSettings.self, from: data) {
            settings = decoded
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }

    /// Lazily activates an audio session the first time a sound plays.
    /// Idempotent and tolerant of interruptions.
    private func ensureAudioSessionConfigured() {
        guard !audioSessionConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioSessionConfigured = true
        } catch {
            // Leave audioSessionConfigured = false so the next sound attempt retries.
        }
    }
    
    // MARK: - Alert Triggers
    func triggerAlert() {
        guard settings.isEnabled else { return }
        
        switch settings.alertType {
        case .haptic:
            triggerHaptic()
        case .sound:
            triggerSound()
        case .both:
            triggerHaptic()
            triggerSound()
        case .none:
            break
        }
    }
    
    // MARK: - Phase Alert Triggers
    func triggerPhaseAlert(for phase: BreathingPhase) {
        guard settings.phaseAlerts.isEnabled else { return }
        
        let alertType: AlertType
        switch phase {
        case .inhale:
            alertType = settings.phaseAlerts.inhaleAlert
        case .hold1:
            alertType = settings.phaseAlerts.hold1Alert
        case .exhale:
            alertType = settings.phaseAlerts.exhaleAlert
        case .hold2:
            alertType = settings.phaseAlerts.hold2Alert
        }
        
        switch alertType {
        case .haptic:
            triggerPhaseHaptic()
        case .sound:
            triggerPhaseSound()
        case .both:
            triggerPhaseHaptic()
            triggerPhaseSound()
        case .none:
            break
        }
    }
    
    func triggerPhaseHaptic() {
        let device = WKInterfaceDevice.current()
        device.play(settings.phaseAlerts.phaseHapticType.hapticType)
    }
    
    func triggerPhaseSound() {
        guard let soundURL = Bundle.main.url(forResource: settings.phaseAlerts.phaseSoundType.fileName, withExtension: nil) else {
            triggerPhaseHaptic()
            return
        }
        ensureAudioSessionConfigured()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = settings.phaseAlerts.phaseVolume
            audioPlayer?.play()
        } catch {
            triggerPhaseHaptic()
        }
    }
    
    func triggerHaptic() {
        let device = WKInterfaceDevice.current()
        device.play(settings.hapticType.hapticType)
    }
    
    func triggerSound() {
        guard let soundURL = Bundle.main.url(forResource: settings.soundType.fileName, withExtension: nil) else {
            triggerHaptic()
            return
        }
        ensureAudioSessionConfigured()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = settings.volume
            audioPlayer?.play()
        } catch {
            triggerHaptic()
        }
    }
    
    // MARK: - Settings Management
    func updateAlertType(_ type: AlertType) {
        settings.alertType = type
        saveSettings()
    }
    
    func updateHapticType(_ type: HapticType) {
        settings.hapticType = type
        saveSettings()
    }
    
    func updateSoundType(_ type: SoundType) {
        settings.soundType = type
        saveSettings()
    }
    
    func updateVolume(_ volume: Float) {
        settings.volume = max(0.0, min(1.0, volume))
        saveSettings()
    }
    
    func toggleEnabled() {
        settings.isEnabled.toggle()
        saveSettings()
    }
    
    // MARK: - Test Functions
    func testAlert() {
        triggerAlert()
    }
    
    func testHaptic() {
        triggerHaptic()
    }
    
    func testSound() {
        triggerSound()
    }
    
    // MARK: - Phase Alert Settings Management
    func updatePhaseAlert(for phase: BreathingPhase, alertType: AlertType) {
        switch phase {
        case .inhale:
            settings.phaseAlerts.inhaleAlert = alertType
        case .hold1:
            settings.phaseAlerts.hold1Alert = alertType
        case .exhale:
            settings.phaseAlerts.exhaleAlert = alertType
        case .hold2:
            settings.phaseAlerts.hold2Alert = alertType
        }
        saveSettings()
    }
    
    func updatePhaseHapticType(_ type: HapticType) {
        settings.phaseAlerts.phaseHapticType = type
        saveSettings()
    }
    
    func updatePhaseSoundType(_ type: SoundType) {
        settings.phaseAlerts.phaseSoundType = type
        saveSettings()
    }
    
    func updatePhaseVolume(_ volume: Float) {
        settings.phaseAlerts.phaseVolume = max(0.0, min(1.0, volume))
        saveSettings()
    }
    
    func togglePhaseAlertsEnabled() {
        settings.phaseAlerts.isEnabled.toggle()
        saveSettings()
    }
    
    // MARK: - Test Functions
    func testPhaseAlert(for phase: BreathingPhase) {
        triggerPhaseAlert(for: phase)
    }
    
    // MARK: - Reset
    func resetToDefaults() {
        settings = AlertSettings()
        saveSettings()
    }
}
