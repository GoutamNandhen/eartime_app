package com.eartime.eartime_app.tracking

import android.content.Context
import java.util.UUID

class ListeningPreferences(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences("eartime_preferences_v1", Context.MODE_PRIVATE)
    fun snapshot(): Map<String, Any?> = mapOf("version" to 1,
        "themeMode" to preferences.getString("themeMode", "system"),
        "dailyGoalMinutes" to preferences.getInt("dailyGoalMinutes", 0),
        "deviceNames" to preferences.all.filterKeys { it.startsWith("device_name_") }
            .mapKeys { it.key.removePrefix("device_name_") })

    fun deviceName(id: String): String? = preferences.getString("device_name_$id", null)

    fun update(values: Map<String, Any?>): Map<String, Any?> {
        require(values.keys.all { it in setOf("themeMode", "dailyGoalMinutes", "deviceNames") })
        val editor = preferences.edit()
        if (values.containsKey("themeMode")) {
            val mode = values["themeMode"] as? String
            require(mode in setOf("system", "light", "dark"))
            editor.putString("themeMode", mode)
        }
        if (values.containsKey("dailyGoalMinutes")) {
            val goal = values["dailyGoalMinutes"]
            require(goal is Int && goal in 0..1440)
            editor.putInt("dailyGoalMinutes", goal)
        }
        if (values.containsKey("deviceNames")) {
            val names = values["deviceNames"] as? Map<*, *> ?: throw IllegalArgumentException("Invalid device names")
            require(names.size <= 2000)
            names.forEach { (id, name) ->
                require(id is String && runCatching { UUID.fromString(id).toString() == id }.getOrDefault(false))
                require(name is String && name.length <= 80 && name.none { Character.isISOControl(it) })
                if (name.isBlank()) editor.remove("device_name_$id") else editor.putString("device_name_$id", name.trim())
            }
            val known = preferences.all.keys.filter { it.startsWith("device_name_") }.toSet()
            require((known + names.keys.map { "device_name_$it" }).size <= 2000)
        }
        check(editor.commit()) { "Preferences could not be saved" }
        return snapshot()
    }
}
