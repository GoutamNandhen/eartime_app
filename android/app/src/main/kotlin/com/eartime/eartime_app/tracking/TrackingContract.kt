package com.eartime.eartime_app.tracking

import java.util.Locale
import java.util.UUID

@JvmInline
value class PhysicalDeviceId(val value: String) {
    init { require(UUID.fromString(value).toString() == value) }
    companion object { fun create() = PhysicalDeviceId(UUID.randomUUID().toString()) }
}

enum class AudioTransport { BLUETOOTH_CLASSIC, BLUETOOTH_LE, WIRED, USB }
enum class AudioProfile { A2DP, SCO, LE_HEADSET, LE_SPEAKER, LE_BROADCAST, WIRED, USB }
enum class AttributionConfidence { UNKNOWN, CANDIDATE, CONFIRMED }
enum class AliasEvidence { SAME_OBSERVED_ENDPOINT, USER_CONFIRMED }
enum class CapabilityAvailability { UNKNOWN, UNSUPPORTED, UNAVAILABLE, FRESH, STALE }

/** An endpoint is not a physical device: two transports require explicit association. */
data class TransportEndpoint(val transport: AudioTransport, val address: String) {
    init { require(address.isNotBlank()) }

    companion object {
        fun bluetooth(transport: AudioTransport, rawAddress: String?): TransportEndpoint? {
            require(transport == AudioTransport.BLUETOOTH_CLASSIC || transport == AudioTransport.BLUETOOTH_LE)
            val normalized = rawAddress?.trim()?.uppercase(Locale.ROOT) ?: return null
            if (!Regex("(?:[0-9A-F]{2}:){5}[0-9A-F]{2}").matches(normalized) ||
                normalized == "00:00:00:00:00:00" || normalized == "02:00:00:00:00:00") return null
            return TransportEndpoint(transport, normalized)
        }
    }
}

data class RouteId(val collectionEpoch: String, val systemId: String) {
    init { require(collectionEpoch.isNotBlank() && systemId.isNotBlank()) }
}

data class DeviceAlias(
    val deviceId: PhysicalDeviceId,
    val endpoint: TransportEndpoint,
    val evidence: AliasEvidence,
    val observationId: String,
) {
    init { require(observationId.isNotBlank()) }
}

data class PhysicalAudioDevice(
    val id: PhysicalDeviceId,
    val observedName: String?,
    val userName: String? = null,
) {
    val displayName: String get() = userName?.takeIf { it.isNotBlank() }
        ?: observedName?.takeIf { it.isNotBlank() } ?: "Audio device"
}

data class OutputRoute(
    val id: RouteId,
    val profile: AudioProfile,
    val endpoint: TransportEndpoint?,
    val deviceId: PhysicalDeviceId?,
    val isExternal: Boolean,
)

data class ObservationTime(
    val wallUtcMs: Long,
    val elapsedMs: Long?,
    val bootId: String?,
    val collectionEpoch: String,
) {
    init { require(elapsedMs == null || elapsedMs >= 0); require(collectionEpoch.isNotBlank()) }

    fun elapsedUntil(other: ObservationTime): Long? {
        if (collectionEpoch != other.collectionEpoch || bootId == null || bootId != other.bootId) return null
        val start = elapsedMs ?: return null
        val end = other.elapsedMs ?: return null
        return (end - start).takeIf { it >= 0 }
    }
}

data class CollectionGap(val previous: ObservationTime?, val resumed: ObservationTime, val reason: String)

data class RoutePlayback(
    val routeId: RouteId?,
    val isPlaying: Boolean,
    val confidence: AttributionConfidence,
)

/** Pure transition contract; global playback/legacy device claims never prove routing. */
class DeviceRouteState {
    private val routes = linkedMapOf<RouteId, OutputRoute>()
    private val playing = mutableSetOf<RouteId>()

    fun connect(route: OutputRoute) { routes[route.id] = route }
    fun disconnect(routeId: RouteId) { routes.remove(routeId); playing.remove(routeId) }
    fun gap() { routes.clear(); playing.clear() }

    fun playback(value: RoutePlayback) {
        val id = value.routeId ?: return
        val route = routes[id] ?: return
        if (value.confidence != AttributionConfidence.CONFIRMED || !route.isExternal || route.deviceId == null) {
            playing.remove(id)
        } else if (value.isPlaying) {
            playing.add(id)
        } else {
            playing.remove(id)
        }
    }

    fun isConnected(deviceId: PhysicalDeviceId) = routes.values.any { it.deviceId == deviceId }
    fun isListening(deviceId: PhysicalDeviceId) = routes.values.any {
        it.deviceId == deviceId && it.id in playing
    }
}
