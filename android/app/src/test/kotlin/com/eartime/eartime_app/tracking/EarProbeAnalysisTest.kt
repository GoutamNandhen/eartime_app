package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class EarProbeAnalysisTest {
    private fun change(at: Long, field: String, old: String?, value: String, device: String = "dev-a") =
        EarProbe.Event(at, "ble", device, field, old, value, -50)

    @Test fun fieldChangingOnlyAfterMarksRanksFirst() {
        val marks = listOf(EarProbe.Mark(10_000, "Left out"), EarProbe.Mark(30_000, "Left in"))
        val events = listOf(
            change(0, "mfr:079a", null, "00"), change(12_000, "mfr:079a", "00", "01"), change(33_000, "mfr:079a", "01", "00"),
            change(0, "svc:0000fe2c", null, "a0"), change(5_000, "svc:0000fe2c", "a0", "a1"), change(13_000, "svc:0000fe2c", "a1", "a2"),
            change(20_000, "svc:0000fe2c", "a2", "a3"), change(40_000, "svc:0000fe2c", "a3", "a4"))
        val result = EarProbe.analyse(events, marks)
        assertEquals("mfr:079a", result.first()["field"]); assertEquals(1.0, result.first()["score"] as Double, 1e-9)
        assertEquals(2, result.first()["marksExplained"])
        assertTrue((result[1]["score"] as Double) < 0.5)
    }

    @Test fun noMarksOrNoNearbyChangesYieldNoCandidates() {
        assertTrue(EarProbe.analyse(listOf(change(0, "f", null, "1"), change(1000, "f", "1", "2")), emptyList()).isEmpty())
        assertTrue(EarProbe.analyse(listOf(change(0, "f", null, "1"), change(50_000, "f", "1", "2")),
            listOf(EarProbe.Mark(1000, "x"))).isEmpty())
    }

    @Test fun diffNamesChangedBytes() {
        assertEquals("b1,b3", EarProbe.diff("00110022", "00ff00ee"))
        assertEquals("", EarProbe.diff(null, "00")); assertEquals("", EarProbe.diff("00", "0000"))
    }
}
