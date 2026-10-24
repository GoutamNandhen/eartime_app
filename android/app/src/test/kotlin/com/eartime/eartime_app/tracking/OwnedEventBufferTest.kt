package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class OwnedEventBufferTest {
    @Test
    fun oldOwnerCannotDetachReplacement() {
        val buffer = OwnedEventBuffer<Int>()
        val a = mutableListOf<Int>()
        val b = mutableListOf<Int>()
        buffer.attach(EngineAttachmentOwner("A"), a::add)
        buffer.attach(EngineAttachmentOwner("B"), b::add)
        assertFalse(buffer.detach("A"))
        buffer.enqueue(1)
        assertEquals(1, buffer.drain(32))
        assertEquals("B", buffer.owner)
        assertTrue(a.isEmpty())
        assertEquals(listOf(1), b)
    }

    @Test
    fun currentOwnerDetachBuffersUntilNextAttachment() {
        val buffer = OwnedEventBuffer<Int>()
        buffer.attach(EngineAttachmentOwner("B"), sender = { })
        assertTrue(buffer.detach("B"))
        buffer.enqueue(1)
        buffer.enqueue(2)
        assertNull(buffer.owner)
        assertEquals(0, buffer.drain(32))
        assertEquals(2, buffer.pendingCount)
        val received = mutableListOf<Int>()
        buffer.attach(EngineAttachmentOwner("C"), received::add)
        assertEquals(2, buffer.drain(32))
        assertEquals(listOf(1, 2), received)
        assertEquals(0, buffer.pendingCount)
    }

    @Test
    fun flushYieldsAfterItsConfiguredBatchWithoutReordering() {
        val buffer = OwnedEventBuffer<Int>()
        (1..100).forEach(buffer::enqueue)
        val received = mutableListOf<Int>()
        buffer.attach(EngineAttachmentOwner("A"), received::add)
        assertEquals(32, buffer.drain(32))
        assertEquals(68, buffer.pendingCount)
        buffer.enqueue(101)
        assertEquals(32, buffer.drain(32))
        assertEquals(32, buffer.drain(32))
        assertEquals(5, buffer.drain(32))
        assertEquals((1..101).toList(), received)
    }

    @Test
    fun aFailedSendRetainsTheObservation() {
        val buffer = OwnedEventBuffer<Int>()
        buffer.enqueue(1)
        buffer.attach(EngineAttachmentOwner("A"), sender = { throw IllegalStateException("detached transport") })
        try {
            buffer.drain(32)
            fail("send must fail")
        } catch (_: IllegalStateException) { }
        assertEquals(1, buffer.pendingCount)
        buffer.detach("A")
        val received = mutableListOf<Int>()
        buffer.attach(EngineAttachmentOwner("B"), received::add)
        buffer.drain(32)
        assertEquals(listOf(1), received)
    }

    @Test
    fun attachmentSnapshotsPrecedeBufferedEvents() {
        val buffer = OwnedEventBuffer<Int>()
        buffer.enqueue(3)
        val received = mutableListOf<Int>()
        buffer.attach(EngineAttachmentOwner("A"), received::add, listOf(1, 2))
        buffer.drain(32)
        assertEquals(listOf(1, 2, 3), received)
    }
}
