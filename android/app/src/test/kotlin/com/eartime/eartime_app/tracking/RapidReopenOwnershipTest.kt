package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class RapidReopenOwnershipTest {
    @Test
    fun delayedListenFromStillActiveACannotReplaceNewerB() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        val b = EngineAttachmentOwner("B")
        buffer.attach(a, {})
        buffer.attach(b, {})
        assertTrue(a.isActive) // old host cleanup has not run yet
        assertFalse(buffer.attach(a, {})) // late old onListen / broker post
        a.retire()
        assertFalse(buffer.detach(a.token))
        assertEquals("B", buffer.owner)
    }

    @Test
    fun olderOwnerCannotReattachEvenWhenNewerOwnerTemporarilyCancels() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        val b = EngineAttachmentOwner("B")
        buffer.attach(a, {})
        buffer.attach(b, {})
        buffer.detach(b.token)
        assertFalse(buffer.attach(a, {}))
        assertTrue(buffer.attach(b, {}))
        assertEquals("B", buffer.owner)
    }

    @Test
    fun cleanupABeforeBAttaches() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        val b = EngineAttachmentOwner("B")
        buffer.attach(a, {})
        a.retire() // MainActivity cleanup retires synchronously, detach may be posted.
        assertNull(buffer.owner)
        assertTrue(buffer.detach(a.token))
        assertTrue(buffer.attach(b, {}))
        assertEquals("B", buffer.owner)
    }

    @Test
    fun cleanupAAndOnCancelAAfterBAttachesCannotDetachB() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        val b = EngineAttachmentOwner("B")
        buffer.attach(a, {})
        buffer.attach(b, {})
        a.retire()
        assertFalse(buffer.detach(a.token)) // engine cleanup
        assertFalse(buffer.detach(a.token)) // delayed onCancel
        assertEquals("B", buffer.owner)
    }

    @Test
    fun alreadyQueuedListenFromRetiredACannotReattachOrRunSync() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        val b = EngineAttachmentOwner("B")
        var syncRequestsFromA = 0
        val queuedChannelListen = {
            a.runIfActive {
                buffer.attach(a, {})
                syncRequestsFromA++
            }
        }
        buffer.attach(a, {})
        a.retire()
        buffer.attach(b, {})
        assertFalse(queuedChannelListen())
        assertEquals(0, syncRequestsFromA)
        assertEquals("B", buffer.owner)
    }

    @Test
    fun brokerPostCapturedBeforeCleanupRechecksTheLeaseAtExecution() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        val b = EngineAttachmentOwner("B")
        val queuedBrokerAttach = { buffer.attach(a, {}, listOf(99)) }
        buffer.enqueue(1)
        a.retire()
        buffer.attach(b, {})
        assertFalse(queuedBrokerAttach())
        assertEquals("B", buffer.owner)
        assertEquals(1, buffer.pendingCount) // no stale cached replay added
    }

    @Test
    fun retiredOwnerCannotDrainBeforeItsPostedDetach() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        val received = mutableListOf<Int>()
        buffer.attach(a, received::add)
        buffer.enqueue(1)
        a.retire()
        assertEquals(0, buffer.drain(32))
        assertEquals(1, buffer.pendingCount)
        assertTrue(received.isEmpty())
    }

    @Test
    fun channelCancellationDoesNotRetireALiveEngine() {
        val buffer = OwnedEventBuffer<Int>()
        val a = EngineAttachmentOwner("A")
        buffer.attach(a, {})
        buffer.detach(a.token)
        assertTrue(a.isActive)
        assertTrue(buffer.attach(a, {}))
    }

    @Test
    fun meaningfulOrderPermutationsKeepLatestEngineAndPendingFifo() {
        // Include old callbacks BEFORE cleanup, not just retired-owner cases.
        val names = listOf("retireA", "cancelA", "attachB", "queuedAttachA")
        fun permutations(items: List<String>): List<List<String>> =
            if (items.isEmpty()) listOf(emptyList())
            else items.flatMap { item ->
                permutations(items - item).map { listOf(item) + it }
            }
        val cases = permutations(names)
        assertEquals(24, cases.size)
        for (order in cases) {
            val buffer = OwnedEventBuffer<Int>()
            val a = EngineAttachmentOwner("A")
            val b = EngineAttachmentOwner("B")
            val received = mutableListOf<Int>()
            buffer.attach(a, {})
            (1..70).forEach(buffer::enqueue)
            for (step in order) {
                when (step) {
                    "retireA" -> a.retire()
                    "cancelA" -> buffer.detach(a.token)
                    "attachB" -> buffer.attach(b, received::add)
                    "queuedAttachA" -> {
                        val bAlreadyAttached = order.indexOf("attachB") < order.indexOf(step)
                        assertEquals(!bAlreadyAttached && a.isActive, buffer.attach(a, {}))
                    }
                }
            }
            assertEquals(order.toString(), "B", buffer.owner)
            repeat(3) { buffer.drain(32) }
            assertEquals(order.toString(), (1..70).toList(), received)
        }
    }

    @Test
    fun oneHundredRapidRetireReplaceCyclesFinishDeterministically() {
        val buffer = OwnedEventBuffer<Int>()
        var previous = EngineAttachmentOwner("0")
        val received = mutableListOf<Int>()
        buffer.attach(previous, received::add)
        repeat(100) { index ->
            val old = previous
            val next = EngineAttachmentOwner("${index + 1}")
            buffer.enqueue(index)
            if (index % 2 == 0) {
                old.retire()
                buffer.detach(old.token)
                buffer.attach(next, received::add)
            } else {
                buffer.attach(next, received::add)
                old.retire()
                assertFalse(buffer.detach(old.token))
            }
            assertFalse(buffer.attach(old, {}))
            buffer.drain(32)
            previous = next
        }
        assertEquals("100", buffer.owner)
        assertEquals(0, buffer.pendingCount)
        assertEquals((0..99).toList(), received)
    }
}
