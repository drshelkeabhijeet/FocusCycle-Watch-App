package com.focuscycle.domain

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

enum class ActivityType(val rawValue: String, val displayName: String) {
    Yoga("yoga", "Yoga"),
    Pranayama("pranayama", "Pranayama"),
    Meditation("meditation", "Meditation");

    companion object {
        fun fromRawValue(rawValue: String): ActivityType? = entries.firstOrNull { it.rawValue == rawValue }
    }
}

enum class OperatingMode(val rawValue: String) {
    SingleInterval("Single"),
    MultipleIntervals("Multiple")
}

enum class LaunchPractice(val rawValue: String) {
    Yoga("yoga"),
    Pranayama("pranayama"),
    Meditation("meditation")
}

@Serializable
data class HRSamplePoint(
    val t: Int,
    val bpm: Int
)

@Serializable
data class SessionHealthMetrics(
    val avgHeartRate: Double? = null,
    val avgRespiratoryRate: Double? = null,
    val activeEnergyKcal: Double? = null,
    val hrvPreSdnnMs: Double? = null,
    val hrvPostSdnnMs: Double? = null,
    val spo2PrePercent: Double? = null,
    val spo2PostPercent: Double? = null,
    val hrSamples: List<HRSamplePoint>? = null
)

@Serializable
data class SessionRecord(
    val id: String = UUID.randomUUID().toString(),
    val activityTypeRawValue: String,
    val dateEpochMillis: Long = Instant.now().toEpochMilli(),
    val durationSeconds: Int,
    val pattern: String? = null,
    val avgHeartRate: Double? = null,
    val avgRespiratoryRate: Double? = null,
    val activeEnergyKcal: Double? = null,
    val hrvPreSdnnMs: Double? = null,
    val hrvPostSdnnMs: Double? = null,
    val spo2PrePercent: Double? = null,
    val spo2PostPercent: Double? = null,
    val hrSamples: List<HRSamplePoint>? = null
) {
    constructor(
        activityType: ActivityType,
        durationSeconds: Int,
        pattern: String? = null,
        metrics: SessionHealthMetrics? = null
    ) : this(
        activityTypeRawValue = activityType.rawValue,
        durationSeconds = durationSeconds,
        pattern = pattern,
        avgHeartRate = metrics?.avgHeartRate,
        avgRespiratoryRate = metrics?.avgRespiratoryRate,
        activeEnergyKcal = metrics?.activeEnergyKcal,
        hrvPreSdnnMs = metrics?.hrvPreSdnnMs,
        hrvPostSdnnMs = metrics?.hrvPostSdnnMs,
        spo2PrePercent = metrics?.spo2PrePercent,
        spo2PostPercent = metrics?.spo2PostPercent,
        hrSamples = metrics?.hrSamples
    )
}

@Serializable
data class StreakData(
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val totalSessions: Int = 0,
    val lastSessionEpochMillis: Long? = null,
    val sessions: List<SessionRecord> = emptyList()
)

@Serializable
data class YogaPreset(
    val holdSeconds: Int = 60,
    val restSeconds: Int = 20,
    val asanaCount: Int = 10,
    val operatingMode: OperatingMode = OperatingMode.MultipleIntervals,
    val singleIntervalDurationSeconds: Int = 60,
    val singleIntervalSequenceDurationMinutes: Int = 30
)

enum class PranayamaType(val rawValue: String, val displayName: String) {
    Anulom("Anulom", "Anulom"),
    Ujjayi("Ujjayi", "Ujjayi"),
    Bhastrika("Bhastrika", "Bhastrika");

    companion object {
        fun fromRawValue(rawValue: String): PranayamaType? = entries.firstOrNull { it.rawValue == rawValue }
    }
}

enum class BreathingPhase(val rawValue: String, val displayName: String) {
    Inhale("Inhale", "Inhale"),
    Hold1("Hold 1", "Hold 1"),
    Exhale("Exhale", "Exhale"),
    Hold2("Hold 2", "Hold 2")
}

@Serializable
data class PranayamaPattern(
    val typeRawValue: String,
    val inhaleDuration: Int,
    val hold1Duration: Int,
    val exhaleDuration: Int,
    val hold2Duration: Int,
    val cycles: Int
) {
    val totalDurationSeconds: Int
        get() = (inhaleDuration + hold1Duration + exhaleDuration + hold2Duration) * cycles

    val phases: List<Pair<BreathingPhase, Int>>
        get() = listOf(
            BreathingPhase.Inhale to inhaleDuration,
            BreathingPhase.Hold1 to hold1Duration,
            BreathingPhase.Exhale to exhaleDuration,
            BreathingPhase.Hold2 to hold2Duration
        )

    companion object {
        fun defaultFor(type: PranayamaType) = when (type) {
            PranayamaType.Anulom -> PranayamaPattern(type.rawValue, 4, 4, 4, 4, 10)
            PranayamaType.Ujjayi -> PranayamaPattern(type.rawValue, 6, 2, 6, 2, 8)
            PranayamaType.Bhastrika -> PranayamaPattern(type.rawValue, 2, 1, 2, 1, 12)
        }
    }
}

@Serializable
data class MeditationPreset(
    val durationMinutes: Int = 12,
    val userPresetName: String? = null
)
