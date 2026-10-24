package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class SummaryJobOwnersTest {
    @Test fun lateStopForOldParametersCannotCancelReplacementWithSameJobId() {
        val owners = SummaryJobOwners(); val oldToken = "old-request"; val nextToken = "new-request"
        val old = owners.start(4101, oldToken); val next = owners.start(4101, nextToken)
        owners.stop(4101, oldToken)
        assertFalse(owners.active(old)); assertTrue(owners.active(next))
        assertFalse(owners.finish(old)); assertTrue(owners.active(next))
    }
    @Test fun matchingStopRetiresOnlyItsJobAndDuplicateStopIsIdempotent() {
        val owners = SummaryJobOwners(); val a = "daily-request"; val b = "weekly-request"
        val first = owners.start(4101, a); val second = owners.start(4102, b)
        owners.stop(4101, a); owners.stop(4101, a)
        assertFalse(owners.active(first)); assertTrue(owners.active(second))
        assertTrue(owners.finish(second)); assertFalse(owners.active(second))
    }
    @Test fun fiveHundredReplacementsRejectAllRetiredStopAndCompletionCallbacks() {
        val owners = SummaryJobOwners(); val old = mutableListOf<SummaryJobOwners.Owner>()
        repeat(500) { old.add(owners.start(4101, "request-$it")) }
        val last = old.removeAt(old.lastIndex)
        old.forEach { owners.stop(4101, it.token); assertFalse(owners.finish(it)) }
        assertTrue(owners.active(last)); assertTrue(owners.finish(last))
    }
    @Test fun unrelatedTokenNeverAcquiresOrRetiresAnExistingJob() {
        val owners = SummaryJobOwners(); val owner = owners.start(4101, "active-request")
        owners.stop(4101, "unrelated-request"); assertTrue(owners.active(owner))
    }
    @Test fun reparceledEqualTokenStopsTheCorrectOwnerWithoutObjectIdentityAssumptions() {
        val owners = SummaryJobOwners(); val token = "serialized-request"
        val owner = owners.start(4101, token)
        owners.stop(4101, String(token.toCharArray()))
        assertFalse(owners.active(owner))
    }
    @Test fun duplicateStartForSameScheduledRequestIsIdempotent() {
        val owners = SummaryJobOwners(); val first = owners.start(4101, "same-request")
        assertSame(first, owners.start(4101, String("same-request".toCharArray())))
        assertTrue(owners.active(first))
    }
}
