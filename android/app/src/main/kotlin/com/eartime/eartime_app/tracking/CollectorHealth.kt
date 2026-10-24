package com.eartime.eartime_app.tracking

import org.json.JSONObject

enum class CollectorPhase {
    NOT_STARTED, STARTING, HEALTHY, TEMPORARILY_UNAVAILABLE, PERMISSION_BLOCKED,
    SUSPENDED, STOPPED, UNKNOWN, CONTINUITY_LOST,
}

/** Folded into the existing projection transaction, never an independent source of truth. */
internal object CollectorHealth {
    const val SOURCE = "supported_audio_observer"
    const val SCOPE = "inventory_and_global_activity"
    const val MAX_LEASE_MS = 15000L

    fun lose(root: JSONObject, reason: String) {
        val state = root.optJSONObject("collectorHealth") ?: return
        state.put("state", CollectorPhase.CONTINUITY_LOST.name).put("reason", reason).put("leaseUntilElapsedMs", 0)
    }

    private fun comparable(state: JSONObject, time: ObservationTime): Boolean {
        val elapsed = time.elapsedMs ?: return false
        if (time.bootId == null || state.optString("bootId") != time.bootId ||
            state.optString("collectionEpoch") != time.collectionEpoch) return false
        val delta = elapsed - state.optLong("lastElapsedMs")
        val drift = runCatching { Math.subtractExact(Math.subtractExact(time.wallUtcMs,
            state.optLong("lastWallUtcMs")), delta) }.getOrNull() ?: return false
        return delta >= 0 && drift in -2000L..2000L
    }

    fun apply(root: JSONObject, observation: JournalObservation): Boolean {
        val input = observation.input
        if (input.collector != SOURCE || input.kind != "COLLECTOR_STATUS") return false
        if (input.payloadVersion != 1) { lose(root, "unsupported_health_payload"); return false }
        val payload = JSONObject(input.payloadJson)
        val old = root.optJSONObject("collectorHealth")
        val generation = payload.optLong("generation", 0)
        val epoch = payload.optString("continuityEpoch")
        val phase = runCatching { CollectorPhase.valueOf(payload.getString("state")) }.getOrNull()
        val sameOwner = old != null && old.optString("processGeneration") == input.processGeneration &&
            old.optString("collectionEpoch") == input.time.collectionEpoch
        // Late callbacks from retired owners must not revoke or renew a newer owner.
        if (sameOwner && generation < old!!.optLong("generation")) return false
        if (old == null && phase != CollectorPhase.STARTING) return false
        if (old != null && !sameOwner && phase != CollectorPhase.STARTING) return false
        val state = old ?: JSONObject().also { root.put("collectorHealth", it) }
        fun fail(reason: String) {
            state.put("state", CollectorPhase.CONTINUITY_LOST.name).put("reason", reason).put("leaseUntilElapsedMs", 0)
        }
        if (payload.optInt("contractVersion") != 1 || generation <= 0 || epoch.isBlank() || epoch.length > 128 ||
            input.time.elapsedMs == null || phase == null) {
            fail("invalid_health_evidence"); return false
        }
        if (phase == CollectorPhase.STARTING) {
            if (sameOwner && (generation <= state.optLong("generation") || epoch == state.optString("continuityEpoch"))) return false
            state.put("generation", generation).put("continuityEpoch", epoch)
                .put("ownerStopRecorded", false)
                .put("processGeneration", input.processGeneration).put("collectionEpoch", input.time.collectionEpoch)
                .put("bootId", input.time.bootId ?: "").put("scope", SCOPE)
        } else {
            if (!sameOwner || generation != state.optLong("generation") || epoch != state.optString("continuityEpoch")) return false
            if (phase == CollectorPhase.HEALTHY) {
                if (!comparable(state, input.time)) { fail("clock_discontinuity"); return false }
                val previous = state.optString("state")
                val lease = payload.optLong("leaseMs", 0)
                if (previous !in listOf("STARTING", "HEALTHY") ||
                    previous == "HEALTHY" && input.time.elapsedMs >= state.optLong("leaseUntilElapsedMs")) {
                    fail("lease_expired_or_owner_stopped"); return false
                }
                if (!payload.optBoolean("deviceListenerRegistered") || !payload.optBoolean("activityObservationReady") ||
                    !payload.optBoolean("sampleSucceeded") || lease !in 1..MAX_LEASE_MS ||
                    input.time.elapsedMs > Long.MAX_VALUE - lease) {
                    fail("initialization_or_sampling_unproven"); return false
                }
                state.put("leaseUntilElapsedMs", input.time.elapsedMs + lease)
            }
        }
        if (phase != CollectorPhase.HEALTHY) state.put("leaseUntilElapsedMs", 0)
        state.put("state", phase.name).put("reason", payload.optString("reason", phase.name.lowercase()))
            .put("lastElapsedMs", input.time.elapsedMs).put("lastWallUtcMs", input.time.wallUtcMs)
            .put("sourceSequence", observation.sequence)
        val stopped = phase == CollectorPhase.STOPPED && !state.optBoolean("ownerStopRecorded") &&
            payload.optString("reason") == "observer_owner_stopped"
        if (stopped) state.put("ownerStopRecorded", true)
        return stopped
    }

    fun snapshot(root: JSONObject, now: ObservationTime?): Map<String, Any?> {
        val state = root.optJSONObject("collectorHealth")
            ?: return mapOf("contractVersion" to 1, "state" to "UNKNOWN", "reason" to "no_collector_acknowledgment",
                "scope" to SCOPE, "liveListeningEligible" to false)
        val wire = JSONObject(state.toString()).put("contractVersion", 1).put("liveListeningEligible", false)
        if (state.optString("state") == "HEALTHY") {
            if (now == null || !comparable(state, now)) wire.put("state", "UNKNOWN").put("reason", "current_clock_unverified")
            else if (now.elapsedMs!! >= state.optLong("leaseUntilElapsedMs"))
                wire.put("state", "TEMPORARILY_UNAVAILABLE").put("reason", "lease_expired")
        }
        @Suppress("UNCHECKED_CAST")
        return JournalJson.toValue(wire) as Map<String, Any?>
    }
}
