package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class ListeningRemindersTest {
    private val min = 60_000L
    private val prefs = ReminderPreferences(enabled = true, continuousMinutes = 60, repeatMinutes = 30, breakMinutes = 5)

    @Test fun runRequiresLiveNewestSpanAndJoinsShortPauses() {
        val now = 100 * min
        assertNull(ReminderPolicy.currentRun(emptyList(), now, 5 * min))
        assertNull(ReminderPolicy.currentRun(listOf(0L to 50 * min), now, 5 * min))
        val spans = listOf(10 * min to 40 * min, 43 * min to 70 * min, 72 * min to now)
        assertEquals(10 * min to now, ReminderPolicy.currentRun(spans, now, 5 * min))
        val withBreak = listOf(10 * min to 40 * min, 50 * min to now)
        assertEquals(50 * min to now, ReminderPolicy.currentRun(withBreak, now, 5 * min))
        assertEquals(10 * min to now, ReminderPolicy.currentRun(withBreak.reversed(), now, 15 * min))
    }

    @Test fun continuousReminderOnceThenBreakReminderAtRepeatInterval() {
        val start = 0L
        assertNull(ReminderPolicy.decide(prefs, start to 59 * min, 59 * min, null, false))
        val first = ReminderPolicy.decide(prefs, start to 60 * min, 60 * min, null, false)!!
        assertEquals(ReminderKind.CONTINUOUS, first.kind); assertEquals(1, first.state.count)
        assertNull(ReminderPolicy.decide(prefs, start to 80 * min, 80 * min, first.state, false))
        val second = ReminderPolicy.decide(prefs, start to 90 * min, 90 * min, first.state, false)!!
        assertEquals(ReminderKind.BREAK, second.kind); assertEquals(2, second.state.count)
        assertEquals(90 * min, second.listenedMs)
    }

    @Test fun newRunAfterBreakStartsOverAndQuietOrDisabledSuppresses() {
        val old = ReminderState(0, 60 * min, 1)
        assertNull(ReminderPolicy.decide(prefs, 200 * min to 230 * min, 230 * min, old, false))
        assertEquals(ReminderKind.CONTINUOUS, ReminderPolicy.decide(prefs, 200 * min to 260 * min, 260 * min, old, false)!!.kind)
        assertNull(ReminderPolicy.decide(prefs, 0L to 90 * min, 90 * min, null, true))
        assertNull(ReminderPolicy.decide(prefs.copy(enabled = false), 0L to 90 * min, 90 * min, null, false))
        assertNull(ReminderPolicy.decide(prefs, null, 90 * min, null, false))
    }

    @Test fun preferencesValidateAndRoundTrip() {
        assertEquals(prefs, ReminderPreferences.decode(prefs.wire()))
        assertEquals(ReminderPreferences(), ReminderPreferences.decode(null))
        assertThrows(IllegalArgumentException::class.java) { ReminderPreferences.decode(prefs.wire() + ("continuousMinutes" to 2)) }
        assertThrows(IllegalArgumentException::class.java) { ReminderPreferences.decode(prefs.wire() + ("extra" to 1)) }
        assertThrows(IllegalArgumentException::class.java) { ReminderPreferences.decode(prefs.wire() + ("enabled" to "yes")) }
    }
}
