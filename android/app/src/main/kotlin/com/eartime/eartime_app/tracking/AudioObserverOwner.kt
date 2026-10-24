package com.eartime.eartime_app.tracking

import java.util.UUID

internal data class AudioSampleTime(val wallUtcMs: Long, val elapsedMs: Long)

internal interface AudioObservationBackend {
    fun register(): AutoCloseable
    fun sample(): Map<String, Any?>
}

/** All methods and commit acknowledgments belong to one observer worker, not an Activity. */
internal class AudioObserverOwner(
    private val backend: AudioObservationBackend,
    private val clock: () -> AudioSampleTime,
    private val nextGeneration: () -> Long,
    private val emit: (Map<String, Any?>, AudioSampleTime, (Boolean) -> Unit) -> Unit,
) : AutoCloseable {
    private var registration: AutoCloseable? = null
    private var generation = 0L
    private var continuityEpoch = ""
    private var closed = false
    private var restartRequired = false
    private var awaitingCommit = false
    private var cleanupFailed = false
    private var retryAfterElapsedMs = 0L
    private var lastSample: AudioSampleTime? = null
    private val leaseMs = CollectorHealth.MAX_LEASE_MS

    private fun status(phase: String, at: AudioSampleTime, reason: String, completion: (Boolean) -> Unit = {}) {
        emit(mapOf("type" to "COLLECTOR_STATUS", "timestamp" to at.wallUtcMs,
            "contractVersion" to 1, "generation" to generation, "continuityEpoch" to continuityEpoch,
            "state" to phase, "reason" to reason, "leaseMs" to leaseMs,
            "deviceListenerRegistered" to (registration != null),
            "activityObservationReady" to (registration != null), "sampleSucceeded" to (phase == "HEALTHY")), at, completion)
    }

    fun start() {
        if (closed || cleanupFailed || registration != null || clock().elapsedMs < retryAfterElapsedMs) return
        generation = nextGeneration()
        continuityEpoch = UUID.randomUUID().toString()
        restartRequired = false
        awaitingCommit = false
        lastSample = null
        status("STARTING", clock(), "registering_supported_audio_observation")
        try {
            registration = backend.register()
            sample()
        } catch (error: Exception) { unavailable(error) }
    }

    fun sample() {
        if (closed) return
        if (registration == null) { start(); return }
        val at = clock()
        if (at.elapsedMs < retryAfterElapsedMs) return
        val last = lastSample
        val delta = last?.let { at.elapsedMs - it.elapsedMs }
        val drift = last?.let { runCatching { Math.subtractExact(Math.subtractExact(at.wallUtcMs, it.wallUtcMs), delta!!) }.getOrNull() }
        if (restartRequired || last != null && (delta!! < 0 || delta >= leaseMs || drift == null || drift !in -2000L..2000L)) {
            status("CONTINUITY_LOST", at, "lease_or_commit_or_clock_lost")
            cleanup(); start(); return
        }
        // One pending durable acknowledgment and at most one sample/second during callback storms.
        if (awaitingCommit || delta != null && delta < 1000) return
        try {
            val sample = backend.sample()
            val captured = clock()
            val sampleDuration = captured.elapsedMs - at.elapsedMs
            if (sampleDuration !in 0..1000) { unavailable(IllegalStateException("Sample exceeded capture deadline")); return }
            emit(sample + mapOf("type" to "OUTPUT_EVIDENCE", "timestamp" to captured.wallUtcMs,
                "contractVersion" to 1, "generation" to generation, "continuityEpoch" to continuityEpoch,
                "scope" to CollectorHealth.SCOPE, "confidence" to "UNKNOWN"), captured, {})
            lastSample = captured
            awaitingCommit = true
            val owner = generation
            status("HEALTHY", captured, "supported_api_sample_succeeded") { accepted ->
                if (!closed && owner == generation) {
                    awaitingCommit = false
                    if (!accepted) {
                        restartRequired = true
                        retryAfterElapsedMs = clock().elapsedMs + 10000
                    }
                }
            }
        } catch (error: Exception) { unavailable(error) }
    }

    private fun unavailable(error: Exception) {
        cleanup()
        if (error.suppressed.isNotEmpty()) cleanupFailed = true
        if (cleanupFailed) { status("UNKNOWN", clock(), "listener_cleanup_failed"); return }
        retryAfterElapsedMs = clock().elapsedMs + 30000
        status(if (error is SecurityException) "PERMISSION_BLOCKED" else "TEMPORARILY_UNAVAILABLE",
            clock(), if (error is SecurityException) "supported_audio_permission_denied" else "supported_audio_initialization_or_sample_failed")
    }

    private fun cleanup() {
        val handle = registration
        registration = null
        awaitingCommit = false
        try { handle?.close() }
        catch (_: Exception) { cleanupFailed = true; status("UNKNOWN", clock(), "listener_cleanup_failed") }
    }

    override fun close() {
        if (closed) return
        closed = true
        cleanup()
        status("STOPPED", clock(), "observer_owner_stopped")
    }
}
