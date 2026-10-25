package com.eartime.eartime_app.tracking

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone
import java.util.UUID
import kotlin.math.abs

internal object ListeningTimeZones {
    private val known = TimeZone.getAvailableIDs().toHashSet()
    fun valid(id: String) = id.length <= 64 && (id in known || TimeZone.getTimeZone(id).id == id)
}

/** A disposable, versioned read model. Observations are always the source of truth. */
internal class ListeningProjection(private val db: SQLiteDatabase) {
    companion object {
        const val VERSION = 5
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
            createDeviceIndex(db)
            createDevices(db)
            EndpointIdentityProjection.create(db)
        }
        fun createDevices(db: SQLiteDatabase) {
            db.execSQL("""CREATE TABLE listening_devices (
                device_id TEXT PRIMARY KEY NOT NULL, connected INTEGER NOT NULL,
                last_seen_utc_ms INTEGER NOT NULL, device_json TEXT NOT NULL)""")
            db.execSQL("CREATE INDEX listening_device_recent ON listening_devices(connected, last_seen_utc_ms)")
        }
        private fun createDeviceIndex(db: SQLiteDatabase) {
            db.execSQL("CREATE INDEX IF NOT EXISTS listening_interval_device_window ON listening_intervals(device_id, start_utc_ms, end_utc_ms)")
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

    fun collectorHealth(now: ObservationTime) = CollectorHealth.snapshot(state(), now)

    fun requiresUpgrade(): Boolean = db.rawQuery("SELECT version FROM listening_projection WHERE singleton=1", null).use {
        if (!it.moveToFirst()) true
        else if (it.getInt(0) == VERSION) false
        else { check(it.getInt(0) in 2..4) { "Unsupported listening projection version; source retained" }; true }
    }

    fun reset() {
        createDeviceIndex(db)
        EndpointIdentityProjection.create(db)
        db.delete("listening_endpoint_aliases", null, null)
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
            devices.keys().forEach { devices.getJSONObject(it).put("connected", false).put("connectionState", "UNKNOWN") }
            endpoints.keys().asSequence().toList().forEach { endpoints.remove(it) }
            root.put("gapCount", root.optLong("gapCount") + 1)
            CollectorHealth.lose(root, "collection_gap")
        }
        root.put("epoch", time.collectionEpoch)
        val identity = EndpointIdentityProjection(db)
        identity.apply(observation, devices) { previous ->
            routes.keys().asSequence().toList().forEach { key ->
                if (routes.getJSONObject(key).optString("device") == previous)
                    close(routes, key, observation, false, "device_identity_changed")
            }
        }
        identity.observe(input, devices)
        if (CollectorHealth.apply(root, observation)) {
            routes.keys().asSequence().toList().forEach { close(routes, it, observation, false, "service_owner_stopped") }
            root.put("gapCount", root.optLong("gapCount") + 1)
        }

        fun legacyDevice(raw: JSONObject): String? {
            val nativeId = raw.optString("id")
            if (nativeId.isBlank()) return null
            // Legacy IDs may be names or fallback MACs. Scope them to this epoch, never merge as physical identity.
            val id = UUID.nameUUIDFromBytes("${time.collectionEpoch}:$nativeId".toByteArray()).toString()
            devices.put(id, JSONObject().put("id", id).put("name", raw.optString("friendlyName", "Audio device"))
                .put("nativeId", nativeId).put("connected", true).put("identityVerified", false)
                .put("connectionState", "CONNECTED_REPORTED")
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
                        .put("connectionState", "DISCONNECTED_REPORTED").put("lastSeenUtcMs", time.wallUtcMs)
                }
            }
            "SYNC_STATE" -> {
                val snapshot = if (payload.has("connectedDevices")) payload else payload.optJSONObject("device") ?: payload
                val list = snapshot.optJSONArray("connectedDevices")
                if (list != null) {
                    devices.keys().forEach { devices.getJSONObject(it).put("connected", false).put("connectionState", "UNKNOWN") }
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
    fun snapshot(from: Long, until: Long, zoneId: String, now: ObservationTime?, offset: Int = 0, limit: Int = 100,
        deviceOffset: Int = 0, healthTime: ObservationTime? = now, deviceId: String? = null, sessionId: String? = null): Map<String, Any?> {
        require(until > from && until - from in 1L..(367L * 86400000) &&
            offset in 0..(Int.MAX_VALUE - 100) && deviceOffset in 0..(Int.MAX_VALUE - 100) && limit in 1..100)
        require(ListeningTimeZones.valid(zoneId)) { "Unknown calendar time zone" }
        require(deviceId == null || EndpointIdentity.validId(deviceId)) { "Invalid device history identity" }
        require(sessionId == null || sessionId.length in 1..512) { "Invalid session identity" }
        val root = state()
        val routes = root.getJSONObject("routes")
        val segments = mutableListOf<Map<String, Any?>>()
        val deviceClause = if (deviceId == null) "" else " AND i.device_id = ?"
        val intervalArgs = listOf(until.toString(), from.toString()) + listOfNotNull(deviceId)
        db.rawQuery("""SELECT i.*, s.collection_epoch AS session_epoch, s.boot_id AS session_boot,
            s.wall_utc_ms - s.elapsed_ms AS session_anchor, e.kind AS end_kind, e.payload_json AS end_payload
            FROM listening_intervals i JOIN observations s ON s.sequence = i.start_sequence
            JOIN observations e ON e.sequence = i.end_sequence
            WHERE i.start_utc_ms < ? AND (i.end_utc_ms >= ? OR i.open = 1)$deviceClause
            ORDER BY i.start_sequence DESC LIMIT 100001""",
            intervalArgs.toTypedArray()).use { cursor ->
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
                val transition = when {
                    open -> "LAST_OBSERVED"
                    text("close_reason") != "stopped" -> "CONTINUITY_LOST"
                    text("end_kind") == "ROUTE_DISCONNECTED" -> "DISCONNECTED"
                    text("end_kind") == "PLAYBACK_PAUSED" -> "PAUSED"
                    text("end_kind") == "ROUTE_PLAYBACK" -> if (JSONObject(text("end_payload")!!).optBoolean("external")) "PAUSED" else "OUTPUT_CHANGED"
                    else -> "STOPPED"
                }
                segments.add(mapOf("id" to text("interval_id"), "deviceId" to text("device_id"),
                    "attribution" to text("attribution"), "startUtcMs" to start, "endUtcMs" to end,
                    "clippedStartUtcMs" to clippedStart, "clippedEndUtcMs" to clippedEnd,
                    "durationMs" to (clippedEnd - clippedStart).coerceAtLeast(0), "open" to open, "live" to (liveDuration != null),
                    "closeReason" to text("close_reason"), "transition" to transition,
                    "sessionEpoch" to text("session_epoch"), "sessionBoot" to text("session_boot"),
                    "sessionAnchor" to if (cursor.isNull(cursor.getColumnIndexOrThrow("session_anchor"))) null else long("session_anchor"),
                    "startSequence" to long("start_sequence"), "endSequence" to long("end_sequence")))
            }
        }
        val barriers = segments.filter { it["closeReason"] != null && it["closeReason"] != "stopped" }
            .map { it["endSequence"] as Long }.toMutableSet()
        if (segments.isNotEmpty()) {
            db.rawQuery("""SELECT sequence FROM observations WHERE sequence BETWEEN ? AND ?
                AND (kind = 'COLLECTION_GAP' OR payload_version <> 1) LIMIT 100001""",
                arrayOf(segments.minOf { it["startSequence"] as Long }.toString(),
                    segments.maxOf { it["endSequence"] as Long }.toString())).use { rows ->
                var scanned = 0
                while (rows.moveToNext()) {
                    check(++scanned <= 100000) { "Session boundaries exceed work limit; select a shorter date range" }
                    barriers.add(rows.getLong(0))
                }
            }
        }
        val sessions = ListeningSessions.group(segments, barriers.sorted())
        val sessionSummaries = sessions.map { it.summary() }
        val measuredSessions = sessionSummaries.filter { it["attribution"] == "CONFIRMED" && (it["durationMs"] as Long) > 0 }
        // A clipped summary is not a new opening. Count only measured groups whose ORIGINAL start is in the window.
        val measuredStarts = sessions.filter { it.first["attribution"] == "CONFIRMED" && it.end > it.start }
            .map { group -> group.segments.minOf { it["startUtcMs"] as Long } }
            .filter { it >= from && it < until }.sorted()
        val hourlyStarts = IntArray(24)
        val startCalendar = Calendar.getInstance(TimeZone.getTimeZone(zoneId))
        measuredStarts.forEach { start -> startCalendar.timeInMillis = start; hourlyStarts[startCalendar.get(Calendar.HOUR_OF_DAY)]++ }
        val detail = sessionId?.let { id ->
            val group = sessions.firstOrNull { it.id == id }
                ?: error("Session changed or is outside this window; reopen the timeline")
            val parts = group.segments.sortedBy { it["startSequence"] as Long }
            group.summary() + mapOf("offset" to offset, "nextOffset" to minOf(offset + limit, parts.size),
                "hasMore" to (offset + limit < parts.size),
                "intervals" to parts.drop(offset).take(limit).map(ListeningSessions::publicInterval))
        }
        fun spans(attribution: String) = segments.filter { it["attribution"] == attribution }
            .map { (it["clippedStartUtcMs"] as Long) to (it["clippedEndUtcMs"] as Long) }
        val confirmed = union(spans("CONFIRMED")).filter { it.second > it.first }
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
        var startCursor = 0
        val calendar = Calendar.getInstance(TimeZone.getTimeZone(zoneId)).apply {
            timeInMillis = from; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        while (calendar.timeInMillis < until) {
            val start = calendar.timeInMillis
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            val end = calendar.timeInMillis
            val firstStart = startCursor
            while (startCursor < measuredStarts.size && measuredStarts[startCursor] < end) startCursor++
            days.add(mapOf("startUtcMs" to start, "endUtcMs" to end,
                "confirmedMs" to duration(confirmed, start, end), "unverifiedMs" to duration(unverified, start, end),
                "measuredSessionStarts" to (startCursor - firstStart)))
        }
        val deviceWhere = if (deviceId == null) "" else " WHERE device_id = ?"
        val devices = db.rawQuery("SELECT device_json FROM listening_devices$deviceWhere ORDER BY connected DESC, last_seen_utc_ms DESC, device_id LIMIT 100 OFFSET ?",
            (listOfNotNull(deviceId) + deviceOffset.toString()).toTypedArray()).use {
            buildList { while (it.moveToNext()) add(JournalJson.toValue(JSONObject(it.getString(0)))) }
        }
        val deviceCount = db.rawQuery("SELECT COUNT(*) FROM listening_devices$deviceWhere", listOfNotNull(deviceId).toTypedArray())
            .use { it.moveToFirst(); it.getLong(0) }
        return mapOf("projectionVersion" to VERSION, "sequence" to cursor(), "fromUtcMs" to from, "untilUtcMs" to until,
            "filterDeviceId" to deviceId,
            "confirmedMs" to confirmedTotal, "unverifiedMs" to duration(unverified, from, until),
            "longestMs" to (confirmed.maxOfOrNull { it.second - it.first } ?: 0),
            "averageMs" to if (confirmed.isEmpty()) 0L else confirmedTotal / confirmed.size,
            "listeningRuns" to confirmed.count { it.second > it.first }, "perDevice" to perDevice,
            "hourly" to hourly.mapIndexed { hour, value -> mapOf("hour" to hour, "durationMs" to value,
                "measuredSessionStarts" to hourlyStarts[hour]) },
            "frequencyContractVersion" to 1, "measuredSessionStarts" to measuredStarts.size,
            "gapCount" to root.optLong("gapCount"), "days" to days,
            "devices" to devices, "deviceCount" to deviceCount,
            "collectorHealth" to CollectorHealth.snapshot(root, healthTime),
            "deviceOffset" to deviceOffset, "nextDeviceOffset" to minOf(deviceOffset.toLong() + devices.size, deviceCount),
            "hasMoreDevices" to (deviceOffset.toLong() + devices.size < deviceCount),
            "sessionContractVersion" to 1, "sessions" to sessionSummaries.drop(offset).take(limit),
            "measuredSessionCount" to measuredSessions.size,
            "longestSessionMs" to (measuredSessions.maxOfOrNull { it["durationMs"] as Long } ?: 0L),
            "averageSessionMs" to if (measuredSessions.isEmpty()) 0L else measuredSessions.sumOf { it["durationMs"] as Long } / measuredSessions.size,
            "sessionCount" to sessions.size, "nextSessionOffset" to minOf(offset + limit, sessions.size),
            "hasMoreSessions" to (offset + limit < sessions.size), "sessionDetail" to detail,
            "intervals" to segments.drop(offset).take(limit).map(ListeningSessions::publicInterval), "intervalCount" to segments.size,
            "openIntervalCount" to segments.count { it["open"] == true },
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
