package com.eartime.eartime_app.tracking

/** Process-local one-shot authorization, never restored or inferred from connection state. */
internal class BleDiagnosticConsent(private val elapsed: () -> Long) {
    private var pending: Pair<String, Long>? = null
    @Synchronized fun grant(address: String) {
        val endpoint = TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, address)
            ?: throw IllegalArgumentException("Explicit valid endpoint required")
        val now = elapsed()
        require(now >= 0)
        pending = endpoint.address to now
    }
    @Synchronized fun consume(address: String): Boolean {
        val value = pending ?: return false
        pending = null
        val endpoint = TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, address) ?: return false
        val age = runCatching { Math.subtractExact(elapsed(), value.second) }.getOrNull() ?: return false
        return endpoint.address == value.first && age in 0..15000
    }
    @Synchronized fun revoke() { pending = null }
}

internal object BleDiagnosticAuthorization {
    val consent = BleDiagnosticConsent(android.os.SystemClock::elapsedRealtime)
}
