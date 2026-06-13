package com.focuscycle.domain

import kotlinx.serialization.Serializable

object CompanionSchema {
    const val VERSION = 5
}

@Serializable
data class CompanionHRSample(
    val t: Int,
    val bpm: Int
)

@Serializable
data class CompanionStreakSummary(
    val currentStreak: Int,
    val longestStreak: Int,
    val totalSessions: Int,
    val totalMinutes: Int
)

@Serializable
data class CompanionYogaPreset(
    val holdSeconds: Int,
    val restSeconds: Int,
    val asanaCount: Int
)

@Serializable
data class CompanionPranayamaPreset(
    val typeRawValue: String,
    val inhaleDuration: Int,
    val hold1Duration: Int,
    val exhaleDuration: Int,
    val hold2Duration: Int,
    val cycles: Int
)

@Serializable
data class CompanionMeditationPreset(
    val durationMinutes: Int
)

@Serializable
data class CompanionPresetsSnapshot(
    val yoga: CompanionYogaPreset,
    val pranayama: List<CompanionPranayamaPreset>,
    val meditation: CompanionMeditationPreset
)

@Serializable
data class CompanionSessionEvent(
    val id: String,
    val activityTypeRawValue: String,
    val durationSeconds: Int,
    val dateEpochMillis: Long,
    val pattern: String? = null,
    val avgHeartRate: Double? = null,
    val avgRespiratoryRate: Double? = null,
    val activeEnergyKcal: Double? = null,
    val hrvPreSdnnMs: Double? = null,
    val hrvPostSdnnMs: Double? = null,
    val spo2PrePercent: Double? = null,
    val spo2PostPercent: Double? = null,
    val hrSamples: List<CompanionHRSample>? = null
)

@Serializable
data class CompanionStateSnapshot(
    val generatedAtEpochMillis: Long,
    val sequence: Long,
    val streaksByActivity: Map<String, CompanionStreakSummary>,
    val presets: CompanionPresetsSnapshot,
    val recentEvents: List<CompanionSessionEvent>? = null
)

@Serializable
data class CompanionQuickStartCommand(
    val practice: String
)

@Serializable
data class CompanionApplyPresetCommand(
    val practice: String,
    val yoga: CompanionYogaPreset? = null,
    val pranayama: CompanionPranayamaPreset? = null,
    val meditation: CompanionMeditationPreset? = null
)

@Serializable
data class CompanionCommandPayload(
    val id: String,
    val type: String,
    val createdAtEpochMillis: Long,
    val quickStart: CompanionQuickStartCommand? = null,
    val applyPreset: CompanionApplyPresetCommand? = null
)

@Serializable
data class CompanionEnvelope(
    val schemaVersion: Int = CompanionSchema.VERSION,
    val kind: String,
    val stateSnapshot: CompanionStateSnapshot? = null,
    val sessionEvent: CompanionSessionEvent? = null,
    val command: CompanionCommandPayload? = null
) {
    companion object {
        fun snapshot(snapshot: CompanionStateSnapshot) = CompanionEnvelope(
            kind = "stateSnapshot",
            stateSnapshot = snapshot
        )

        fun sessionEvent(event: CompanionSessionEvent) = CompanionEnvelope(
            kind = "sessionEvent",
            sessionEvent = event
        )

        fun command(command: CompanionCommandPayload) = CompanionEnvelope(
            kind = "command",
            command = command
        )
    }
}

fun SessionRecord.toCompanionEvent(): CompanionSessionEvent = CompanionSessionEvent(
    id = id,
    activityTypeRawValue = activityTypeRawValue,
    durationSeconds = durationSeconds,
    dateEpochMillis = dateEpochMillis,
    pattern = pattern,
    avgHeartRate = avgHeartRate,
    avgRespiratoryRate = avgRespiratoryRate,
    activeEnergyKcal = activeEnergyKcal,
    hrvPreSdnnMs = hrvPreSdnnMs,
    hrvPostSdnnMs = hrvPostSdnnMs,
    spo2PrePercent = spo2PrePercent,
    spo2PostPercent = spo2PostPercent,
    hrSamples = hrSamples?.map { CompanionHRSample(it.t, it.bpm) }
)
