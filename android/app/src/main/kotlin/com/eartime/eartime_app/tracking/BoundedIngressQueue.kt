package com.eartime.eartime_app.tracking

import java.util.ArrayDeque

sealed interface IngressEntry<out T> {
    data class Observation<T>(val value: T) : IngressEntry<T>
    data class Gap(val count: Long, val firstElapsedMs: Long, val lastElapsedMs: Long) : IngressEntry<Nothing>
}

/** After overflow, preserve FIFO and emit one gap before accepting later observations. */
class BoundedIngressQueue<T>(val capacity: Int) {
    init { require(capacity > 0) }
    private val pending = ArrayDeque<T>()
    private var loss: IngressEntry.Gap? = null

    @Synchronized fun offer(value: T, elapsedMs: Long): Boolean {
        val current = loss
        if (current != null || pending.size >= capacity) {
            loss = IngressEntry.Gap((current?.count ?: 0) + 1, current?.firstElapsedMs ?: elapsedMs, elapsedMs)
            return false
        }
        pending.addLast(value)
        return true
    }

    @Synchronized fun reject(elapsedMs: Long) {
        val current = loss
        loss = IngressEntry.Gap((current?.count ?: 0) + 1, current?.firstElapsedMs ?: elapsedMs, elapsedMs)
    }

    @Synchronized fun poll(): IngressEntry<T>? {
        val next = pending.pollFirst()
        if (next != null) return IngressEntry.Observation(next)
        return loss.also { loss = null }
    }

    @Synchronized fun hasWork() = pending.isNotEmpty() || loss != null
    @Synchronized fun pendingCount() = pending.size
}
