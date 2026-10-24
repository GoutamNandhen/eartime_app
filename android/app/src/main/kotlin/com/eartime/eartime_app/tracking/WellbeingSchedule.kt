package com.eartime.eartime_app.tracking

import java.util.Calendar
import java.util.TimeZone
import android.util.JsonReader
import android.util.JsonToken
import java.io.StringReader

internal data class WellbeingPreferences(val daily: Boolean = false, val weekly: Boolean = false,
    val quiet: Boolean = true, val quietStart: Int = 1320, val quietEnd: Int = 420, val deliveryMinute: Int = 540) {
    fun wire(): Map<String, Any?> = mapOf("version" to 1, "daily" to daily, "weekly" to weekly,
        "quiet" to quiet, "quietStart" to quietStart, "quietEnd" to quietEnd, "deliveryMinute" to deliveryMinute)
    companion object {
        fun stored(raw: String?): WellbeingPreferences {
            if (raw == null) return WellbeingPreferences()
            require(raw.length <= 2048) { "Notification preferences exceed bound" }
            val values = linkedMapOf<String, Any?>()
            JsonReader(StringReader(raw)).use { reader ->
                require(reader.peek() == JsonToken.BEGIN_OBJECT)
                reader.beginObject()
                while (reader.hasNext()) {
                    require(values.size < 7)
                    val key = reader.nextName(); require(key.length <= 32 && key !in values)
                    values[key] = when (reader.peek()) {
                        JsonToken.BOOLEAN -> reader.nextBoolean()
                        JsonToken.NUMBER -> {
                            val number = reader.nextString().toLongOrNull() ?: throw IllegalArgumentException("Invalid notification minute")
                            require(number in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()); number.toInt()
                        }
                        else -> throw IllegalArgumentException("Invalid notification preference structure")
                    }
                }
                reader.endObject(); require(reader.peek() == JsonToken.END_DOCUMENT)
            }
            return decode(values)
        }
        fun decode(value: Any?): WellbeingPreferences {
            if (value == null) return WellbeingPreferences()
            require(value is Map<*, *> && value.keys == setOf("version", "daily", "weekly", "quiet", "quietStart", "quietEnd", "deliveryMinute"))
            fun number(key: String): Int {
                val raw = value[key]; require(raw is Int || raw is Long)
                val n = (raw as Number).toLong(); require(n in 0..1439); return n.toInt()
            }
            require(value["version"] == 1 && value["daily"] is Boolean && value["weekly"] is Boolean && value["quiet"] is Boolean)
            return WellbeingPreferences(value["daily"] as Boolean, value["weekly"] as Boolean, value["quiet"] as Boolean,
                number("quietStart"), number("quietEnd"), number("deliveryMinute"))
        }
    }
}

internal data class SummaryPlan(val kind: String, val dueUtcMs: Long, val fromUtcMs: Long, val untilUtcMs: Long,
    val zoneId: String, val key: String)

internal object WellbeingSchedule {
    val kinds = setOf("daily", "weekly")
    fun enabled(kind: String, preferences: WellbeingPreferences) = when (kind) {
        "daily" -> preferences.daily; "weekly" -> preferences.weekly; else -> false
    }
    fun quiet(at: Long, zone: String, preferences: WellbeingPreferences): Boolean {
        if (!preferences.quiet) return false
        val calendar = Calendar.getInstance(TimeZone.getTimeZone(zone)).apply { timeInMillis = at }
        val minute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        return if (preferences.quietStart < preferences.quietEnd) minute in preferences.quietStart until preferences.quietEnd
            else minute >= preferences.quietStart || minute < preferences.quietEnd
    }
    fun next(kind: String, now: Long, zone: String, preferences: WellbeingPreferences): SummaryPlan? {
        require(kind in kinds && ListeningTimeZones.valid(zone))
        if (!enabled(kind, preferences) || preferences.quiet && preferences.quietStart == preferences.quietEnd) return null
        val date = Calendar.getInstance(TimeZone.getTimeZone(zone)).apply {
            timeInMillis = now; set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, preferences.deliveryMinute / 60); set(Calendar.MINUTE, preferences.deliveryMinute % 60)
        }
        if (kind == "weekly") while (date.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) date.add(Calendar.DAY_OF_MONTH, -1)
        else date.add(Calendar.DAY_OF_MONTH, -1)
        fun due(): Calendar = (date.clone() as Calendar).apply {
            if (quiet(timeInMillis, zone, preferences)) {
                val minute = get(Calendar.HOUR_OF_DAY) * 60 + get(Calendar.MINUTE)
                if (preferences.quietStart > preferences.quietEnd && minute >= preferences.quietStart) add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, preferences.quietEnd / 60); set(Calendar.MINUTE, preferences.quietEnd % 60)
            }
        }
        var candidate = due()
        var attempts = 0
        while (candidate.timeInMillis <= now) {
            check(++attempts <= 3)
            date.add(Calendar.DAY_OF_MONTH, if (kind == "weekly") 7 else 1)
            candidate = due()
        }
        val until = (date.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val from = (until.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, if (kind == "daily") -1 else -7) }
        val key = "$kind:${until.get(Calendar.YEAR)}:${until.get(Calendar.DAY_OF_YEAR)}"
        check(candidate.timeInMillis > now && !quiet(candidate.timeInMillis, zone, preferences))
        return SummaryPlan(kind, candidate.timeInMillis, from.timeInMillis, until.timeInMillis, zone, key)
    }
}
