package com.eartime.eartime_app.tracking

import java.util.ArrayDeque

/** Main-thread-confined, volatile attachment state. This is not an event journal. */
class OwnedEventBuffer<T : Any>(private val capacity: Int? = null) {
    init { require(capacity == null || capacity >= 2) }
    private var engineOwner: EngineAttachmentOwner? = null
    // Constant-space high-water mark survives sink cancellation, not process death.
    private var newestEngineGeneration = Long.MIN_VALUE
    val owner: String? get() = engineOwner?.takeIf { it.isActive }?.token
    private var sink: ((T) -> Unit)? = null
    private val pending = ArrayDeque<T>()

    val pendingCount: Int get() = pending.size

    fun attach(ownerToken: EngineAttachmentOwner, sender: (T) -> Unit, replay: List<T> = emptyList()): Boolean {
        if (!ownerToken.isActive || ownerToken.generation < newestEngineGeneration) return false
        require(replay.size <= 2) { "Only two cached diagnostic snapshots may precede replay" }
        newestEngineGeneration = ownerToken.generation
        engineOwner = ownerToken
        sink = sender
        replay.asReversed().forEach(pending::addFirst)
        trim()
        return true
    }

    fun detach(ownerToken: String): Boolean {
        if (engineOwner?.token != ownerToken) return false
        engineOwner = null
        sink = null
        return true
    }

    fun enqueue(event: T) {
        pending.addLast(event)
        trim()
    }

    private fun trim() {
        if (capacity != null) while (pending.size > capacity) pending.removeFirst()
    }

    /** Successful return means a send attempt, not an acknowledgement from Dart. */
    fun drain(limit: Int): Int {
        require(limit in 1..64) { "Flush work must have a small explicit batch bound" }
        var sent = 0
        while (sent < limit) {
            if (engineOwner?.isActive != true) break
            val sender = sink ?: break
            val event = pending.peekFirst() ?: break
            sender(event)
            pending.removeFirst()
            sent++
        }
        return sent
    }
}
