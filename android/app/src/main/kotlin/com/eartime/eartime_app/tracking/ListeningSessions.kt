package com.eartime.eartime_app.tracking

/** Query-only grouping: a pause ends a session. No silence between observations is inferred. */
internal object ListeningSessions {
    private val privateKeys = setOf("sessionEpoch", "sessionBoot", "sessionAnchor", "startSequence", "endSequence")
    fun publicInterval(value: Map<String, Any?>) = value.filterKeys { it !in privateKeys }

    class Group(val segments: MutableList<Map<String, Any?>>) {
        var first = segments.single()
            private set
        val id get() = first["id"] as String
        var start = first["clippedStartUtcMs"] as Long
            private set
        var end = first["clippedEndUtcMs"] as Long
            private set
        fun add(part: Map<String, Any?>) {
            segments.add(part)
            if ((part["startSequence"] as Long) < (first["startSequence"] as Long)) first = part
            start = minOf(start, part["clippedStartUtcMs"] as Long)
            end = maxOf(end, part["clippedEndUtcMs"] as Long)
        }
        fun summary(): Map<String, Any?> = mapOf(
            "id" to id, "attribution" to first["attribution"],
            "startUtcMs" to start, "endUtcMs" to end, "durationMs" to (end - start),
            "segmentCount" to segments.size,
            "deviceCount" to segments.mapNotNull { it["deviceId"] as String? }.distinct().size,
            "incomplete" to segments.any { it["open"] == true || it["closeReason"] != "stopped" },
            "clipped" to segments.any { it["startUtcMs"] != it["clippedStartUtcMs"] || it["endUtcMs"] != it["clippedEndUtcMs"] },
        )
    }

    fun group(intervals: List<Map<String, Any?>>, barriers: List<Long>): List<Group> {
        fun fence(sequence: Long): Int {
            val found = barriers.binarySearch(sequence)
            return if (found >= 0) found + 1 else -found - 1
        }
        val domains = intervals.groupBy {
            listOf(it["attribution"], it["sessionEpoch"], it["sessionBoot"], fence(it["startSequence"] as Long))
        }
        val result = mutableListOf<Group>()
        domains.values.forEach { members ->
            var current: Group? = null
            var minAnchor = 0L
            var maxAnchor = 0L
            members.sortedWith(compareBy({ it["clippedStartUtcMs"] as Long }, { it["startSequence"] as Long })).forEach { part ->
                val start = part["clippedStartUtcMs"] as Long
                val end = part["clippedEndUtcMs"] as Long
                val anchor = part["sessionAnchor"] as Long?
                val eligible = end > start && anchor != null && part["sessionBoot"] != null &&
                    (part["open"] == true || part["closeReason"] == "stopped")
                val previous = current
                if (eligible && previous != null && start < previous.end &&
                    maxOf(maxAnchor, anchor!!) - minOf(minAnchor, anchor) <= 2000) {
                    previous.add(part)
                    minAnchor = minOf(minAnchor, anchor); maxAnchor = maxOf(maxAnchor, anchor)
                } else {
                    val next = Group(mutableListOf(part))
                    result.add(next)
                    current = if (eligible) next else null
                    minAnchor = anchor ?: 0; maxAnchor = minAnchor
                }
            }
        }
        // Source order remains deterministic when the wall clock moves backward.
        return result.sortedByDescending { it.first["startSequence"] as Long }
    }
}
