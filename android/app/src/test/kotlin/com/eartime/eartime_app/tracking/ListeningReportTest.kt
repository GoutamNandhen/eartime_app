package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class ListeningReportTest {
    private fun report(totals: List<Long>, now: Long = totals.size * DAY, goal: Int = 1,
        from: Long = 0, unverified: Long = 0, gap: Long = 0): Map<String, Any?> = ListeningReport.build(mapOf(
        "fromUtcMs" to from, "untilUtcMs" to totals.size * DAY,
        "confirmedMs" to totals.sum(), "unverifiedMs" to unverified, "gapCount" to gap,
        "days" to totals.mapIndexed { i, ms -> mapOf("startUtcMs" to i * DAY,
            "endUtcMs" to (i + 1) * DAY, "confirmedMs" to ms) }), goal, now)

    @Test fun goalsUseRecordedTotalsAndMissesBreakStreaksWithoutCallingThemBreaks() {
        val r = report(listOf(60000, 120000, 0, 60000, 60000))
        assertEquals(4, r["goalDays"])
        assertEquals(2, r["currentRecordedStreak"])
        assertEquals(2, r["bestRecordedStreak"])
        assertEquals(75000L, r["averageActiveDayMs"])
    }
    @Test fun unfinishedTodayDoesNotDestroyYesterdayStreakAndFutureDaysAreExcluded() {
        val r = report(listOf(60000, 60000, 0, 0), now = 2 * DAY + 1)
        assertEquals(2, r["currentRecordedStreak"])
        assertEquals(2, r["completedCalendarDays"])
    }
    @Test fun disabledGoalAndEmptyHistoryNeverDivideByZeroOrInventARecommendation() {
        val r = report(listOf(0, 0), goal = 0, unverified = 900000)
        assertEquals(0, r["bestRecordedStreak"])
        assertEquals(0L, r["averageActiveDayMs"])
        assertEquals(true, r["hasUncertainty"])
        assertTrue((r["insight"] as String).contains("output is unverified"))
    }
    @Test fun partialFirstCalendarDayCannotEstablishGoalMissOrAchievement() {
        val r = report(listOf(60000, 60000), from = 1000)
        assertEquals(1, r["goalDays"])
        assertEquals(1, r["bestRecordedStreak"])
    }
    @Test fun dstDaysUseNativeCalendarBucketAdjacencyRatherThan24HourDivision() {
        val r = ListeningReport.build(mapOf("fromUtcMs" to 0L, "untilUtcMs" to 47 * HOUR,
            "confirmedMs" to 120000L, "unverifiedMs" to 0L, "gapCount" to 1L,
            "days" to listOf(mapOf("startUtcMs" to 0L, "endUtcMs" to DAY, "confirmedMs" to 60000L),
                mapOf("startUtcMs" to DAY, "endUtcMs" to 47 * HOUR, "confirmedMs" to 60000L))), 1, 47 * HOUR)
        assertEquals(2, r["bestRecordedStreak"])
        assertEquals(true, r["hasUncertainty"])
    }
    companion object { const val HOUR = 3600000L; const val DAY = 24 * HOUR }
}
