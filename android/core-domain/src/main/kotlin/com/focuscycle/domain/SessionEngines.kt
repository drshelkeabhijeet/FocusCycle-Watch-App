package com.focuscycle.domain

import java.time.Clock

data class TimerState(
    val isActive: Boolean = false,
    val elapsedSeconds: Int = 0,
    val remainingSeconds: Int = 0,
    val progress: Double = 0.0
)

class MeditationSessionEngine(
    private val durationSeconds: Int,
    private val clock: Clock = Clock.systemDefaultZone()
) {
    private var isActive = false
    private var startEpochMillis: Long? = null
    private var startRemainingSeconds = durationSeconds
    private var remainingSeconds = durationSeconds

    fun start() {
        if (isActive) return
        if (remainingSeconds <= 0) remainingSeconds = durationSeconds
        startRemainingSeconds = remainingSeconds
        startEpochMillis = clock.millis()
        isActive = true
    }

    fun pause(): TimerState {
        tick()
        isActive = false
        startEpochMillis = null
        return state()
    }

    fun reset(): TimerState {
        isActive = false
        startEpochMillis = null
        startRemainingSeconds = durationSeconds
        remainingSeconds = durationSeconds
        return state()
    }

    fun tick(): TimerState {
        if (isActive) {
            val elapsed = ((clock.millis() - (startEpochMillis ?: clock.millis())) / 1000).toInt()
            remainingSeconds = maxOf(0, startRemainingSeconds - elapsed)
            if (remainingSeconds == 0) isActive = false
        }
        return state()
    }

    fun state(): TimerState {
        val elapsed = durationSeconds - remainingSeconds
        return TimerState(
            isActive = isActive,
            elapsedSeconds = elapsed,
            remainingSeconds = remainingSeconds,
            progress = if (durationSeconds > 0) elapsed.toDouble() / durationSeconds else 0.0
        )
    }
}

data class YogaSessionState(
    val isActive: Boolean = false,
    val elapsedSeconds: Int = 0,
    val totalSeconds: Int,
    val currentPhaseIndex: Int = 0,
    val phaseRemainingSeconds: Int,
    val sessionProgress: Double = 0.0,
    val phaseProgress: Double = 0.0
)

class YogaSessionEngine(
    private val preset: YogaPreset,
    private val clock: Clock = Clock.systemDefaultZone()
) {
    private var isActive = false
    private var baseStartEpochMillis: Long? = null
    private var accumulatedPausedSeconds = 0

    private val phaseDurations: List<Int>
        get() = if (preset.operatingMode == OperatingMode.SingleInterval) {
            listOf(maxOf(1, preset.singleIntervalDurationSeconds))
        } else {
            listOf(maxOf(1, preset.holdSeconds), maxOf(0, preset.restSeconds))
        }

    private val totalSeconds: Int
        get() = if (preset.operatingMode == OperatingMode.SingleInterval) {
            maxOf(0, preset.singleIntervalSequenceDurationMinutes) * 60
        } else {
            maxOf(0, preset.asanaCount) * maxOf(1, preset.holdSeconds + preset.restSeconds)
        }

    fun start() {
        if (isActive) return
        baseStartEpochMillis = clock.millis()
        isActive = true
    }

    fun pause(): YogaSessionState {
        tick()
        accumulatedPausedSeconds = currentElapsedSeconds()
        baseStartEpochMillis = null
        isActive = false
        return state()
    }

    fun reset(): YogaSessionState {
        isActive = false
        baseStartEpochMillis = null
        accumulatedPausedSeconds = 0
        return state()
    }

    fun tick(): YogaSessionState {
        if (isActive && totalSeconds > 0 && currentElapsedSeconds() >= totalSeconds) {
            accumulatedPausedSeconds = totalSeconds
            baseStartEpochMillis = null
            isActive = false
        }
        return state()
    }

    fun state(): YogaSessionState {
        val elapsed = currentElapsedSeconds().coerceAtMost(maxOf(0, totalSeconds))
        val phases = phaseDurations
        val phaseCycle = phases.sum().coerceAtLeast(1)
        var cycleElapsed = elapsed % phaseCycle
        var index = 0
        var phaseDuration = phases.firstOrNull()?.coerceAtLeast(1) ?: 1
        for ((phaseIndex, duration) in phases.withIndex()) {
            val effective = duration.coerceAtLeast(1)
            if (cycleElapsed < effective) {
                index = phaseIndex
                phaseDuration = effective
                break
            }
            cycleElapsed -= effective
        }
        return YogaSessionState(
            isActive = isActive,
            elapsedSeconds = elapsed,
            totalSeconds = totalSeconds,
            currentPhaseIndex = index,
            phaseRemainingSeconds = maxOf(0, phaseDuration - cycleElapsed),
            sessionProgress = if (totalSeconds > 0) elapsed.toDouble() / totalSeconds else 0.0,
            phaseProgress = cycleElapsed.toDouble() / phaseDuration
        )
    }

    private fun currentElapsedSeconds(): Int {
        val start = baseStartEpochMillis ?: return accumulatedPausedSeconds
        return accumulatedPausedSeconds + ((clock.millis() - start) / 1000).toInt()
    }
}

data class PranayamaSessionState(
    val isActive: Boolean = false,
    val currentPhase: BreathingPhase,
    val phaseProgress: Double = 0.0,
    val cycleProgress: Double = 0.0,
    val currentCycle: Int = 1,
    val elapsedSeconds: Int = 0,
    val remainingSeconds: Int
)

class PranayamaSessionEngine(
    private val pattern: PranayamaPattern,
    private val clock: Clock = Clock.systemDefaultZone()
) {
    private var isActive = false
    private var sessionStartEpochMillis: Long? = null
    private var pausedElapsedSeconds = 0

    fun start() {
        if (isActive) return
        sessionStartEpochMillis = clock.millis() - pausedElapsedSeconds * 1000L
        isActive = true
    }

    fun pause(): PranayamaSessionState {
        pausedElapsedSeconds = elapsedSeconds()
        isActive = false
        return state()
    }

    fun reset(): PranayamaSessionState {
        isActive = false
        sessionStartEpochMillis = null
        pausedElapsedSeconds = 0
        return state()
    }

    fun tick(): PranayamaSessionState {
        if (isActive && elapsedSeconds() >= pattern.totalDurationSeconds) {
            pausedElapsedSeconds = pattern.totalDurationSeconds
            isActive = false
        }
        return state()
    }

    fun state(): PranayamaSessionState {
        val elapsed = elapsedSeconds().coerceAtMost(pattern.totalDurationSeconds)
        val cycleDuration = pattern.phases.sumOf { it.second }.coerceAtLeast(1)
        val cycleElapsed = elapsed % cycleDuration
        var cursor = 0
        var phase = pattern.phases.first().first
        var phaseProgress = 0.0
        for ((candidate, duration) in pattern.phases) {
            val safeDuration = duration.coerceAtLeast(1)
            if (cycleElapsed < cursor + safeDuration) {
                phase = candidate
                phaseProgress = (cycleElapsed - cursor).toDouble() / safeDuration
                break
            }
            cursor += safeDuration
        }
        return PranayamaSessionState(
            isActive = isActive,
            currentPhase = phase,
            phaseProgress = phaseProgress,
            cycleProgress = cycleElapsed.toDouble() / cycleDuration,
            currentCycle = (elapsed / cycleDuration) + 1,
            elapsedSeconds = elapsed,
            remainingSeconds = maxOf(0, pattern.totalDurationSeconds - elapsed)
        )
    }

    private fun elapsedSeconds(): Int {
        val start = sessionStartEpochMillis ?: return pausedElapsedSeconds
        return if (isActive) ((clock.millis() - start) / 1000).toInt() else pausedElapsedSeconds
    }
}
