package com.eartime.eartime_app.tracking

enum class OutputEvidenceKind { CONNECTED_INVENTORY, GLOBAL_ACTIVITY, COMMUNICATION_DEVICE, PREDICTED_MEDIA, OWNED_PLAYER_ROUTING }

data class OutputEvidence(
    val kind: OutputEvidenceKind,
    val captured: ObservationTime,
    val ownerGeneration: Long,
    val routeId: RouteId?,
    val playerId: String?,
    val playing: Boolean?,
    val external: Boolean?,
    val deviceId: PhysicalDeviceId?,
    val mediaUsage: Boolean = false,
)

/** Inventory and policy predictions are never proof of another application's actual output. */
object OutputAttribution {
    fun confidence(evidence: OutputEvidence, current: ObservationTime, ownerGeneration: Long,
        currentRoute: OutputRoute?): AttributionConfidence {
        val age = evidence.captured.elapsedUntil(current) ?: return AttributionConfidence.UNKNOWN
        val drift = runCatching { Math.subtractExact(Math.subtractExact(current.wallUtcMs,
            evidence.captured.wallUtcMs), age) }.getOrNull() ?: return AttributionConfidence.UNKNOWN
        if (age > 1000 || evidence.ownerGeneration != ownerGeneration ||
            evidence.routeId?.collectionEpoch != current.collectionEpoch || currentRoute == null ||
            currentRoute.id != evidence.routeId || currentRoute.deviceId != evidence.deviceId ||
            currentRoute.isExternal != evidence.external ||
            drift !in -2000L..2000L) return AttributionConfidence.UNKNOWN
        if (evidence.kind != OutputEvidenceKind.OWNED_PLAYER_ROUTING) return AttributionConfidence.UNKNOWN
        return if (evidence.playerId.isNullOrBlank() || !evidence.mediaUsage || evidence.playing != true ||
            evidence.external != true || evidence.deviceId == null) AttributionConfidence.UNKNOWN
        else AttributionConfidence.CONFIRMED
    }
}
