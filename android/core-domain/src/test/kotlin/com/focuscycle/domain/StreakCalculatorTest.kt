package com.focuscycle.domain

import kotlin.test.Test
import kotlin.test.assertEquals
import java.time.LocalDate
import java.time.ZoneId

class StreakCalculatorTest {
    private val zone = ZoneId.of("UTC")

    @Test
    fun currentStreakCountsConsecutiveDaysFromToday() {
        val today = LocalDate.of(2026, 6, 11)
        val sessions = listOf(
            record(today),
            record(today.minusDays(1)),
            record(today.minusDays(2)),
            record(today.minusDays(4))
        )

        val data = StreakCalculator.recalculate(
            StreakData(sessions = sessions, totalSessions = sessions.size),
            zoneId = zone,
            nowEpochMillis = today.atStartOfDay(zone).toInstant().toEpochMilli()
        )

        assertEquals(3, data.currentStreak)
        assertEquals(3, data.longestStreak)
    }

    @Test
    fun currentStreakCanAnchorAtYesterday() {
        val today = LocalDate.of(2026, 6, 11)
        val sessions = listOf(record(today.minusDays(1)), record(today.minusDays(2)))

        val data = StreakCalculator.recalculate(
            StreakData(sessions = sessions, totalSessions = sessions.size),
            zoneId = zone,
            nowEpochMillis = today.atStartOfDay(zone).toInstant().toEpochMilli()
        )

        assertEquals(2, data.currentStreak)
        assertEquals(2, data.longestStreak)
    }

    private fun record(day: LocalDate): SessionRecord = SessionRecord(
        id = day.toString(),
        activityTypeRawValue = ActivityType.Yoga.rawValue,
        dateEpochMillis = day.atStartOfDay(zone).toInstant().toEpochMilli(),
        durationSeconds = 60
    )
}
