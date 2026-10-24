package com.eartime.eartime_app.tracking

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone
import java.util.UUID
import kotlin.math.abs

/** A disposable, versioned read model. Observations are always the source of truth. */
internal class ListeningProjection(private val db: SQLiteDatabase) {
    companion object {
        const val VERSION = 2
        fun create(db: SQLiteDatabase) {
            db.execSQL("""CREATE TABLE listening_projection (
                singleton INTEGER PRIMARY KEY CHECK(singleton = 1), version INTEGER NOT NULL,
                sequence INTEGER NOT NULL, state_json TEXT NOT NULL)""")
            db.execSQL("""CREATE TABLE listening_intervals (
                interval_id TEXT PRIMARY KEY NOT NULL, route_key TEXT NOT NULL, device_id TEXT,
                attribution TEXT NOT NULL, start_utc_ms INTEGER NOT NULL, end_utc_ms INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL CHECK(duration_ms >= 0), open INTEGER NOT NULL,
                close_reason TEXT, start_sequence INTEGER NOT NULL, end_sequence INTEGER NOT NULL)""")
            db.execSQL("CREATE INDEX listening_interval_window ON listening_intervals(end_utc_ms, start_utc_ms)")
            createDevices(db)
        }
        fun createDevices(db: SQLiteDatabase) {
            db.execSQL("""CREATE TABLE listening_devices (
                device_id TEXT PRIMARY KEY NOT NULL, connected INTEGER NOT NULL,
                last_seen_utc_ms INTEGER NOT NULL, device_json TEXT NOT NULL)""")
            db.execSQL("CREATE INDEX listening_device_recent ON listening_devices(connected, last_seen_utc_ms)")
        }
    }

    private fun state(): JSONObject = db.rawQuery(
        "SELECT version, state_json FROM listening_projection WHERE singleton = 1", null,
    ).use {
        if (!it.moveToFirst()) JSONObject().put("routes", JSONObject())
        else { check(it.getInt(0) == VERSION) { "Projection version requires rebuild" }; JSONObject(it.getString(1)) }
    }

    fun cursor(): Long = db.rawQuery("SELECT sequence FROM listening_projection WHERE singleton = 1", null)
        .use { if (it.moveToFirst()) it.getLong(0) else 0 }

    fun reset() {
        db.delete("listening_intervals", null, null)
        db.delete("listening_projection", null, null)
        db.delete("listening_devices", null, null)
    }

    /** Called inside the observation transaction; a crash cannot advance only one side. */
    fun apply(observation: JournalObservation) {
        if (observation.sequence <= cursor()) return
        val input = observation.input
        val root = state()
        val routes = root.getJSONObject("routes")
        val devices = JSONObject()
        db.rawQuery("SELECT device_json FROM listening_devices WHERE connected = 1", null).use { rows ->
            while (rows.moveToNext()) JSONObject(rows.getString(0)).let { devices.put(it.getString("id"), it) }
        }
        val endpoints = root.optJSONObject("endpoints") ?: JSONObject().also { root.put("endpoints", it) }
        val payload = JSONObject(input.payloadJson)
        val time = input.time
        val previousEpoch = root.optString("epoch")
        if (previousEpoch.isNotEmpty() && previousEpoch != time.collectionEpoch || input.kind == "COLLECTION_GAP" || input.payloadVersion != 1) {
            routes.keys().asSequence().toList().forEach { close(routes, it, observation, false, "collection_gap") }
            devices.keys().forEach { devices.getJSONObject(it).put("connected", false) }
            endpoints.keys().asSequence().toList().forEach { endpoints.remove(it) }
            root.put("gapCount", root.optLong("gapCount") + 1)
        }
        root.put("epoch", time.collectionEpoch)

        fun legacyDevice(raw: JSONObject): String? {
            val nativeId = raw.optString("id")
            if (nativeId.isBlank()) return null
            // Legacy IDs may be names or fallback MACs. Scope them to this epoch, never merge as physical identity.
            val id = UUID.nameUUIDFromBytes("${time.collectionEpoch}:$nativeId".toByteArray()).toString()
            devices.put(id, JSONObject().put("id", id).put("name", raw.optString("friendlyName", "Audio device"))
                .put("nativeId", nativeId).put("connected", true).put("identityVerified", false)
                .put("lastSeenUtcMs", time.wallUtcMs).put("nativeType", raw.optInt("nativeType", -1)))
            return id
        }

        when (if (input.payloadVersion == 1) input.kind else "UNSUPPORTED_PAYLOAD") {
            "COLLECTION_GAP", "COLLECTION_STARTED" -> Unit
            "DEVICE_CONNECTED" -> payload.optJSONObject("device")?.let { legacyDevice(it) }
            "DEVICE_DISCONNECTED" -> {
                val nativeId = payload.optString("deviceId")
                devices.keys().forEach { key ->
                    val device = devices.getJSONObject(key)
                    if (device.optString("nativeId") == nativeId) device.put("connected", false)
                }
            }
            "SYNC_STATE" -> {
                val snapshot = if (payload.has("connectedDevices")) payload else payload.optJSONObject("device") ?: payload
                val list = snapshot.optJSONArray("connectedDevices")
                if (list != null) {
                    devices.keys().forEach { devices.getJSONObject(it).put("connected", false) }
                    for (index in 0 until list.length()) list.optJSONObject(index)?.let { legacyDevice(it) }
                    update(routes, "legacy-global", null, "UNVERIFIED", snapshot.optBoolean("isPlaying"), observation)
                }
            }
            "PLAYBACK_STARTED", "PLAYBACK_PAUSED" -> update(routes, "legacy-global", null, "UNVERIFIED",
                input.kind == "PLAYBACK_STARTED", observation)
            // Only typed native inputs with explicit CONFIRMED provenance can contribute listening time.
            // The protected legacy collector never emits these or sets this confidence.
            "ROUTE_PLAYBACK", "ROUTE_DISCONNECTED" -> {
                if (input.confidence == AttributionConfidence.CONFIRMED) {
                    val routeId = payload.optString("routeId")
                    val id = payload.optString("physicalDeviceId")
                    val validId = runCatching { UUID.fromString(id).toString() == id }.getOrDefault(false)
                    if (routeId.isNotBlank()) {
                        val key = "${time.collectionEpoch}:$routeId"
                        val active = input.kind != "ROUTE_DISCONNECTED" && payload.optBoolean("playing") &&
                            payload.optBoolean("external") && validId
                        if (input.kind == "ROUTE_DISCONNECTED") endpoints.remove(key)
                        else endpoints.put(key, if (validId) id else "")
                        if (validId) devices.put(id, JSONObject().put("id", id).put("identityVerified", true)
                            .put("name", payload.optString("name", "Audio device"))
                            .put("connected", input.kind != "ROUTE_DISCONNECTED").put("lastSeenUtcMs", time.wallUtcMs))
                        update(routes, key, if (validId) id else null, "CONFIRMED", active, observation)
                    }
                } else {
                    val key = "${time.collectionEpoch}:${payload.optString("routeId")}"
                    close(routes, key, observation, false, "attribution_lost")
                }
            }
        }
        devices.keys().forEach { id ->
            val device = devices.getJSONObject(id)
            if (device.optBoolean("identityVerified")) device.put("connected",
                endpoints.keys().asSequence().any { endpoints.optString(it) == id })
            db.insertWithOnConflict("listening_devices", null, ContentValues().apply {
                put("device_id", id); put("connected", if (device.optBoolean("connected")) 1 else 0)
                put("last_seen_utc_ms", device.optLong("lastSeenUtcMs")); put("device_json", device.toString())
            }, SQLiteDatabase.CONFLICT_REPLACE)
        }
        db.insertWithOnConflict("listening_projection", null, ContentValues().apply {
            put("singleton", 1); put("version", VERSION); put("sequence", observation.sequence)
            put("state_json", root.toString())
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }

    private fun comparable(route: JSONObject, time: ObservationTime): Long? {
        if (route.optString("epoch") != time.collectionEpoch || time.bootId == null ||
            route.optString("boot") != time.bootId || time.elapsedMs == null) return null
        val delta = time.elapsedMs - route.getLong("lastElapsed")
        if (delta < 0 || abs((time.wallUtcMs - route.getLong("lastWall")) - delta) > 2000) return null
        return time.elapsedMs - route.getLong("startElapsed")
    }

    private fun update(routes: JSONObject, key: String, device: String?, attribution: String,
        active: Boolean, observation: JournalObservation) {
        val old = routes.optJSONObject(key)
        if (old != null && (comparable(old, observation.input.time) == null || old.optString("device") != (device ?: ""))) {
            close(routes, key, observation, false, "continuity_unproven")
        }
        if (!active) { close(routes, key, observation, true, "stopped"); return }
        val time = observation.input.time
        val route = routes.optJSONObject(key) ?: JSONObject().put("intervalId", "${observation.input.id}:$key")
            .put("startWall", time.wallUtcMs).put("startElapsed", time.elapsedMs ?: 0)
            .put("epoch", time.collectionEpoch).put("boot", time.bootId ?: "")
            .put("device", device ?: "").put("attribution", attribution).put("startSequence", observation.sequence)
        route.put("lastElapsed", time.elapsedMs ?: 0).put("lastWall", time.wallUtcMs)
        routes.put(key, route)
        writeInterval(route, key, observation.sequence, true, null, comparable(route, time) ?: 0)
    }

    private fun close(routes: JSONObject, key: String, observation: JournalObservation, observedStop: Boolean, reason: String) {
        val route = routes.optJSONObject(key) ?: return
        val elapsed = if (observedStop) comparable(route, observation.input.time) else null
        val duration = elapsed ?: (route.getLong("lastElapsed") - route.getLong("startElapsed")).coerceAtLeast(0)
        writeInterval(route, key, observation.sequence, false, reason, duration)
        routes.remove(key)
    }

    private fun writeInterval(route: JSONObject, key: String, sequence: Long, open: Boolean, reason: String?, duration: Long) {
        db.insertWithOnConflict("listening_intervals", null, ContentValues().apply {
            put("interval_id", route.getString("intervalId")); put("route_key", key)
            put("device_id", route.optString("device").ifEmpty { null }); put("attribution", route.getString("attribution"))
            put("start_utc_ms", route.getLong("startWall")); put("end_utc_ms", route.getLong("startWall") + duration)
            put("duration_ms", duration); put("open", if (open) 1 else 0); put("close_reason", reason)
            put("start_sequence", route.getLong("startSequence")); put("end_sequence", sequence)
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }

    /** Intervals are clipped once here for all consumers. Overlapping routes are unioned, not added. */
    fun snapshot(from: Long, until: Long, zoneId: String, now: ObservationTime?, offset: Int = 0, limit: Int = 100): Map<String, Any?> {
        require(until > from && until - from in 1L..(367L * 86400000) &&
            offset in 0..(Int.MAX_VALUE - 100) && limit in 1..100)
        require(zoneId in TimeZone.getAvailableIDs()) { "Unknown calendar time zone" }
        val root = state()
        val routes = root.getJSONObject("routes")
        val segments = mutableListOf<Map<String, Any?>>()
        db.rawQuery("SELECT * FROM listening_intervals WHERE start_utc_ms < ? AND (end_utc_ms >= ? OR open = 1) ORDER BY start_sequence DESC LIMIT 100001",
            arrayOf(until.toString(), from.toString())).use { cursor ->
            var scanned = 0
            while (cursor.moveToNext()) {
                check(++scanned <= 100000) { "Projection window exceeds work limit; select a shorter date range" }
                fun long(name: String) = cursor.getLong(cursor.getColumnIndexOrThrow(name))
                fun text(name: String): String? = cursor.getString(cursor.getColumnIndexOrThrow(name))
                val start = long("start_utc_ms")
                var end = long("end_utc_ms")
                val open = long("open") == 1L
                val route = routes.optJSONObject(text("route_key") ?: "")
                val liveDuration = if (open && now != null && route != null) comparable(route, now) else null
                if (liveDuration != null) end = start + liveDuration
                val clippedStart = maxOf(start, from)
                val clippedEnd = minOf(end, until)
                if (clippedEnd < clippedStart || end < from) continue
                segments.add(mapOf("id" to text("interval_id"), "deviceId" to text("device_id"),
                    "attribution" to text("attribution"), "startUtcMs" to start, "endUtcMs" to end,
                    "clippedStartUtcMs" to clippedStart, "clippedEndUtcMs" to clippedEnd,
                    "durationMs" to (clippedEnd - clippedStart).coerceAtLeast(0), "open" to open, "live" to (liveDuration != null),
                    "closeReason" to text("close_reason")))
            }
        }
        fun spans(attribution: String) = segments.filter { it["attribution"] == attribution }
            .map { (it["clippedStartUtcMs"] as Long) to (it["clippedEndUtcMs"] as Long) }
        val confirmed = union(spans("CONFIRMED"))
        val unverified = union(spans("UNVERIFIED"))
        val confirmedTotal = duration(confirmed, from, until)
        val hourly = LongArray(24)
        confirmed.forEach { span ->
            var point = span.first
            while (point < span.second) {
                val hour = Calendar.getInstance(TimeZone.getTimeZone(zoneId)).apply { timeInMillis = point }
                val bucket = hour.get(Calendar.HOUR_OF_DAY)
                hour.set(Calendar.MINUTE, 0); hour.set(Calendar.SECOND, 0); hour.set(Calendar.MILLISECOND, 0)
                hour.add(Calendar.HOUR_OF_DAY, 1)
                val next = minOf(span.second, hour.timeInMillis)
                check(next > point)
                hourly[bucket] += next - point
                point = next
            }
        }
        val perDevice = segments.filter { it["attribution"] == "CONFIRMED" && it["deviceId"] != null }
            .groupBy { it["deviceId"] as String }.map { (id, intervals) ->
                mapOf("deviceId" to id, "durationMs" to duration(union(intervals.map {
                    (it["clippedStartUtcMs"] as Long) to (it["clippedEndUtcMs"] as Long)
                }), from, until))
            }
        val days = mutableListOf<Map<String, Any?>>()
        val calendar = Calendar.getInstance(TimeZone.getTimeZone(zoneId)).apply {
            timeInMillis = from; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        while (calendar.timeInMillis < until) {
            val start = calendar.timeInMillis
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            val end = calendar.timeInMillis
            days.add(mapOf("startUtcMs" to start, "endUtcMs" to end,
                "confirmedMs" to duration(confirmed, start, end), "unverifiedMs" to duration(unverified, start, end)))
        }
        val devices = db.rawQuery("SELECT device_json FROM listening_devices ORDER BY connected DESC, last_seen_utc_ms DESC, device_id LIMIT 100", null).use {
            buildList { while (it.moveToNext()) add(JournalJson.toValue(JSONObject(it.getString(0)))) }
        }
        val deviceCount = db.rawQuery("SELECT COUNT(*) FROM listening_devices", null).use { it.moveToFirst(); it.getLong(0) }
        return mapOf("projectionVersion" to VERSION, "sequence" to cursor(), "fromUtcMs" to from, "untilUtcMs" to until,
            "confirmedMs" to confirmedTotal, "unverifiedMs" to duration(unverified, from, until),
            "longestMs" to (confirmed.maxOfOrNull { it.second - it.first } ?: 0),
            "averageMs" to if (confirmed.isEmpty()) 0L else confirmedTotal / confirmed.size,
            "listeningRuns" to confirmed.count { it.second > it.first }, "perDevice" to perDevice,
            "hourly" to hourly.mapIndexed { hour, value -> mapOf("hour" to hour, "durationMs" to value) },
            "gapCount" to root.optLong("gapCount"), "days" to days,
            "devices" to devices, "deviceCount" to deviceCount,
            "intervals" to segments.drop(offset).take(limit), "intervalCount" to segments.size,
            "nextOffset" to minOf(offset + limit, segments.size), "hasMore" to (offset + limit < segments.size))
    }

    private fun union(spans: List<Pair<Long, Long>>): List<Pair<Long, Long>> {
        val result = mutableListOf<Pair<Long, Long>>()
        spans.sortedBy { it.first }.forEach { span ->
            val last = result.lastOrNull()
            if (last != null && span.first <= last.second) result[result.lastIndex] = last.first to maxOf(last.second, span.second)
            else result.add(span)
        }
        return result
    }

    private fun duration(spans: List<Pair<Long, Long>>, from: Long, until: Long): Long =
        spans.sumOf { (minOf(it.second, until) - maxOf(it.first, from)).coerceAtLeast(0) }
}
