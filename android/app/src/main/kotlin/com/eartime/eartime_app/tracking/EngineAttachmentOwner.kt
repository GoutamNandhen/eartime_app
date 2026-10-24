package com.eartime.eartime_app.tracking

/** Main-thread-owned lease; workers may read retirement. Cancellation is not retirement. */
class EngineAttachmentOwner(val token: String) {
    companion object {
        // Issued only on the main thread. This orders engine leases, not events.
        private var lastGeneration = 0L
    }

    val generation: Long = ++lastGeneration
    @Volatile var isActive: Boolean = true
        private set

    fun retire() { isActive = false }

    fun runIfActive(action: () -> Unit): Boolean {
        if (!isActive) return false
        action()
        return true
    }
}
