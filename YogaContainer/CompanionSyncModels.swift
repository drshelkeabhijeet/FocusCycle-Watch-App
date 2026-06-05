// MARK: - CompanionSyncModels
//
// IMPORTANT: This file MUST be kept byte-identical with
// `FocusCycle Watch App/CompanionSyncModels.swift`. It is duplicated rather
// than shared because the project uses `PBXFileSystemSynchronizedRootGroup`,
// which makes adding the same file to two targets via the build system risky.
// If you change anything here, copy the changes to the watch target file too.
//
// The intended long-term refactor is to extract this file into a Swift Package
// shared by both targets.
//
// Wire-format contract:
// - JSON dictionary derived from `CompanionEnvelope`.
// - `schemaVersion` bumps on any breaking field change.
// - `sequence` is a monotonically increasing counter so receivers can break
//   ties when two payloads share an identical `generatedAt` timestamp.

import Foundation

enum CompanionSchema {
    static let version = 4
}

/// Single heart-rate datapoint captured during a session. `secondsFromStart`
/// is monotonically increasing; `bpm` is the instantaneous BPM rounded to int.
struct CompanionHRSample: Codable, Equatable {
    let t: Int
    let bpm: Int
}

struct CompanionStreakSummary: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let totalSessions: Int
    let totalMinutes: Int
}

struct CompanionYogaPreset: Codable {
    let holdSeconds: Int
    let restSeconds: Int
    let asanaCount: Int
}

struct CompanionPranayamaPreset: Codable {
    let typeRawValue: String
    let inhaleDuration: Int
    let hold1Duration: Int
    let exhaleDuration: Int
    let hold2Duration: Int
    let cycles: Int
}

struct CompanionMeditationPreset: Codable {
    let durationMinutes: Int
}

struct CompanionPresetsSnapshot: Codable {
    let yoga: CompanionYogaPreset
    let pranayama: [CompanionPranayamaPreset]
    let meditation: CompanionMeditationPreset
}

struct CompanionSessionEvent: Codable, Identifiable {
    let id: String
    let activityTypeRawValue: String
    let durationSeconds: Int
    let date: Date
    let pattern: String?
    // Health metrics captured by the watch around the session (all optional;
    // populated only when HealthKit auth granted and a sample was available).
    let avgHeartRate: Double?
    let avgRespiratoryRate: Double?
    let activeEnergyKcal: Double?
    let hrvPreSdnnMs: Double?
    let hrvPostSdnnMs: Double?
    let spo2PrePercent: Double?
    let spo2PostPercent: Double?
    /// Downsampled HR timeseries captured during the session (typically 1 sample
    /// per 5s). Nil when HR was not captured or the user is on schema < 4.
    let hrSamples: [CompanionHRSample]?

    init(id: String,
         activityTypeRawValue: String,
         durationSeconds: Int,
         date: Date,
         pattern: String?,
         avgHeartRate: Double? = nil,
         avgRespiratoryRate: Double? = nil,
         activeEnergyKcal: Double? = nil,
         hrvPreSdnnMs: Double? = nil,
         hrvPostSdnnMs: Double? = nil,
         spo2PrePercent: Double? = nil,
         spo2PostPercent: Double? = nil,
         hrSamples: [CompanionHRSample]? = nil) {
        self.id = id
        self.activityTypeRawValue = activityTypeRawValue
        self.durationSeconds = durationSeconds
        self.date = date
        self.pattern = pattern
        self.avgHeartRate = avgHeartRate
        self.avgRespiratoryRate = avgRespiratoryRate
        self.activeEnergyKcal = activeEnergyKcal
        self.hrvPreSdnnMs = hrvPreSdnnMs
        self.hrvPostSdnnMs = hrvPostSdnnMs
        self.spo2PrePercent = spo2PrePercent
        self.spo2PostPercent = spo2PostPercent
        self.hrSamples = hrSamples
    }

    // Backwards-compatible decode: v1/v2 events lack the health fields,
    // v3 events lack `hrSamples`.
    private enum CodingKeys: String, CodingKey {
        case id, activityTypeRawValue, durationSeconds, date, pattern
        case avgHeartRate, avgRespiratoryRate, activeEnergyKcal
        case hrvPreSdnnMs, hrvPostSdnnMs, spo2PrePercent, spo2PostPercent
        case hrSamples
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        activityTypeRawValue = try c.decode(String.self, forKey: .activityTypeRawValue)
        durationSeconds = try c.decode(Int.self, forKey: .durationSeconds)
        date = try c.decode(Date.self, forKey: .date)
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern)
        avgHeartRate = try c.decodeIfPresent(Double.self, forKey: .avgHeartRate)
        avgRespiratoryRate = try c.decodeIfPresent(Double.self, forKey: .avgRespiratoryRate)
        activeEnergyKcal = try c.decodeIfPresent(Double.self, forKey: .activeEnergyKcal)
        hrvPreSdnnMs = try c.decodeIfPresent(Double.self, forKey: .hrvPreSdnnMs)
        hrvPostSdnnMs = try c.decodeIfPresent(Double.self, forKey: .hrvPostSdnnMs)
        spo2PrePercent = try c.decodeIfPresent(Double.self, forKey: .spo2PrePercent)
        spo2PostPercent = try c.decodeIfPresent(Double.self, forKey: .spo2PostPercent)
        hrSamples = try c.decodeIfPresent([CompanionHRSample].self, forKey: .hrSamples)
    }
}

struct CompanionStateSnapshot: Codable {
    let generatedAt: Date
    let sequence: UInt64
    let streaksByActivity: [String: CompanionStreakSummary]
    let presets: CompanionPresetsSnapshot

    init(generatedAt: Date,
         sequence: UInt64,
         streaksByActivity: [String: CompanionStreakSummary],
         presets: CompanionPresetsSnapshot) {
        self.generatedAt = generatedAt
        self.sequence = sequence
        self.streaksByActivity = streaksByActivity
        self.presets = presets
    }

    // Backwards compat: snapshots written by schemaVersion 1 lack `sequence`.
    private enum CodingKeys: String, CodingKey {
        case generatedAt, sequence, streaksByActivity, presets
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        sequence = (try? c.decode(UInt64.self, forKey: .sequence)) ?? 0
        streaksByActivity = try c.decode([String: CompanionStreakSummary].self, forKey: .streaksByActivity)
        presets = try c.decode(CompanionPresetsSnapshot.self, forKey: .presets)
    }
}

struct CompanionQuickStartCommand: Codable {
    let practice: String
}

struct CompanionApplyPresetCommand: Codable {
    let practice: String
    let yoga: CompanionYogaPreset?
    let pranayama: CompanionPranayamaPreset?
    let meditation: CompanionMeditationPreset?
}

struct CompanionCommandPayload: Codable, Identifiable {
    let id: String
    let type: String
    let createdAt: Date
    let quickStart: CompanionQuickStartCommand?
    let applyPreset: CompanionApplyPresetCommand?
}

struct CompanionEnvelope: Codable {
    let schemaVersion: Int
    let kind: String
    let stateSnapshot: CompanionStateSnapshot?
    let sessionEvent: CompanionSessionEvent?
    let command: CompanionCommandPayload?

    static func snapshot(_ snapshot: CompanionStateSnapshot) -> CompanionEnvelope {
        CompanionEnvelope(
            schemaVersion: CompanionSchema.version,
            kind: "stateSnapshot",
            stateSnapshot: snapshot,
            sessionEvent: nil,
            command: nil
        )
    }

    static func sessionEvent(_ event: CompanionSessionEvent) -> CompanionEnvelope {
        CompanionEnvelope(
            schemaVersion: CompanionSchema.version,
            kind: "sessionEvent",
            stateSnapshot: nil,
            sessionEvent: event,
            command: nil
        )
    }

    static func command(_ command: CompanionCommandPayload) -> CompanionEnvelope {
        CompanionEnvelope(
            schemaVersion: CompanionSchema.version,
            kind: "command",
            stateSnapshot: nil,
            sessionEvent: nil,
            command: command
        )
    }
}
