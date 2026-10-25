package com.eartime.eartime_app.tracking

import android.content.Context
import org.json.JSONArray
import java.io.File

/** Typed restore payload, not a new preference store. Used only under the native restore/recovery owner. */
internal class ApplicationRestorePreferences private constructor(private val stores: Map<String, Map<String, Any>>) {
    companion object {
        fun read(file: File, validateCurrentSettings: Boolean): ApplicationRestorePreferences {
            val size = file.length()
            require(size in 1..524288)
            val bytes = ByteArray(size.toInt())
            java.io.DataInputStream(file.inputStream()).use { input -> input.readFully(bytes); require(input.read() == -1) }
            val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
                .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
            val root = JournalArchive.validatedObject(decoder.decode(java.nio.ByteBuffer.wrap(bytes)).toString())
            require(root.get("version") == 1)
            val rawStores = root.getJSONObject("stores")
            require(rawStores.keys().asSequence().toSet() == ApplicationArchive.stores.toSet())
            val stores = ApplicationArchive.stores.associateWith { store ->
                val rows = rawStores.getJSONArray(store); require(rows.length() <= 4096)
                val result = linkedMapOf<String, Any>()
                for (index in 0 until rows.length()) {
                    val row = rows.getJSONObject(index); val key = row.getString("key")
                    require(key.length in 1..256 && key !in result)
                    val value = row.get("value")
                    result[key] = when (row.getString("type")) {
                        "string" -> { require(value is String); value }
                        "int" -> { require(value is Int); value }
                        "long" -> { require(value is Int || value is Long); (value as Number).toLong() }
                        "boolean" -> { require(value is Boolean); value }
                        "float" -> { require(value is Number && value.toDouble().isFinite() && value.toFloat().isFinite()); value.toFloat() }
                        "strings" -> {
                            require(value is JSONArray)
                            val strings = (0 until value.length()).map { value.get(it).also { item -> require(item is String) } as String }
                            require(strings.distinct().size == strings.size); strings.toSet()
                        }
                        else -> error("Unsupported restored preference type")
                    }
                }
                result
            }
            if (validateCurrentSettings) {
                val preferences = stores.getValue("eartime_preferences_v1")
                preferences["themeMode"]?.let { require(it in setOf("system", "light", "dark")) }
                preferences["dailyGoalMinutes"]?.let { require(it is Int && it in 0..1440) }
                preferences["wellbeing_notifications_v1"]?.let { require(it is String); WellbeingPreferences.stored(it) }
                val names = preferences.filterKeys { it.startsWith("device_name_") }
                require(names.size <= 2000)
                names.forEach { (key, value) ->
                    require(EndpointIdentity.validId(key.removePrefix("device_name_")))
                    require(value is String && value.length <= 80 && value.none { Character.isISOControl(it) })
                }
                val delivery = stores.getValue("eartime_summary_delivery_v1")
                for (kind in listOf("daily", "weekly")) {
                    delivery["last_day_$kind"]?.let { require(it is Long) }
                    delivery["last_$kind"]?.let { require(it is String && it.length <= 256) }
                }
                delivery["lastResult"]?.let { require(it is String && it.length <= 256) }
            }
            return ApplicationRestorePreferences(stores)
        }
    }

    fun equivalent(context: Context): Boolean = stores.all { (name, values) ->
        context.getSharedPreferences(name, Context.MODE_PRIVATE).all == values
    }

    fun preserveDeliveryEvidence(context: Context): ApplicationRestorePreferences {
        val name = "eartime_summary_delivery_v1"
        val current = context.getSharedPreferences(name, Context.MODE_PRIVATE).all
        val delivery = stores.getValue(name).toMutableMap()
        for (kind in listOf("daily", "weekly")) {
            val key = "last_day_$kind"
            val old = current[key] as? Long
            val imported = delivery[key] as? Long
            if (old != null && (imported == null || old >= imported)) {
                delivery[key] = old
                val receipt = current["last_$kind"]
                if (receipt is String) delivery["last_$kind"] = receipt else delivery.remove("last_$kind")
            }
        }
        delivery.remove("lastResult")
        (current["lastResult"] as? String)?.let { delivery["lastResult"] = it }
        return ApplicationRestorePreferences(stores + (name to delivery))
    }

    fun apply(context: Context, beforeStore: (String) -> Unit = {}) {
        stores.forEach { (name, values) ->
            beforeStore(name)
            val editor = context.getSharedPreferences(name, Context.MODE_PRIVATE).edit().clear()
            values.forEach { (key, value) ->
                when (value) {
                    is String -> editor.putString(key, value)
                    is Int -> editor.putInt(key, value)
                    is Long -> editor.putLong(key, value)
                    is Boolean -> editor.putBoolean(key, value)
                    is Float -> editor.putFloat(key, value)
                    is Set<*> -> editor.putStringSet(key, value.filterIsInstance<String>().toSet())
                    else -> error("Unsupported restored preference value")
                }
            }
            check(editor.commit()) { "Application preferences could not be committed" }
        }
    }
}
