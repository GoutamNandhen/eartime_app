package com.eartime.eartime_app.tracking

import android.app.Application
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import org.json.JSONObject

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class ListeningProjectionTest {
    private lateinit var context: Context
    private lateinit var journal: ObservationJournal
    private val name = "p-${UUID.randomUUID().toString().take(8)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private val deviceA = "00000000-0000-4000-8000-000000000001"
    private val deviceB = "00000000-0000-4000-8000-000000000002"
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @Before fun setup() { context = RuntimeEnvironment.getApplication(); journal = ObservationJournal(context, name) }
    @After fun cleanup() { run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name) }
    private fun raw(kind: String, wall: Long, elapsed: Long = wall, epoch: String = "epoch", boot: String? = "boot",
        payload: Map<String, Any?> = emptyMap(), confidence: AttributionConfidence = AttributionConfidence.UNKNOWN) =
        ObservationInput(UUID.randomUUID().toString(), kind, "fixture", "process", ObservationTime(wall, elapsed, boot, epoch),
            JournalJson.encode(payload), "fixture_observation", confidence)
    private fun route(wall: Long, playing: Boolean = true, route: String = "r1", device: String = deviceA,
        elapsed: Long = wall, epoch: String = "epoch", external: Boolean = true) = raw("ROUTE_PLAYBACK", wall, elapsed, epoch,
            payload = mapOf("routeId" to route, "physicalDeviceId" to device, "playing" to playing, "external" to external),
            confidence = AttributionConfidence.CONFIRMED)
    private fun snapshot(from: Long = 0, until: Long = 100000, now: ObservationTime? = null) =
        journal.listeningSnapshot(from, until, "UTC", now)
    private fun total() = snapshot()["confirmedMs"]
    @Suppress("UNCHECKED_CAST") private fun intervals() = snapshot()["intervals"] as List<Map<String, Any?>>

    @Suppress("UNCHECKED_CAST")
    @Test fun measuredFrequencyUsesOriginalOpeningNotLaterSyncOrClippedWindowBoundary() = run {
        val first = route(1000)
        journal.append(first); journal.append(first); journal.append(route(5000))
        journal.append(raw("SYNC_STATE", 7000, payload = mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(route(9000, false))
        val full = snapshot()
        assertEquals(1, full["frequencyContractVersion"]); assertEquals(1, full["measuredSessionStarts"])
        assertEquals(1, (full["days"] as List<Map<String, Any?>>).sumOf { it["measuredSessionStarts"] as Int })
        assertEquals(1, (full["hourly"] as List<Map<String, Any?>>).sumOf { it["measuredSessionStarts"] as Int })
        val clipped = snapshot(6000, 10000)
        assertEquals(3000L, clipped["confirmedMs"]); assertEquals(1, clipped["measuredSessionCount"])
        assertEquals(0, clipped["measuredSessionStarts"])
        journal.rebuildListeningProjection(); assertEquals(full, snapshot())
        journal.close(); journal = ObservationJournal(context, name); assertEquals(full, snapshot())
    }

    @Test fun frequencyNeverCountsUnverifiedZeroDurationOrSpeakerActivityAsMeasuredListening() = run {
        journal.append(raw("PLAYBACK_STARTED", 1000)); journal.append(raw("SYNC_STATE", 4000,
            payload = mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(raw("PLAYBACK_PAUSED", 5000))
        journal.append(route(6000)); journal.append(route(6000, false))
        journal.append(route(7000, external = false)); journal.append(route(9000, false, external = false))
        assertEquals(0, snapshot()["measuredSessionStarts"])
        journal.append(route(10000)); journal.append(route(11000, false))
        assertEquals(1, snapshot()["measuredSessionStarts"])
    }

    @Test fun frequencyCountsCanonicalOverlapGroupsNotPerDeviceSumAndRetainsGapClockStarts() = run {
        journal.append(route(1000, route = "a")); journal.append(route(2000, route = "b", device = deviceB))
        journal.append(route(5000, false, "a")); journal.append(route(6000, false, "b", deviceB))
        journal.append(route(8000)); journal.append(route(9000, false))
        assertEquals(2, snapshot()["measuredSessionStarts"])
        assertEquals(2, journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceA)["measuredSessionStarts"])
        assertEquals(1, journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceB)["measuredSessionStarts"])
        journal.append(raw("COLLECTION_GAP", 9000))
        journal.append(route(1000, elapsed = 10000)); journal.append(route(5000, false, elapsed = 14000))
        assertEquals(3, snapshot()["measuredSessionStarts"])
        assertEquals(6000L, snapshot()["confirmedMs"])
    }

    @Suppress("UNCHECKED_CAST")
    @Test fun frequencyAssignsMidnightAndRepeatedDstHourByCapturedOriginalStart() = run {
        val midnight = 1730606400000L // 2024-11-03 00:00 America/New_York, a 25-hour day.
        journal.append(route(midnight - 1000)); journal.append(route(midnight + 1000, false))
        val firstOneThirty = midnight + 90 * 60000L
        val secondOneThirty = firstOneThirty + 3600000L
        journal.append(route(firstOneThirty)); journal.append(route(firstOneThirty + 1000, false))
        journal.append(route(secondOneThirty)); journal.append(route(secondOneThirty + 1000, false))
        val full = journal.listeningSnapshot(midnight - 1000, midnight + 25 * 3600000, "America/New_York")
        val hours = full["hourly"] as List<Map<String, Any?>>
        assertEquals(2, hours.single { it["hour"] == 1 }["measuredSessionStarts"])
        assertEquals(3, full["measuredSessionStarts"])
        val today = journal.listeningSnapshot(midnight, midnight + 25 * 3600000, "America/New_York")
        assertEquals(2, today["measuredSessionStarts"]); assertEquals(3000L, today["confirmedMs"])
        assertEquals(2, (today["days"] as List<Map<String, Any?>>).single()["measuredSessionStarts"])
    }

    @Test fun frequencyTotalsDoNotDependOnTheVisibleSessionPage() = run {
        repeat(21) { index ->
            journal.append(route(1000L + index * 2000)); journal.append(route(2000L + index * 2000, false))
        }
        val full = snapshot()
        val last = journal.listeningSnapshot(0, 100000, "UTC", offset = 20, limit = 10)
        assertEquals(21, full["measuredSessionStarts"]); assertEquals(21, last["measuredSessionStarts"])
        assertEquals(1, (last["sessions"] as List<*>).size)
    }

    @Suppress("UNCHECKED_CAST")
    @Test fun canonicalSessionsUnionOverlappingRoutesButPauseResumeStartsAnotherSession() = run {
        journal.append(route(1000, route = "a")); journal.append(route(2000, route = "b", device = deviceB))
        journal.append(route(5000, false, "a")); journal.append(route(6000, false, "b", deviceB))
        journal.append(route(8000)); journal.append(route(9000, false))
        val value = snapshot()
        assertEquals(1, value["sessionContractVersion"])
        val groups = value["sessions"] as List<Map<String, Any?>>
        assertEquals(2, groups.size)
        assertEquals(listOf(1000L, 5000L), groups.map { it["durationMs"] })
        assertEquals(2, groups.last()["segmentCount"])
        assertEquals(2, groups.last()["deviceCount"])
        assertEquals(6000L, groups.sumOf { it["durationMs"] as Long })
        assertEquals(6000L, value["confirmedMs"])
        assertEquals(5000L, value["longestSessionMs"]); assertEquals(3000L, value["averageSessionMs"])
        assertEquals(2, value["measuredSessionCount"])
        val before = journal.readAfter(0)
        journal.rebuildListeningProjection(); assertEquals(value, snapshot())
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals(value, snapshot()); assertEquals(before, journal.readAfter(0))
    }

    @Suppress("UNCHECKED_CAST")
    @Test fun sessionsDoNotMergeTouchingObservationsAcrossExplicitGapOrClockRollback() = run {
        journal.append(route(1000)); journal.append(route(5000, false))
        journal.append(raw("COLLECTION_GAP", 5000))
        journal.append(route(5000)); journal.append(route(7000, false))
        journal.append(route(1000, elapsed = 8000)); journal.append(route(5000, false, elapsed = 12000))
        val groups = snapshot()["sessions"] as List<Map<String, Any?>>
        assertEquals(3, groups.size)
        assertEquals(10000L, groups.sumOf { it["durationMs"] as Long })
        assertEquals(6000L, total()) // Calendar union remains authoritative, even when clocks overlap.
    }

    @Suppress("UNCHECKED_CAST")
    @Test fun unverifiedAndOpenUnknownSessionsCannotBecomeConfirmedOrAbsorbMeasuredSessions() = run {
        journal.append(raw("PLAYBACK_STARTED", 1000)); journal.append(raw("PLAYBACK_PAUSED", 5000))
        journal.append(route(1000)); journal.append(route(5000, false)); journal.append(route(8000))
        val groups = snapshot()["sessions"] as List<Map<String, Any?>>
        assertEquals(3, groups.size)
        assertEquals(1, groups.count { it["attribution"] == "UNVERIFIED" })
        assertEquals(1, groups.count { it["durationMs"] == 0L && it["incomplete"] == true })
        assertEquals(4000L, total())
        assertEquals(4000L, snapshot()["averageSessionMs"])
        assertEquals(1, snapshot()["measuredSessionCount"])
    }

    @Suppress("UNCHECKED_CAST")
    @Test fun sessionAndContributorPagingRemainBoundedScopedAndReplayable() = run {
        repeat(105) { index -> journal.append(route(1000L + index, route = "r$index")) }
        repeat(105) { index -> journal.append(route(10000L + index, false, "r$index")) }
        repeat(104) { index ->
            journal.append(route(20000L + index * 100, route = "later"))
            journal.append(route(20050L + index * 100, false, "later"))
        }
        val page = journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceA)
        val last = journal.listeningSnapshot(0, 100000, "UTC", offset = 100, deviceId = deviceA)
        assertEquals(105, page["sessionCount"]); assertEquals(100, (page["sessions"] as List<*>).size)
        assertEquals(5, (last["sessions"] as List<*>).size)
        val group = (last["sessions"] as List<Map<String, Any?>>).last()
        assertEquals(105, group["segmentCount"])
        val id = group["id"] as String
        fun detail(offset: Int) = journal.listeningSnapshot(0, 100000, "UTC", offset = offset,
            deviceId = deviceA, sessionId = id)["sessionDetail"] as Map<String, Any?>
        assertEquals(100, (detail(0)["intervals"] as List<*>).size)
        assertEquals(5, (detail(100)["intervals"] as List<*>).size)
        assertEquals(false, detail(100)["hasMore"])
        assertEquals(9104L, detail(100)["durationMs"])
        assertThrows(IllegalStateException::class.java) {
            journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceB, sessionId = id)
        }
        val before = detail(100); journal.rebuildListeningProjection()
        assertEquals(before, detail(100)); assertEquals(page["confirmedMs"], last["confirmedMs"])
    }

    @Suppress("UNCHECKED_CAST")
    @Test fun sessionDetailsRetainDisconnectSpeakerAndUncertaintyRatherThanInventingBreaks() = run {
        journal.append(route(1000)); journal.append(raw("ROUTE_DISCONNECTED", 3000,
            payload = mapOf("routeId" to "r1", "physicalDeviceId" to deviceA), confidence = AttributionConfidence.CONFIRMED))
        journal.append(route(4000)); journal.append(route(6000, external = false))
        journal.append(route(7000)); journal.append(route(8000)); journal.append(raw("COLLECTION_GAP", 20000))
        val value = snapshot()
        val transitions = (value["intervals"] as List<Map<String, Any?>>).map { it["transition"] }
        assertEquals(listOf("CONTINUITY_LOST", "OUTPUT_CHANGED", "DISCONNECTED"), transitions)
        assertEquals(5000L, value["confirmedMs"])
        val group = (value["sessions"] as List<Map<String, Any?>>).first()
        assertEquals(true, group["incomplete"]); assertEquals(8000L, group["endUtcMs"])
        val clipped = journal.listeningSnapshot(2000, 2500, "UTC")
        val selected = (clipped["sessions"] as List<Map<String, Any?>>).single()
        assertEquals(true, selected["clipped"]); assertEquals(500L, selected["durationMs"])
        assertEquals(500L, clipped["confirmedMs"])
    }

    @Test fun deviceDrilldownReusesCanonicalUnionAndExcludesOtherDevicesAndLegacyActivity() = run {
        journal.append(raw("PLAYBACK_STARTED", 500))
        journal.append(route(1000, route = "a", device = deviceA))
        journal.append(route(2000, route = "a2", device = deviceA))
        journal.append(route(3000, route = "b", device = deviceB))
        journal.append(route(5000, false, "a", deviceA))
        journal.append(route(6000, false, "a2", deviceA))
        journal.append(route(8000, false, "b", deviceB))
        journal.append(raw("PLAYBACK_PAUSED", 9000))
        ListeningPreferences(context).update(mapOf("dailyGoalMinutes" to 30))
        val global = snapshot()
        val scoped = journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceA)
        assertEquals(7000L, global["confirmedMs"]); assertEquals(8500L, global["unverifiedMs"])
        assertEquals(5000L, scoped["confirmedMs"]); assertEquals(0L, scoped["unverifiedMs"])
        assertEquals(deviceA, scoped["filterDeviceId"])
        assertEquals(1L, scoped["deviceCount"])
        assertEquals(deviceA, ((scoped["devices"] as List<*>).single() as Map<*, *>)["id"])
        assertEquals(2, scoped["intervalCount"])
        assertEquals(5000L, ((scoped["perDevice"] as List<*>).single() as Map<*, *>)["durationMs"])
        assertEquals(5000L, (scoped["days"] as List<*>).sumOf { ((it as Map<*, *>)["confirmedMs"] as Long) })
        assertEquals(0, (scoped["report"] as Map<*, *>)["goalMinutes"])
        val clipped = journal.listeningSnapshot(3000, 4500, "UTC", deviceId = deviceA)
        assertEquals(1500L, clipped["confirmedMs"])
    }

    @Test fun deviceHistoryPagesDoNotFilterOnlyTheFirstGlobalPageAndSurviveReplay() = run {
        repeat(105) { index ->
            val at = 1000L + index * 100
            journal.append(route(at, device = deviceA)); journal.append(route(at + 10, false, device = deviceA))
            journal.append(route(at + 20, route = "b", device = deviceB)); journal.append(route(at + 30, false, "b", deviceB))
        }
        val first = journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceA)
        val last = journal.listeningSnapshot(0, 100000, "UTC", offset = 100, deviceId = deviceA)
        assertEquals(105, first["intervalCount"]); assertEquals(100, (first["intervals"] as List<*>).size)
        assertEquals(5, (last["intervals"] as List<*>).size)
        assertEquals(1050L, first["confirmedMs"]); assertEquals(first["confirmedMs"], last["confirmedMs"])
        assertTrue(((first["intervals"] as List<*>) + (last["intervals"] as List<*>)).all { (it as Map<*, *>)["deviceId"] == deviceA })
        journal.rebuildListeningProjection(); assertEquals(first, journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceA))
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals(last, journal.listeningSnapshot(0, 100000, "UTC", offset = 100, deviceId = deviceA))
    }

    @Test fun malformedOrUnknownDeviceFilterNeverFallsBackToGlobalTotals() = run {
        journal.append(route(1000)); journal.append(route(5000, false))
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 100000, "UTC", deviceId = "same model") }
        val empty = journal.listeningSnapshot(0, 100000, "UTC", deviceId = UUID.randomUUID().toString())
        assertEquals(0L, empty["confirmedMs"]); assertEquals(0, empty["intervalCount"]); assertEquals(0L, empty["deviceCount"])
    }

    @Test fun versionFourCacheAddsDeviceHistoryIndexWithoutChangingSourceOrCursors() = run {
        journal.append(route(1000)); journal.append(route(5000, false)); journal.acknowledge("device-history", 2)
        val raw = journal.readAfter(0); val source = journal.stats()["sourceId"]
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("UPDATE listening_projection SET version=4")
            it.execSQL("DROP INDEX listening_interval_device_window")
        }
        journal = ObservationJournal(context, name)
        assertEquals(4000L, journal.listeningSnapshot(0, 100000, "UTC", deviceId = deviceA)["confirmedMs"])
        assertEquals(raw, journal.readAfter(0)); assertEquals(source, journal.stats()["sourceId"])
        assertEquals(2L, journal.cursor("device-history"))
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND name='listening_interval_device_window'", null).use { assertTrue(it.moveToFirst()) }
        }
    }

    @Test fun b02SyncRetainsDurableOpeningRatherThanFlutterTimestamp() = run {
        journal.append(raw("PLAYBACK_STARTED", 1000))
        journal.append(raw("SYNC_STATE", 5000, payload = mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(raw("PLAYBACK_PAUSED", 9000))
        assertEquals(1000L, intervals().single()["startUtcMs"])
        assertEquals(8000L, snapshot()["unverifiedMs"])
        assertEquals(0L, total()) // A global flag is not evidence of external listening.
    }

    @Test fun calendarAndCustomQueriesReconcileClippedUnionAcrossLeapDayReopenAndReplay() = run {
        fun day(month: Int, date: Int) = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply {
            clear(); set(2024, month - 1, date)
        }.timeInMillis
        val midnight = day(3, 1); val noon = midnight + 12 * 3600000L
        journal.append(route(midnight - 1000)); journal.append(route(midnight + 1000, false))
        journal.append(route(noon)); journal.append(route(noon + 3000, route = "other", device = deviceB))
        journal.append(route(noon + 5000, false)); journal.append(route(noon + 6000, false, "other", deviceB))
        val raw = journal.readAfter(0); journal.acknowledge("calendar-acceptance", 6)
        val windows = listOf(Triple(day(2, 29), midnight, 1000L), Triple(midnight, day(3, 2), 7000L),
            Triple(day(2, 26), day(3, 2), 8000L), Triple(day(1, 1), day(3, 2), 8000L),
            Triple(day(2, 29), day(3, 2), 8000L))
        fun verify() {
            for ((from, until, expected) in windows) {
                val value = journal.listeningSnapshot(from, until, "UTC")
                assertEquals(expected, value["confirmedMs"])
                assertEquals(expected, (value["days"] as List<*>).sumOf { (it as Map<*, *>)["confirmedMs"] as Long })
                assertEquals(expected, (value["hourly"] as List<*>).sumOf { (it as Map<*, *>)["durationMs"] as Long })
                assertEquals(value["confirmedMs"], journal.listeningSnapshot(from, until, "UTC", offset = 100)["confirmedMs"])
            }
        }
        verify(); journal.close(); journal = ObservationJournal(context, name); verify()
        journal.rebuildListeningProjection(); verify(); assertEquals(raw, journal.readAfter(0)); assertEquals(6L, journal.cursor("calendar-acceptance"))
    }

    @Test fun invalidCalendarQueryCannotMutateJournalOrFallBackToAllHistory() = run {
        journal.append(route(1000)); journal.append(route(5000, false)); val before = journal.readAfter(0)
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(10000, 5000, "UTC") }
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 400L * 86400000, "UTC") }
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 10000, "not-a-timezone") }
        assertEquals(before, journal.readAfter(0)); assertEquals(4000L, total())
    }

    @Test fun emptyUnverifiedAndGapStatesRemainDistinctWithoutNegativeOrConfirmedSubstitution() = run {
        fun verify(expectedUnverified: Long, expectedCount: Int, expectedGap: Long) {
            val value = snapshot()
            assertEquals(0L, value["confirmedMs"]); assertEquals(expectedUnverified, value["unverifiedMs"])
            assertEquals(expectedCount, value["intervalCount"]); assertEquals(expectedGap, value["gapCount"])
            for (field in listOf("longestMs", "averageMs")) assertEquals(0L, value[field])
            assertEquals(0, value["listeningRuns"])
            assertTrue((value["hourly"] as List<*>).all { ((it as Map<*, *>)["durationMs"] as Long) == 0L })
        }
        verify(0, 0, 0)
        journal.append(raw("PLAYBACK_STARTED", 1000)); verify(0, 1, 0)
        journal.append(raw("SYNC_STATE", 5000, payload = mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(raw("PLAYBACK_PAUSED", 9000)); verify(8000, 1, 0)
        journal.append(raw("COLLECTION_GAP", 10000)); verify(8000, 1, 1)
        journal.close(); journal = ObservationJournal(context, name); journal.rebuildListeningProjection(); verify(8000, 1, 1)
    }

    @Test fun unmeasuredOpenObservationsCannotDiluteTheAverageOfMeasuredRuns() = run {
        journal.append(route(1000)); journal.append(route(5000, false))
        journal.append(route(9000))
        val value = snapshot()
        assertEquals(4000L, value["confirmedMs"]); assertEquals(1, value["listeningRuns"])
        assertEquals(4000L, value["longestMs"]); assertEquals(4000L, value["averageMs"])
        assertEquals(2, value["intervalCount"]); assertEquals(1, value["openIntervalCount"])
        journal.close(); journal = ObservationJournal(context, name); journal.rebuildListeningProjection()
        assertEquals(4000L, snapshot()["averageMs"])
        assertEquals(1, snapshot()["openIntervalCount"])
    }

    @Test fun generatedReportUsesPersistedGoalAndCanonicalTotalsAfterReopenAndReplay() = run {
        ListeningPreferences(context).update(mapOf("dailyGoalMinutes" to 1))
        try {
            journal.append(route(1000)); journal.append(route(61000, false))
            val first = journal.listeningSnapshot(0, 86400000, "UTC")["report"] as Map<*, *>
            assertEquals(1, first["goalDays"])
            assertEquals(60000L, first["averageActiveDayMs"])
            journal.close(); journal = ObservationJournal(context, name)
            journal.rebuildListeningProjection()
            assertEquals(first, journal.listeningSnapshot(0, 86400000, "UTC")["report"])
        } finally { ListeningPreferences(context).update(mapOf("dailyGoalMinutes" to 0)) }
    }

    @Test fun crossLayerFixtureUsesTheActualNativeReducerAndFlutterWireContract() = run {
        val fixture = JSONObject(javaClass.classLoader!!.getResourceAsStream("listening_continuity.json")!!.bufferedReader().use { it.readText() })
        val events = fixture.getJSONArray("events")
        for (i in 0 until events.length()) {
            val event = events.getJSONObject(i)
            @Suppress("UNCHECKED_CAST") val payload = JournalJson.toValue(event.getJSONObject("payload")) as Map<String, Any?>
            journal.append(raw(event.getString("kind"), event.getLong("wall"), payload = payload))
        }
        val expected = fixture.getJSONObject("projection")
        val actual = snapshot()
        for (key in listOf("confirmedMs", "unverifiedMs", "sequence", "gapCount"))
            assertEquals(key, expected.getLong(key), actual[key])
        assertEquals(expected.getJSONArray("intervals").getJSONObject(0).getLong("startUtcMs"), intervals().single()["startUtcMs"])
    }

    @Test fun confirmedContinuitySurvivesFlutterSnapshotAndJournalReopen() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.close(); journal = ObservationJournal(context, name)
        journal.append(raw("SYNC_STATE", 5000, payload = mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(route(9000, false))
        assertEquals(8000L, total())
        assertEquals(1000L, intervals().single { it["attribution"] == "CONFIRMED" }["startUtcMs"])
    }

    @Test fun restartGapClosesAtLastEvidenceAndNeverBridgesToNewProcess() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(raw("COLLECTION_GAP", 8000, epoch = "new"))
        journal.append(route(10000, epoch = "new")); journal.append(route(12000, false, epoch = "new"))
        assertEquals(4000L, total())
        assertEquals("collection_gap", intervals().last()["closeReason"])
    }

    @Test fun preCommitCrashRollsBackProjectionAndSourceTogether() = run {
        val event = route(1000)
        assertThrows(IllegalStateException::class.java) { journal.append(event) { error("process death before commit") } }
        assertEquals(0L, snapshot()["sequence"])
        assertTrue(intervals().isEmpty())
        journal.append(event); journal.append(route(4000, false))
        assertEquals(3000L, total())
    }

    @Test fun duplicateDeliveryAndRebuildHaveExactlyEquivalentProjection() = run {
        val start = route(1000)
        journal.append(start); journal.append(start); journal.append(route(4000, false))
        val before = snapshot()
        journal.rebuildListeningProjection()
        assertEquals(before, snapshot())
        assertEquals(3000L, total())
    }

    @Test fun overlappingOutputsAreUnionedAndDisconnectIsRouteScoped() = run {
        journal.append(route(1000)); journal.append(route(2000, route = "r2", device = deviceB))
        journal.append(raw("ROUTE_DISCONNECTED", 4000, payload = mapOf("routeId" to "r1", "physicalDeviceId" to deviceA),
            confidence = AttributionConfidence.CONFIRMED))
        journal.append(route(7000, false, "r2", deviceB))
        assertEquals(6000L, total())
        assertEquals(8000L, intervals().sumOf { it["durationMs"] as Long })
    }

    @Test fun twoRoutesOfOnePhysicalDeviceRemainConnectedWhenOneDisconnects() = run {
        journal.append(route(1000)); journal.append(route(2000, route = "r2"))
        journal.append(raw("ROUTE_DISCONNECTED", 3000, payload = mapOf("routeId" to "r1", "physicalDeviceId" to deviceA),
            confidence = AttributionConfidence.CONFIRMED))
        val devices = snapshot()["devices"] as List<*>
        assertEquals(true, (devices.single() as Map<*, *>)["connected"])
    }

    @Test fun pauseResumeDoesNotCountPausedTime() = run {
        journal.append(route(1000)); journal.append(route(3000, false))
        journal.append(route(6000)); journal.append(route(9000, false))
        assertEquals(5000L, total()); assertEquals(2, intervals().size)
    }

    @Test fun lossOfRouteAttributionClosesAtLastVerifiedEvidence() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(route(9000).copy(confidence = AttributionConfidence.UNKNOWN))
        assertEquals(2000L, total()); assertEquals("attribution_lost", intervals().single()["closeReason"])
    }

    @Test fun speakerAndUnidentifiedOrUnconfirmedOutputsNeverBecomeListening() = run {
        journal.append(route(1000, external = false)); journal.append(route(2000, device = "mutable name"))
        journal.append(route(3000).copy(confidence = AttributionConfidence.UNKNOWN))
        journal.append(raw("PLAYBACK_STARTED", 4000)); journal.append(raw("PLAYBACK_PAUSED", 8000))
        assertEquals(0L, total()); assertEquals(4000L, snapshot()["unverifiedMs"])
    }

    @Test fun wallRollbackAndForwardJumpCannotFabricateDuration() = run {
        journal.append(route(10000, elapsed = 1000)); journal.append(route(12000, elapsed = 3000))
        journal.append(route(2000, elapsed = 4000)); journal.append(route(5000, false, elapsed = 7000))
        journal.append(route(100000, elapsed = 8000)); journal.append(route(200000, false, elapsed = 9000))
        assertEquals(5000L, journal.listeningSnapshot(0, 300000, "UTC")["confirmedMs"])
    }

    @Test fun bootOrElapsedRegressionAndUnknownBootCannotExtendOldInterval() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(route(5000, elapsed = 100))
        journal.append(route(7000, false, elapsed = 2100))
        assertEquals(4000L, total())
        journal.append(raw("PLAYBACK_STARTED", 10000, boot = null))
        journal.append(raw("PLAYBACK_PAUSED", 20000, boot = null))
        assertEquals(0L, snapshot()["unverifiedMs"])
    }

    @Test fun liveExtensionRequiresCurrentEpochBootAndStableClock() = run {
        journal.append(route(1000))
        assertEquals(4000L, snapshot(now = ObservationTime(5000, 5000, "boot", "epoch"))["confirmedMs"])
        assertEquals(0L, snapshot(now = ObservationTime(5000, 5000, "boot", "new"))["confirmedMs"])
        assertEquals(0L, snapshot(now = ObservationTime(50000, 5000, "boot", "epoch"))["confirmedMs"])
    }

    @Test fun physicalIdentityChangeSplitsRatherThanRenamesOldListening() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(route(4000, device = deviceB)); journal.append(route(7000, false, device = deviceB))
        assertEquals(5000L, total())
        assertEquals(setOf(deviceA, deviceB), intervals().map { it["deviceId"] }.toSet())
    }

    @Test fun calendarMidnightAndDstDaysUseLocalCalendarNotFixed24Hours() = run {
        val midnight = 1710046800000L // 2024-03-10 00:00 America/New_York
        journal.append(route(midnight - 1000)); journal.append(route(midnight + 2000, false))
        val result = journal.listeningSnapshot(midnight - 1000, midnight + 86400000, "America/New_York")
        val days = result["days"] as List<*>
        assertEquals(3000L, result["confirmedMs"])
        val springDay = days.map { it as Map<*, *> }.single { it["startUtcMs"] == midnight }
        assertEquals(23L * 3600000, springDay["endUtcMs"] as Long - midnight)
        assertEquals(2000L, springDay["confirmedMs"])
    }

    @Test fun autumnRepeatedHourAndAllAggregateBucketsReconcile() = run {
        val start = java.time.Instant.parse("2024-11-03T04:30:00Z").toEpochMilli()
        journal.append(route(start)); journal.append(route(start + 4 * 3600000, false))
        val result = journal.listeningSnapshot(start, start + 4 * 3600000, "America/New_York")
        val hours = (result["hourly"] as List<*>).map { it as Map<*, *> }
        assertEquals(4L * 3600000, hours.sumOf { it["durationMs"] as Long })
        assertEquals(2L * 3600000, hours.single { it["hour"] == 1 }["durationMs"])
        assertEquals(4L * 3600000, result["longestMs"])
        assertEquals(4L * 3600000, result["averageMs"])
        assertEquals(1, result["listeningRuns"])
    }

    @Test fun leapYearLocalWindowMayIncludeAnAdditionalDstHourWithoutOverflow() = run {
        val start = java.time.Instant.parse("2023-11-05T04:00:00Z").toEpochMilli()
        val end = java.time.Instant.parse("2024-11-05T05:00:00Z").toEpochMilli()
        journal.append(route(start)); journal.append(route(end, false))
        val result = journal.listeningSnapshot(start, end, "America/New_York")
        assertEquals(366, (result["days"] as List<*>).size)
        assertEquals(end - start, result["confirmedMs"])
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(Long.MIN_VALUE, Long.MAX_VALUE, "UTC") }
        Unit
    }

    @Test fun displayNameEditsDoNotChangePhysicalIdentityOrJournalFacts() = run {
        journal.append(route(1000)); journal.append(route(5000, false))
        val before = journal.readAfter(0)
        ListeningPreferences(context).update(mapOf("deviceNames" to mapOf(deviceA to "My headset")))
        val device = (snapshot()["devices"] as List<*>).single() as Map<*, *>
        assertEquals("My headset", device["name"]); assertEquals(deviceA, device["id"])
        assertEquals(before, journal.readAfter(0)); assertEquals(4000L, total())
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals("My headset", ((snapshot()["devices"] as List<*>).single() as Map<*, *>)["name"])
    }

    @Test fun additiveV1MigrationPreservesObservationsAndReplaysInBoundedBatches() = run {
        repeat(140) { journal.append(raw("PLAYBACK_STARTED", it.toLong())) }
        val source = journal.stats()["sourceId"]
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DROP TABLE listening_projection"); it.execSQL("DROP TABLE listening_intervals")
            it.execSQL("DROP TABLE listening_devices"); it.version = 1
        }
        journal = ObservationJournal(context, name)
        assertEquals(source, snapshot()["sourceId"]); assertEquals(140L, snapshot()["sequence"])
        assertEquals(140L, journal.stats()["observationCount"])
        assertEquals(3, journal.stats()["schemaVersion"])
    }

    @Test fun v2MigrationRebuildsOnlyDisposableStateAndPreservesSourceAndCursors() = run {
        journal.append(route(1000)); journal.append(route(5000, false))
        val source = journal.stats()["sourceId"]
        journal.acknowledge("reader", 2)
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DROP TABLE listening_devices"); it.version = 2
        }
        journal = ObservationJournal(context, name)
        assertEquals(source, snapshot()["sourceId"]); assertEquals(4000L, total())
        assertEquals(2L, journal.cursor("reader")); assertEquals(2L, journal.stats()["observationCount"])
    }

    @Test fun sameMillisecondSourceOrderAndPaginationAreDeterministic() = run {
        journal.append(route(1000)); journal.append(route(1000, false)); journal.append(route(1000))
        assertEquals(2, intervals().size)
        val page = journal.listeningSnapshot(0, 100000, "UTC", offset = 1, limit = 1)
        assertEquals(false, page["hasMore"]); assertEquals(2, page["nextOffset"])
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 100, "invalid") }
        Unit
    }

    @Test fun knownDevicePagesAreBoundedDisjointAndPreserveListeningTotals() = run {
        repeat(205) { index ->
            journal.append(raw("DEVICE_CONNECTED", 1000L + index * 2, payload = mapOf("device" to
                mapOf("id" to "endpoint-$index", "friendlyName" to "Fixture $index", "nativeType" to 8))))
            if (index < 204) journal.append(raw("DEVICE_DISCONNECTED", 1001L + index * 2,
                payload = mapOf("deviceId" to "endpoint-$index")))
        }
        fun page(offset: Int) = journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = offset)
        val first = page(0); val second = page(100); val third = page(200)
        val firstDevices = first["devices"] as List<*>
        val secondDevices = second["devices"] as List<*>
        val thirdDevices = third["devices"] as List<*>
        assertEquals(100, firstDevices.size); assertEquals(100, secondDevices.size); assertEquals(5, thirdDevices.size)
        assertEquals(205, (firstDevices + secondDevices + thirdDevices).map { (it as Map<*, *>)["id"] }.toSet().size)
        assertEquals("Fixture 204", (firstDevices.first() as Map<*, *>)["name"])
        assertEquals("Fixture 0", (thirdDevices.last() as Map<*, *>)["name"])
        assertEquals(205L, third["deviceCount"]); assertEquals(205L, third["nextDeviceOffset"])
        assertEquals(true, first["hasMoreDevices"]); assertEquals(false, third["hasMoreDevices"])
        for (result in listOf(first, second, third)) {
            assertEquals(0L, result["confirmedMs"]); assertEquals(0L, result["unverifiedMs"])
            assertEquals(0, result["intervalCount"])
        }
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals(third, page(200))
    }

    @Test fun invalidDeviceOffsetsFailAndEmptyPagesCannotAdvancePastCount() = run {
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = -1) }
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = Int.MAX_VALUE) }
        val page = journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = 100)
        assertEquals(100, page["deviceOffset"]); assertEquals(0L, page["nextDeviceOffset"])
        assertEquals(false, page["hasMoreDevices"]); assertTrue((page["devices"] as List<*>).isEmpty())
        assertEquals(0L, journal.stats()["observationCount"])
    }
}
