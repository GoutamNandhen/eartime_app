package com.eartime.eartime_app.tracking

/** Main-thread-only engine lease. Cancellation is not retirement; cleanup is. */
class EngineAttachmentOwner(val token: String) {
    companion object {
        // Issued only on the main thread. This orders engine leases, not events.
        private var lastGeneration = 0L
    }

    val generation: Long = ++lastGeneration
    var isActive: Boolean = true
        private set

    fun retire() { isActive = false }

    fun runIfActive(action: () -> Unit): Boolean {
        if (!isActive) return false
        action()
        return true
    }
}
