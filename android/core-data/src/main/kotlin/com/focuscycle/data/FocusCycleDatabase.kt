package com.focuscycle.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import com.focuscycle.domain.CompanionCommandPayload
import com.focuscycle.domain.HRSamplePoint
import com.focuscycle.domain.SessionRecord
import kotlinx.serialization.decodeFromString
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Entity(tableName = "session_records")
data class SessionRecordEntity(
    @PrimaryKey val id: String,
    val activityTypeRawValue: String,
    val dateEpochMillis: Long,
    val durationSeconds: Int,
    val pattern: String?,
    val avgHeartRate: Double?,
    val avgRespiratoryRate: Double?,
    val activeEnergyKcal: Double?,
    val hrvPreSdnnMs: Double?,
    val hrvPostSdnnMs: Double?,
    val spo2PrePercent: Double?,
    val spo2PostPercent: Double?,
    val hrSamplesJson: String?
) {
    fun toDomain(json: Json): SessionRecord = SessionRecord(
        id = id,
        activityTypeRawValue = activityTypeRawValue,
        dateEpochMillis = dateEpochMillis,
        durationSeconds = durationSeconds,
        pattern = pattern,
        avgHeartRate = avgHeartRate,
        avgRespiratoryRate = avgRespiratoryRate,
        activeEnergyKcal = activeEnergyKcal,
        hrvPreSdnnMs = hrvPreSdnnMs,
        hrvPostSdnnMs = hrvPostSdnnMs,
        spo2PrePercent = spo2PrePercent,
        spo2PostPercent = spo2PostPercent,
        hrSamples = hrSamplesJson?.let { json.decodeFromString<List<HRSamplePoint>>(it) }
    )

    companion object {
        fun fromDomain(record: SessionRecord, json: Json) = SessionRecordEntity(
            id = record.id,
            activityTypeRawValue = record.activityTypeRawValue,
            dateEpochMillis = record.dateEpochMillis,
            durationSeconds = record.durationSeconds,
            pattern = record.pattern,
            avgHeartRate = record.avgHeartRate,
            avgRespiratoryRate = record.avgRespiratoryRate,
            activeEnergyKcal = record.activeEnergyKcal,
            hrvPreSdnnMs = record.hrvPreSdnnMs,
            hrvPostSdnnMs = record.hrvPostSdnnMs,
            spo2PrePercent = record.spo2PrePercent,
            spo2PostPercent = record.spo2PostPercent,
            hrSamplesJson = record.hrSamples?.let { json.encodeToString(it) }
        )
    }
}

@Entity(tableName = "pending_commands")
data class PendingCommandEntity(
    @PrimaryKey val id: String,
    val commandJson: String,
    val createdAtEpochMillis: Long
)

@Dao
interface SessionRecordDao {
    @Query("SELECT * FROM session_records ORDER BY dateEpochMillis DESC")
    fun observeAll(): Flow<List<SessionRecordEntity>>

    @Query("SELECT * FROM session_records ORDER BY dateEpochMillis DESC")
    suspend fun all(): List<SessionRecordEntity>

    @Query("SELECT * FROM session_records WHERE dateEpochMillis >= :cutoffEpochMillis ORDER BY dateEpochMillis DESC LIMIT :limit")
    suspend fun recentSince(cutoffEpochMillis: Long, limit: Int): List<SessionRecordEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(record: SessionRecordEntity)

    @Query("DELETE FROM session_records")
    suspend fun clear()
}

@Dao
interface PendingCommandDao {
    @Query("SELECT * FROM pending_commands ORDER BY createdAtEpochMillis ASC")
    fun observeAll(): Flow<List<PendingCommandEntity>>

    @Query("SELECT * FROM pending_commands ORDER BY createdAtEpochMillis ASC")
    suspend fun all(): List<PendingCommandEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(command: PendingCommandEntity)

    @Query("DELETE FROM pending_commands WHERE id = :id")
    suspend fun delete(id: String)

    @Query("DELETE FROM pending_commands")
    suspend fun clear()
}

@Database(
    entities = [SessionRecordEntity::class, PendingCommandEntity::class],
    version = 1,
    exportSchema = false
)
abstract class FocusCycleDatabase : RoomDatabase() {
    abstract fun sessionRecords(): SessionRecordDao
    abstract fun pendingCommands(): PendingCommandDao

    companion object {
        fun create(context: Context): FocusCycleDatabase = Room.databaseBuilder(
            context.applicationContext,
            FocusCycleDatabase::class.java,
            "focus_cycle.db"
        ).build()
    }
}

fun CompanionCommandPayload.toPendingEntity(json: Json): PendingCommandEntity =
    PendingCommandEntity(id = id, commandJson = json.encodeToString(this), createdAtEpochMillis = createdAtEpochMillis)
