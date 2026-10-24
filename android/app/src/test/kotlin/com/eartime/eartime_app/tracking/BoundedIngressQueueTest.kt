package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class BoundedIngressQueueTest {
    @Test fun overflowCannotReorderGapBeforeAlreadyAcceptedObservations() {
        val queue = BoundedIngressQueue<Int>(2)
        assertTrue(queue.offer(1, 100))
        assertTrue(queue.offer(2, 200))
        assertFalse(queue.offer(3, 300))
        assertEquals(IngressEntry.Observation(1), queue.poll())
        assertFalse(queue.offer(4, 400))
        assertEquals(IngressEntry.Observation(2), queue.poll())
        assertEquals(IngressEntry.Gap(2, 300, 400), queue.poll())
        assertTrue(queue.offer(5, 500))
        assertEquals(IngressEntry.Observation(5), queue.poll())
        assertNull(queue.poll())
    }

    @Test fun boundedMemoryWhileConsumerIsAbsent() {
        val queue = BoundedIngressQueue<Int>(16)
        repeat(10000) { queue.offer(it, it.toLong()) }
        assertEquals(16, queue.pendingCount())
        repeat(16) { assertEquals(IngressEntry.Observation(it), queue.poll()) }
        assertEquals(IngressEntry.Gap(9984, 16, 9999), queue.poll())
        assertFalse(queue.hasWork())
    }

    @Test fun legacyDeliveryRetainsAllEventsUntilCanonicalReplayReplacesIt() {
        val buffer = OwnedEventBuffer<Int>()
        repeat(1000) { buffer.enqueue(it) }
        assertEquals(1000, buffer.pendingCount)
        val received = mutableListOf<Int>()
        buffer.attach(EngineAttachmentOwner("latest"), received::add)
        while (buffer.pendingCount > 0) buffer.drain(32)
        assertEquals((0 until 1000).toList(), received)
    }
}
