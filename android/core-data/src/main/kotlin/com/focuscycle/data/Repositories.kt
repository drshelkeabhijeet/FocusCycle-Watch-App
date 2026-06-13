package com.focuscycle.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.focuscycle.domain.ActivityType
import com.focuscycle.domain.CompanionCommandPayload
import com.focuscycle.domain.CompanionMeditationPreset
import com.focuscycle.domain.CompanionPranayamaPreset
import com.focuscycle.domain.CompanionPresetsSnapshot
import com.focuscycle.domain.CompanionStateSnapshot
import com.focuscycle.domain.CompanionStreakSummary
import com.focuscycle.domain.CompanionYogaPreset
import com.focuscycle.domain.MeditationPreset
import com.focuscycle.domain.OperatingMode
import com.focuscycle.domain.PranayamaPattern
import com.focuscycle.domain.PranayamaType
import com.focuscycle.domain.SessionRecord
import com.focuscycle.domain.StreakCalculator
import com.focuscycle.domain.StreakData
import com.focuscycle.domain.YogaPreset
import com.focuscycle.domain.toCompanionEvent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.temporal.ChronoUnit

private val Context.focusCycleDataStore by preferencesDataStore("focus_cycle_preferences")

class PreferenceRepository(
    private val context: Context,
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    private object Keys {
        val yogaMode = stringPreferencesKey("yoga.operatingMode")
        val yogaSingleDuration = intPreferencesKey("yoga.singleDurationSeconds")
        val yogaSingleSequence = intPreferencesKey("yoga.singleSequenceMinutes")
        val yogaHold = intPreferencesKey("yoga.holdSeconds")
        val yogaRest = intPreferencesKey("yoga.restSeconds")
        val yogaAsanas = intPreferencesKey("yoga.asanaCount")
        val pranayamaPatterns = stringPreferencesKey("pranayama.patterns.json")
        val meditationDuration = intPreferencesKey("meditation.durationMinutes")
        val meditationPresetName = stringPreferencesKey("meditation.presetName")
        val snapshotSequence = longPreferencesKey("sync.snapshotSequence")
    }

    val yogaPreset: Flow<YogaPreset> = context.focusCycleDataStore.data.map { prefs ->
        YogaPreset(
            holdSeconds = prefs[Keys.yogaHold] ?: 60,
            restSeconds = prefs[Keys.yogaRest] ?: 20,
            asanaCount = prefs[Keys.yogaAsanas] ?: 10,
            operatingMode = OperatingMode.entries.firstOrNull { it.rawValue == prefs[Keys.yogaMode] }
                ?: OperatingMode.MultipleIntervals,
            singleIntervalDurationSeconds = prefs[Keys.yogaSingleDuration] ?: 60,
            singleIntervalSequenceDurationMinutes = prefs[Keys.yogaSingleSequence] ?: 30
        )
    }

    val pranayamaPatterns: Flow<List<PranayamaPattern>> = context.focusCycleDataStore.data.map { prefs ->
        prefs[Keys.pranayamaPatterns]
            ?.let { runCatching { json.decodeFromString<List<PranayamaPattern>>(it) }.getOrNull() }
            ?: PranayamaType.entries.map { PranayamaPattern.defaultFor(it) }
    }

    val meditationPreset: Flow<MeditationPreset> = context.focusCycleDataStore.data.map { prefs ->
        MeditationPreset(
            durationMinutes = prefs[Keys.meditationDuration] ?: 12,
            userPresetName = prefs[Keys.meditationPresetName]
        )
    }

    suspend fun saveYogaPreset(preset: YogaPreset) {
        context.focusCycleDataStore.edit { prefs ->
            prefs[Keys.yogaHold] = maxOf(1, preset.holdSeconds)
            prefs[Keys.yogaRest] = maxOf(0, preset.restSeconds)
            prefs[Keys.yogaAsanas] = maxOf(1, preset.asanaCount)
            prefs[Keys.yogaMode] = preset.operatingMode.rawValue
            prefs[Keys.yogaSingleDuration] = maxOf(1, preset.singleIntervalDurationSeconds)
            prefs[Keys.yogaSingleSequence] = maxOf(1, preset.singleIntervalSequenceDurationMinutes)
        }
    }

    suspend fun savePranayamaPattern(pattern: PranayamaPattern) {
        val existing = context.focusCycleDataStore.data.map { prefs ->
            prefs[Keys.pranayamaPatterns]
                ?.let { runCatching { json.decodeFromString<List<PranayamaPattern>>(it) }.getOrNull() }
                ?: PranayamaType.entries.map { PranayamaPattern.defaultFor(it) }
        }.first()
        context.focusCycleDataStore.edit { prefs ->
            val updated = existing.filterNot { it.typeRawValue == pattern.typeRawValue } + pattern
            prefs[Keys.pranayamaPatterns] = json.encodeToString(updated.sortedBy { it.typeRawValue })
        }
    }

    suspend fun saveMeditationPreset(preset: MeditationPreset) {
        context.focusCycleDataStore.edit { prefs ->
            prefs[Keys.meditationDuration] = maxOf(1, preset.durationMinutes)
            preset.userPresetName?.let { prefs[Keys.meditationPresetName] = it } ?: prefs.remove(Keys.meditationPresetName)
        }
    }

    suspend fun nextSnapshotSequence(): Long {
        var next = 1L
        context.focusCycleDataStore.edit { prefs ->
            next = (prefs[Keys.snapshotSequence] ?: 0L) + 1L
            prefs[Keys.snapshotSequence] = next
        }
        return next
    }
}

class SessionRepository(
    private val dao: SessionRecordDao,
    private val preferences: PreferenceRepository,
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    val sessions: Flow<List<SessionRecord>> = dao.observeAll().map { rows -> rows.map { it.toDomain(json) } }

    suspend fun record(record: SessionRecord) {
        dao.upsert(SessionRecordEntity.fromDomain(record, json))
    }

    suspend fun all(): List<SessionRecord> = dao.all().map { it.toDomain(json) }

    suspend fun recentEventsForSnapshot(): List<SessionRecord> {
        val cutoff = Instant.now().minus(90, ChronoUnit.DAYS).toEpochMilli()
        return dao.recentSince(cutoff, limit = 100).map { it.toDomain(json).copy(hrSamples = null) }
    }

    suspend fun clear() = dao.clear()

    suspend fun snapshot(
        yoga: YogaPreset,
        pranayama: List<PranayamaPattern>,
        meditation: MeditationPreset
    ): CompanionStateSnapshot {
        val sessions = all()
        val streaks = ActivityType.entries.associate { activity ->
            val records = sessions.filter { it.activityTypeRawValue == activity.rawValue }
            val data = StreakCalculator.recalculate(
                StreakData(totalSessions = records.size, sessions = records)
            )
            activity.rawValue to CompanionStreakSummary(
                currentStreak = data.currentStreak,
                longestStreak = data.longestStreak,
                totalSessions = records.size,
                totalMinutes = records.sumOf { it.durationSeconds } / 60
            )
        }
        return CompanionStateSnapshot(
            generatedAtEpochMillis = Instant.now().toEpochMilli(),
            sequence = preferences.nextSnapshotSequence(),
            streaksByActivity = streaks,
            presets = CompanionPresetsSnapshot(
                yoga = CompanionYogaPreset(yoga.holdSeconds, yoga.restSeconds, yoga.asanaCount),
                pranayama = pranayama.map {
                    CompanionPranayamaPreset(
                        typeRawValue = it.typeRawValue,
                        inhaleDuration = it.inhaleDuration,
                        hold1Duration = it.hold1Duration,
                        exhaleDuration = it.exhaleDuration,
                        hold2Duration = it.hold2Duration,
                        cycles = it.cycles
                    )
                },
                meditation = CompanionMeditationPreset(meditation.durationMinutes)
            ),
            recentEvents = recentEventsForSnapshot().map { it.toCompanionEvent() }
        )
    }
}

class PendingCommandRepository(
    private val dao: PendingCommandDao,
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    val commands: Flow<List<CompanionCommandPayload>> = dao.observeAll().map { rows ->
        rows.map { json.decodeFromString<CompanionCommandPayload>(it.commandJson) }
    }

    suspend fun enqueue(command: CompanionCommandPayload) = dao.upsert(command.toPendingEntity(json))

    suspend fun markDispatched(commandId: String) = dao.delete(commandId)

    suspend fun all(): List<CompanionCommandPayload> = dao.all().map {
        json.decodeFromString(it.commandJson)
    }
}
