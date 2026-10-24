package com.eartime.eartime_app.tracking

/** Read-only analytics over canonical, already clipped daily totals. Never fills collection gaps. */
object ListeningReport {
    fun build(snapshot: Map<String, Any?>, goalMinutes: Int, asOfUtcMs: Long): Map<String, Any?> {
        require(goalMinutes in 0..1440)
        val from = (snapshot["fromUtcMs"] as Number).toLong()
        val until = (snapshot["untilUtcMs"] as Number).toLong()
        val days = (snapshot["days"] as List<*>).map { it as Map<*, *> }
        val goal = goalMinutes * 60000L
        var best = 0
        var run = 0
        var current = 0
        var goalDays = 0
        var eligibleDays = 0
        var activeDays = 0
        var previousEnd: Long? = null
        days.forEach { day ->
            val start = (day["startUtcMs"] as Number).toLong()
            val end = (day["endUtcMs"] as Number).toLong()
            val total = (day["confirmedMs"] as Number).toLong()
            require(end > start && total >= 0)
            if (start >= asOfUtcMs) return@forEach
            if (total > 0) activeDays++
            // Partial custom-date buckets cannot establish a full calendar-day goal miss.
            val wholeDayInWindow = start >= from && end <= until
            val reached = goal > 0 && total >= goal
            if (wholeDayInWindow && end <= asOfUtcMs) eligibleDays++
            if (wholeDayInWindow && reached) goalDays++
            if (previousEnd != null && previousEnd != start) run = 0
            if (wholeDayInWindow && reached) {
                run++
                best = maxOf(best, run)
                current = run
            } else if (end <= asOfUtcMs || !wholeDayInWindow) {
                run = 0
                current = 0
            }
            previousEnd = end
        }
        val confirmed = (snapshot["confirmedMs"] as Number).toLong()
        val unverified = (snapshot["unverifiedMs"] as Number).toLong()
        val hasUncertainty = (snapshot["gapCount"] as Number).toLong() > 0 || unverified > 0
        val insight = when {
            confirmed == 0L && unverified > 0 -> "Playback was observed, but its output is unverified. It is excluded from listening totals."
            confirmed == 0L -> "No confirmed listening was recorded in this period. This does not establish that no listening occurred."
            goal > 0 && goalDays > 0 -> "Your recorded listening reached your personal goal on $goalDays day(s) in this period."
            else -> "Confirmed listening was recorded on $activeDays day(s) in this period."
        }
        val guidance = if (goal == 0L) "Set a personal duration goal in Settings to track recorded goal days."
            else "Your duration goal is a personal preference, not a safe sound-exposure limit. Unobserved time is excluded."
        return mapOf("version" to 1, "scope" to "selected_window_recorded_lower_bound",
            "activeDays" to activeDays, "goalMinutes" to goalMinutes, "goalDays" to goalDays,
            "completedCalendarDays" to eligibleDays, "currentRecordedStreak" to current,
            "bestRecordedStreak" to best, "hasUncertainty" to hasUncertainty,
            "averageActiveDayMs" to if (activeDays == 0) 0L else confirmed / activeDays,
            "insight" to insight, "guidance" to guidance)
    }
}
