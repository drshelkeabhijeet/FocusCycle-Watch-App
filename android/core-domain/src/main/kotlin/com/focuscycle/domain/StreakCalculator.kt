package com.focuscycle.domain

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

object StreakCalculator {
    fun recordSession(
        current: StreakData,
        session: SessionRecord,
        zoneId: ZoneId = ZoneId.systemDefault(),
        nowEpochMillis: Long = Instant.now().toEpochMilli()
    ): StreakData {
        val sessions = current.sessions + session
        val updated = current.copy(
            totalSessions = current.totalSessions + 1,
            lastSessionEpochMillis = session.dateEpochMillis,
            sessions = sessions
        )
        return recalculate(updated, zoneId, nowEpochMillis)
    }

    fun recalculate(
        data: StreakData,
        zoneId: ZoneId = ZoneId.systemDefault(),
        nowEpochMillis: Long = Instant.now().toEpochMilli()
    ): StreakData {
        val days = data.sessions
            .map { Instant.ofEpochMilli(it.dateEpochMillis).atZone(zoneId).toLocalDate() }
            .toSet()

        if (days.isEmpty()) {
            return data.copy(currentStreak = 0, longestStreak = 0)
        }

        val today = Instant.ofEpochMilli(nowEpochMillis).atZone(zoneId).toLocalDate()
        var cursor = when {
            today in days -> today
            today.minusDays(1) in days -> today.minusDays(1)
            else -> null
        }

        var currentStreak = 0
        while (cursor != null && cursor in days) {
            currentStreak += 1
            cursor = cursor.minusDays(1)
        }

        return data.copy(
            currentStreak = currentStreak,
            longestStreak = maxOf(data.longestStreak, longestStreak(days))
        )
    }

    private fun longestStreak(days: Set<LocalDate>): Int {
        if (days.isEmpty()) return 0
        val sorted = days.sorted()
        var longest = 1
        var run = 1
        for (index in 1 until sorted.size) {
            run = if (sorted[index - 1].plusDays(1) == sorted[index]) run + 1 else 1
            longest = maxOf(longest, run)
        }
        return longest
    }
}
