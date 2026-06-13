package com.focuscycle.health

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.core.content.ContextCompat
import com.focuscycle.domain.HRSamplePoint
import com.focuscycle.domain.SessionHealthMetrics
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Instant

interface HealthSessionRepository {
    val bpm: Flow<Int?>
    fun hasBodySensorPermission(): Boolean
    fun start()
    fun stop(): SessionHealthMetrics
}

class WearHealthSessionRepository(
    private val context: Context
) : HealthSessionRepository, SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val heartRateSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
    private val _bpm = MutableStateFlow<Int?>(null)
    private val samples = mutableListOf<Pair<Long, Int>>()
    private var startedAtEpochMillis: Long? = null

    override val bpm: Flow<Int?> = _bpm.asStateFlow()

    override fun hasBodySensorPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.BODY_SENSORS) == PackageManager.PERMISSION_GRANTED

    override fun start() {
        if (!hasBodySensorPermission() || heartRateSensor == null) return
        startedAtEpochMillis = Instant.now().toEpochMilli()
        samples.clear()
        sensorManager.registerListener(this, heartRateSensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun stop(): SessionHealthMetrics {
        sensorManager.unregisterListener(this)
        val hrSamples = downsample()
        val avg = if (samples.isEmpty()) null else samples.map { it.second }.average()
        _bpm.value = null
        return SessionHealthMetrics(
            avgHeartRate = avg,
            hrSamples = hrSamples.ifEmpty { null }
        )
    }

    override fun onSensorChanged(event: SensorEvent) {
        val value = event.values.firstOrNull()?.toInt() ?: return
        if (value <= 0) return
        _bpm.value = value
        samples += Instant.now().toEpochMilli() to value
        if (samples.size > 240) {
            samples.removeAt(0)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun downsample(): List<HRSamplePoint> {
        val start = startedAtEpochMillis ?: return emptyList()
        val buckets = linkedMapOf<Int, MutableList<Int>>()
        for ((time, bpm) in samples) {
            val bucket = (((time - start).coerceAtLeast(0)) / 1000 / 5).toInt()
            buckets.getOrPut(bucket) { mutableListOf() } += bpm
        }
        return buckets.map { (bucket, values) ->
            HRSamplePoint(t = bucket * 5, bpm = values.average().toInt())
        }.takeLast(720)
    }
}

data class BaselineHealthSnapshot(
    val restingHeartRate: Double? = null,
    val vo2Max: Double? = null,
    val latestSpO2: Double? = null,
    val latestRespiratoryRate: Double? = null,
    val lastNightSleepHours: Double? = null
)

interface BaselineHealthRepository {
    suspend fun readBaseline(): BaselineHealthSnapshot
}

class HealthConnectBaselineRepository(
    private val context: Context
) : BaselineHealthRepository {
    override suspend fun readBaseline(): BaselineHealthSnapshot {
        // Health Connect availability and record providers vary by device. The
        // phone app treats every value as optional and renders unavailable data
        // explicitly instead of inventing estimates.
        return BaselineHealthSnapshot()
    }
}
