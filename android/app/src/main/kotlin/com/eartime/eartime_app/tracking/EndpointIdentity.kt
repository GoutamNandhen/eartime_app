package com.eartime.eartime_app.tracking

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import java.util.UUID

internal data class EndpointObservation(val address: String, val wallUtcMs: Long, val elapsedMs: Long, val name: String?)

/** Identifiable transport evidence, not verified hardware identity or playback attribution. */
internal object EndpointIdentity {
    const val KIND = "ENDPOINT_IDENTITY"
    const val COLLECTOR = "device_identity_registry"
    fun validId(value: String) = runCatching { UUID.fromString(value).toString() == value }.getOrDefault(false)
    private fun integer(value: Any?): Long? = if (value is Int || value is Long) (value as Number).toLong() else null

    fun observations(input: ObservationInput): List<EndpointObservation> {
        if (input.kind != "OUTPUT_EVIDENCE" || input.collector != CollectorHealth.SOURCE || input.payloadVersion != 1) return emptyList()
        val sample = JSONObject(input.payloadJson).optJSONObject("a2dpTransport") ?: return emptyList()
        if (integer(sample.opt("contractVersion")) != 1L || sample.optString("apiSource") != "BluetoothA2dp.isA2dpPlaying" ||
            sample.optString("state") != "SAMPLED" || !validId(sample.optString("ownerId")) ||
            (integer(sample.opt("requestGeneration")) ?: 0) <= 0) return emptyList()
        val devices = sample.optJSONArray("devices") ?: return emptyList()
        if (devices.length() > 16 || input.time.elapsedMs == null) return emptyList()
        val result = mutableListOf<EndpointObservation>()
        for (index in 0 until devices.length()) {
            val row = devices.optJSONObject(index) ?: return emptyList()
            if (row.opt("connectedReported") != true || row.optString("profile") != "A2DP") continue
            val endpoint = TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, row.optString("endpointAddress")) ?: continue
            val elapsed = integer(row.opt("observedElapsedMs")) ?: continue
            val wall = integer(row.opt("observedWallUtcMs")) ?: continue
            val age = runCatching { Math.subtractExact(input.time.elapsedMs, elapsed) }.getOrNull() ?: continue
            val drift = runCatching { Math.subtractExact(Math.subtractExact(input.time.wallUtcMs, wall), age) }.getOrNull() ?: continue
            if (elapsed < 0 || age !in 0..1000 || drift !in -2000L..2000L) continue
            val name = (row.opt("observedName") as? String)?.filterNot { it.isISOControl() }?.take(80)?.takeIf { it.isNotBlank() }
            result.add(EndpointObservation(endpoint.address, wall, elapsed, name))
        }
        return if (result.map { it.address }.distinct().size == result.size) result else emptyList()
    }
}

/** Disposable cache of immutable identity observations in the canonical journal. */
internal class EndpointIdentityProjection(private val db: SQLiteDatabase) {
    companion object {
        fun create(db: SQLiteDatabase) {
            db.execSQL("""CREATE TABLE IF NOT EXISTS listening_endpoint_aliases (
                alias_id TEXT PRIMARY KEY NOT NULL, address TEXT UNIQUE NOT NULL,
                origin_device_id TEXT UNIQUE NOT NULL, device_id TEXT NOT NULL,
                evidence TEXT NOT NULL, revision INTEGER NOT NULL, first_observation_id TEXT NOT NULL)""")
            db.execSQL("CREATE INDEX IF NOT EXISTS listening_alias_device ON listening_endpoint_aliases(device_id)")
        }
    }
    fun alias(address: String): Map<String, Any?>? = db.rawQuery(
        "SELECT * FROM listening_endpoint_aliases WHERE address = ?", arrayOf(address),
    ).use { cursor -> if (!cursor.moveToFirst()) null else mapOf(
        "id" to cursor.getString(cursor.getColumnIndexOrThrow("alias_id")),
        "address" to cursor.getString(cursor.getColumnIndexOrThrow("address")),
        "originDeviceId" to cursor.getString(cursor.getColumnIndexOrThrow("origin_device_id")),
        "deviceId" to cursor.getString(cursor.getColumnIndexOrThrow("device_id")),
        "evidence" to cursor.getString(cursor.getColumnIndexOrThrow("evidence")),
        "revision" to cursor.getLong(cursor.getColumnIndexOrThrow("revision"))) }

    fun byId(id: String): Map<String, Any?>? = db.rawQuery("SELECT address FROM listening_endpoint_aliases WHERE alias_id=?", arrayOf(id))
        .use { if (it.moveToFirst()) alias(it.getString(0)) else null }

    fun details(deviceId: String, aliasOffset: Int, candidateOffset: Int, name: (String) -> String?): Map<String, Any?> {
        require(EndpointIdentity.validId(deviceId) && aliasOffset in 0..1000000 && candidateOffset in 0..1000000)
        val aliasCount = db.rawQuery("SELECT COUNT(*) FROM listening_endpoint_aliases WHERE device_id=? OR origin_device_id=?",
            arrayOf(deviceId, deviceId)).use { it.moveToFirst(); it.getInt(0) }
        val aliases = db.rawQuery("SELECT address FROM listening_endpoint_aliases WHERE device_id=? OR origin_device_id=? ORDER BY alias_id LIMIT 100 OFFSET ?",
            arrayOf(deviceId, deviceId, aliasOffset.toString())).use { rows -> buildList {
                while (rows.moveToNext()) alias(rows.getString(0))?.let { value ->
                    add(value - "address" + mapOf("endpointSuffix" to (value["address"] as String).takeLast(5),
                        "transport" to "BLUETOOTH_CLASSIC", "profile" to "A2DP"))
                }
            } }
        val candidateCount = db.rawQuery("SELECT COUNT(*) FROM listening_endpoint_aliases", null).use { it.moveToFirst(); it.getInt(0) }
        val candidates = db.rawQuery("SELECT a.origin_device_id, d.device_json FROM listening_endpoint_aliases a JOIN listening_devices d ON d.device_id=a.origin_device_id ORDER BY a.origin_device_id LIMIT 100 OFFSET ?",
            arrayOf(candidateOffset.toString())).use { rows -> buildList {
                while (rows.moveToNext()) {
                    val id = rows.getString(0)
                    add(mapOf("id" to id, "name" to (name(id) ?: JSONObject(rows.getString(1)).optString("name", "Bluetooth audio device"))))
                }
            } }
        return mapOf("version" to 1, "deviceId" to deviceId, "aliases" to aliases, "candidates" to candidates,
            "aliasOffset" to aliasOffset, "nextAliasOffset" to minOf(aliasOffset + aliases.size, aliasCount),
            "hasMoreAliases" to (aliasOffset + aliases.size < aliasCount),
            "candidateOffset" to candidateOffset, "nextCandidateOffset" to minOf(candidateOffset + candidates.size, candidateCount),
            "hasMoreCandidates" to (candidateOffset + candidates.size < candidateCount))
    }

    fun observe(input: ObservationInput, devices: JSONObject) {
        if (input.kind == "OUTPUT_EVIDENCE" && input.collector == CollectorHealth.SOURCE &&
            JSONObject(input.payloadJson).has("a2dpTransport")) {
            devices.keys().forEach { id ->
                val previous = devices.getJSONObject(id)
                if (previous.optString("identityKind") == "ENDPOINT_ASSOCIATED")
                    previous.put("connected", false).put("connectionState", "UNKNOWN")
            }
        }
        EndpointIdentity.observations(input).forEach { observed ->
            val association = alias(observed.address) ?: return@forEach
            val id = association["deviceId"] as String
            val previous = devices.optJSONObject(id) ?: db.rawQuery("SELECT device_json FROM listening_devices WHERE device_id = ?",
                arrayOf(id)).use { if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject() }
            previous.put("id", id).put("name", observed.name ?: previous.optString("name", "Bluetooth audio device"))
                .put("connected", true).put("lastSeenUtcMs", observed.wallUtcMs).put("nativeType", 8)
                .put("identityVerified", false).put("identityKind", "ENDPOINT_ASSOCIATED")
                .put("identityEvidence", association["evidence"]).put("transport", "BLUETOOTH_CLASSIC")
                .put("connectionState", "CONNECTED_REPORTED")
            devices.put(id, previous)
        }
    }

    fun apply(record: JournalObservation, devices: JSONObject, changed: (String) -> Unit) {
        if (record.input.kind != EndpointIdentity.KIND || record.input.collector != EndpointIdentity.COLLECTOR || record.input.payloadVersion != 1) return
        val payload = JSONObject(record.input.payloadJson)
        val endpoint = TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, payload.optString("address")) ?: return
        val id = payload.optString("deviceId")
        val aliasId = payload.optString("aliasId")
        if (!EndpointIdentity.validId(id) || !EndpointIdentity.validId(aliasId)) return
        val old = alias(endpoint.address)
        if (payload.optString("action") == "OBSERVED_ENDPOINT") {
            if (old != null) return
            val proofId = payload.optString("observationId")
            val proof = proof(proofId) ?: return
            if (proof.sequence >= record.sequence || EndpointIdentity.observations(proof.input).none { it.address == endpoint.address }) return
            db.insertOrThrow("listening_endpoint_aliases", null, ContentValues().apply {
                put("alias_id", aliasId); put("address", endpoint.address); put("origin_device_id", id); put("device_id", id)
                put("evidence", "SAME_OBSERVED_ENDPOINT"); put("revision", record.sequence); put("first_observation_id", proofId)
            })
            observe(proof.input, devices)
        } else if (payload.optString("action") in listOf("USER_ASSOCIATED", "RESET_ASSOCIATION")) {
            if (old == null || old["id"] != aliasId || old["revision"] != payload.optLong("expectedRevision", -1)) return
            val target = if (payload.optString("action") == "RESET_ASSOCIATION") old["originDeviceId"] as String else id
            val known = db.rawQuery("SELECT COUNT(*) FROM listening_endpoint_aliases WHERE origin_device_id = ?", arrayOf(target))
                .use { it.moveToFirst(); it.getLong(0) > 0 }
            if (!known) return
            if (old["deviceId"] != target) {
                changed(old["deviceId"] as String)
                devices.optJSONObject(old["deviceId"] as String)?.put("connected", false)?.put("connectionState", "UNKNOWN")
            }
            db.execSQL("UPDATE listening_endpoint_aliases SET device_id=?, evidence=?, revision=? WHERE alias_id=?", arrayOf(
                target, if (target == old["originDeviceId"]) "SAME_OBSERVED_ENDPOINT" else "USER_CONFIRMED", record.sequence, aliasId))
        }
    }

    private fun proof(id: String): JournalObservation? = db.rawQuery("SELECT * FROM observations WHERE observation_id = ?", arrayOf(id)).use {
        if (!it.moveToFirst()) null else {
            fun text(key: String): String = it.getString(it.getColumnIndexOrThrow(key))
            fun number(key: String): Long = it.getLong(it.getColumnIndexOrThrow(key))
            val elapsedIndex = it.getColumnIndexOrThrow("elapsed_ms")
            val bootIndex = it.getColumnIndexOrThrow("boot_id")
            JournalObservation("identity-evidence", number("sequence"), ObservationInput(text("observation_id"), text("kind"),
                text("collector"), text("process_generation"), ObservationTime(number("wall_utc_ms"),
                    if (it.isNull(elapsedIndex)) null else it.getLong(elapsedIndex),
                    if (it.isNull(bootIndex)) null else it.getString(bootIndex), text("collection_epoch")),
                text("payload_json"), text("provenance"), AttributionConfidence.valueOf(text("confidence")), number("payload_version").toInt()),
                number("committed_utc_ms"))
        }
    }
}
