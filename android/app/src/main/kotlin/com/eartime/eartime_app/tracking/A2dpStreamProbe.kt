package com.eartime.eartime_app.tracking

import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Semaphore
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

internal interface A2dpDeviceRead {
    val address: String
    fun connected(): Boolean
    fun streaming(): Boolean
}
internal interface A2dpProfileRead : AutoCloseable { fun devices(): List<A2dpDeviceRead> }
internal interface A2dpProfileConnector : AutoCloseable {
    fun request(connected: (A2dpProfileRead) -> Unit, disconnected: () -> Unit): Boolean
}

/** Owns one public profile request. Main-looper callbacks only exchange references, never query IPC. */
internal class A2dpStreamProbe(
    private val connector: A2dpProfileConnector,
    private val clock: () -> AudioSampleTime,
    private val changed: () -> Unit,
    private val budget: Semaphore = sharedBudget,
    private val cleanup: (Runnable) -> Unit = { cleanupWorker.execute(it) },
) : AutoCloseable {
    companion object {
        private val sharedBudget = Semaphore(8)
        private val cleanupWorker = ThreadPoolExecutor(0, 1, 30, TimeUnit.SECONDS, ArrayBlockingQueue(8),
            { task -> Thread(task, "EarTimeA2dpCleanup").apply { isDaemon = true } })
    }
    private val lock = Any()
    private var closed = false
    private var requested = false
    private var ready = false
    private var profile: A2dpProfileRead? = null
    private var reason = "not_started"
    private var retryAfter = 0L
    private var ownsPermit = false
    private var permitMayRelease = true
    private val closeQueued = AtomicBoolean(false)
    private val ownerId = java.util.UUID.randomUUID().toString()
    private var requestGeneration = 0L

    fun start() {
        val generation = synchronized(lock) {
            if (closed || requested || profile != null || clock().elapsedMs < retryAfter) return
            if (!budget.tryAcquire()) { reason = "profile_capacity_unavailable"; return }
            ownsPermit = true
            requested = true
            reason = "profile_starting"
            ++requestGeneration
        }
        try {
            val accepted = connector.request({ value ->
                var dispose = false
                var unexpected = false
                synchronized(lock) {
                    if (profile == null) profile = value
                    if (profile !== value || !requested || !ownsPermit || generation != requestGeneration) {
                        // The public request owns one proxy. Unexpected replacements cannot supply evidence.
                        ready = false; reason = "profile_handle_changed"; closed = true
                        permitMayRelease = false; unexpected = true
                    } else if (closed) dispose = true
                    else { ready = true; reason = "profile_available" }
                }
                if (unexpected) {
                    try { cleanup(Runnable {
                        val original = synchronized(lock) { profile }
                        try { connector.close(); if (original !== value) value.close() }
                        catch (_: Exception) { synchronized(lock) { reason = "profile_cleanup_failed" } }
                        finally { original?.let(::disposeProfile) }
                    }) } catch (_: Exception) { synchronized(lock) { reason = "profile_cleanup_unavailable" } }
                } else if (dispose) disposeProfile(value) else changed()
            }, {
                synchronized(lock) { ready = false; if (!closed) reason = "profile_service_unavailable" }
                changed()
            })
            if (!accepted) synchronized(lock) {
                if (profile == null) {
                    requested = false; reason = "profile_request_unavailable"
                    retryAfter = clock().elapsedMs + 30000
                    releasePermit()
                }
            }
        } catch (error: Exception) {
            // A thrown request may have allocated an inaccessible proxy. Keep its reservation until a callback resolves it.
            synchronized(lock) { ready = false; reason = if (error is SecurityException) "permission_blocked" else "profile_request_failed" }
        }
    }

    fun sample(): Map<String, Any?> {
        start()
        val owned = synchronized(lock) { if (!closed && ready) profile else null }
            ?: return unknown(synchronized(lock) { reason })
        val before = clock()
        if (before.elapsedMs < 0) return unknown("sample_clock_or_deadline_lost")
        try {
            val devices = owned.devices()
            if (devices.size > 16) return unknown("device_sample_bound_exceeded")
            val rows = devices.map { device ->
                val endpoint = TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, device.address)
                val connectedBefore = device.connected()
                val streaming = device.streaming()
                val connectedAfter = device.connected()
                val at = clock()
                mapOf("endpointAddress" to endpoint?.address, "profile" to "A2DP",
                    "streamState" to if (endpoint != null && connectedBefore && connectedAfter && streaming)
                        "STREAMING_REPORTED" else "NOT_STREAMING_OR_API_UNAVAILABLE",
                    "observedWallUtcMs" to at.wallUtcMs, "observedElapsedMs" to at.elapsedMs)
            }
            val endpoints = rows.mapNotNull { it["endpointAddress"] as? String }
            if (endpoints.distinct().size != endpoints.size) return unknown("duplicate_endpoint_inventory")
            val after = clock()
            val duration = after.elapsedMs - before.elapsedMs
            val drift = runCatching { Math.subtractExact(Math.subtractExact(after.wallUtcMs, before.wallUtcMs), duration) }.getOrNull()
            if (after.elapsedMs < 0 || duration !in 0..1000 || drift == null || drift !in -2000L..2000L)
                return unknown("sample_clock_or_deadline_lost")
            if (synchronized(lock) { closed || !ready || profile !== owned }) return unknown("profile_owner_changed_during_sample")
            return envelope("SAMPLED", if (rows.isEmpty()) "empty_inventory_or_api_unavailable" else "public_profile_query",
                rows, after)
        } catch (error: Exception) {
            return unknown(if (error is SecurityException) "permission_blocked" else "profile_sample_unavailable")
        }
    }

    private fun unknown(reason: String) = envelope("UNKNOWN", reason, emptyList(), clock())
    private fun envelope(state: String, reason: String, devices: List<Map<String, Any?>>, at: AudioSampleTime) = mapOf(
        "contractVersion" to 1, "apiSource" to "BluetoothA2dp.isA2dpPlaying", "state" to state,
        "ownerId" to ownerId, "requestGeneration" to synchronized(lock) { requestGeneration },
        "reason" to reason, "devices" to devices, "capturedWallUtcMs" to at.wallUtcMs,
        "capturedElapsedMs" to at.elapsedMs, "confidence" to "UNKNOWN", "liveListeningEligible" to false)

    private fun releasePermit() {
        if (ownsPermit) { ownsPermit = false; budget.release() }
    }
    private fun disposeProfile(value: A2dpProfileRead) {
        if (!closeQueued.compareAndSet(false, true)) return
        try {
            cleanup(Runnable {
                try { value.close() }
                catch (_: Exception) { synchronized(lock) { reason = "profile_cleanup_failed" }; return@Runnable }
                synchronized(lock) { if (permitMayRelease) releasePermit() }
            })
        } catch (_: Exception) { synchronized(lock) { reason = "profile_cleanup_unavailable" } }
    }
    override fun close() {
        val owned = synchronized(lock) {
            if (closed) return
            closed = true; ready = false; reason = "observer_stopped"
            profile
        }
        try { connector.close() }
        finally { if (owned != null) disposeProfile(owned) }
    }
}
