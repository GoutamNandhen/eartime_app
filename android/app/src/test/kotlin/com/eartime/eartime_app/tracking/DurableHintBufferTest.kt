package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class DurableHintBufferTest {
    @Test fun deliveryHintCacheIsBoundedWhileKeepingMostRecentCommittedHints() {
        val buffer = OwnedEventBuffer<Int>(capacity = 256)
        repeat(10000) { buffer.enqueue(it) }
        assertEquals(256, buffer.pendingCount)
        val sent = mutableListOf<Int>()
        buffer.attach(EngineAttachmentOwner("native-projection"), sent::add)
        repeat(4) { buffer.drain(64) }
        assertEquals((9744..9999).toList(), sent)
    }
    @Test fun malformedIngressIsAnOrderedGapRatherThanSilentContinuity() {
        val queue = BoundedIngressQueue<String>(2)
        queue.offer("before", 1); queue.reject(2)
        assertFalse(queue.offer("after", 3))
        assertEquals(IngressEntry.Observation("before"), queue.poll())
        assertEquals(IngressEntry.Gap(2, 2, 3), queue.poll())
        assertTrue(queue.offer("recovered", 4))
    }
}
