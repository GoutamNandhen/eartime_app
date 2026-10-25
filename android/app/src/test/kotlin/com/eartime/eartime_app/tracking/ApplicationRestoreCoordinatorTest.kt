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
import java.io.File
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class, shadows = [DirectoryFsyncShadow::class])
class ApplicationRestoreCoordinatorTest {
    private lateinit var context: Context
    private lateinit var journal: ObservationJournal
    private val worker = Executors.newSingleThreadExecutor()
    private val name = "rc-${UUID.randomUUID().toString().take(6)}.db"
    private val files = mutableListOf<File>()
    private fun <T> run(block: () -> T): T = try { worker.submit(Callable { block() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    private fun coordinator() = ApplicationRestoreCoordinator(context, journal)
    private val time = ObservationTime(5000, 5000, "synthetic-boot", "synthetic-epoch")
    private fun preferences() = context.getSharedPreferences("eartime_preferences_v1", 0)
    private fun delivery() = context.getSharedPreferences("eartime_summary_delivery_v1", 0)
    @Before fun setup() {
        DirectoryFsyncShadow.resetFixture()
        context = RuntimeEnvironment.getApplication()
        org.robolectric.shadows.ShadowSQLiteConnection.setDefaultJournalMode("DELETE")
        org.robolectric.shadows.ShadowSQLiteConnection.setDefaultSyncMode("FULL")
        journal = ObservationJournal(context, name)
        run {
            journal.applicationDatabase().let {
                it.disableWriteAheadLogging()
                assertEquals("delete", it.rawQuery("PRAGMA journal_mode=DELETE", null).use { rows -> rows.moveToFirst(); rows.getString(0) })
            }
            SQLiteDatabase.openOrCreateDatabase(ApplicationArchive.legacyFile(context), null).use {
                it.disableWriteAheadLogging()
                assertEquals("delete", it.rawQuery("PRAGMA journal_mode=DELETE", null).use { rows -> rows.moveToFirst(); rows.getString(0) })
                it.version = 1
                it.execSQL("CREATE TABLE ear_time_events(id TEXT PRIMARY KEY NOT NULL,canonical_device_id TEXT NOT NULL,device_name TEXT NOT NULL,connection_type TEXT NOT NULL,event_type TEXT NOT NULL,playback_state TEXT,timestamp INTEGER NOT NULL)")
            }
            journal.append(ObservationInput(UUID.randomUUID().toString(), "PLAYBACK_STARTED", "synthetic_restore",
                "synthetic-process", time, "{}", "fixture_only"))
            setState("dark", "incoming")
        }
    }
    @After fun cleanup() {
        run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name)
        SQLiteDatabase.deleteDatabase(ApplicationArchive.legacyFile(context)); files.forEach { it.delete() }
    }
    private fun setState(theme: String, id: String) {
        check(preferences().edit().clear().putString("themeMode", theme).commit())
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DELETE FROM ear_time_events")
            it.execSQL("INSERT INTO ear_time_events VALUES (?,'synthetic-id','Synthetic device','bluetooth','PLAYBACK_STARTED',NULL,123)", arrayOf(id))
        }
    }
    private fun legacyId(): String = SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READONLY).use {
        it.rawQuery("SELECT id FROM ear_time_events", null).use { rows -> assertEquals(1, rows.count); rows.moveToFirst(); rows.getString(0) }
    }
    private fun export() = File.createTempFile("restore-model-", ".eartimeapp", context.cacheDir).also {
        files.add(it); journal.writeApplicationArchive(it)
    }
    private fun reopen() { journal.close(); journal = ObservationJournal(context, name) }
    private class SyntheticDeath : Error("Synthetic process death; not physical evidence")

    @Test fun ordinaryFailureAfterEachCommittedStoreRestoresAllPriorStateAndNativeRows() = run {
        val archive = export(); setState("light", "old")
        val original = journal.readAfter(0)
        val stages = listOf("prepared", "native_staged", "legacy_committed", "before_eartime_summary_delivery_v1", "preferences_committed", "before_native_commit")
        for (stage in stages) {
            assertThrows(IllegalStateException::class.java) {
                coordinator().restore(archive, time, "synthetic-process", checkpoint = { if (it == stage) error("synthetic interruption") })
            }
            assertEquals("light", preferences().getString("themeMode", null)); assertEquals("old", legacyId())
            assertEquals(original, journal.readAfter(0)); assertFalse(coordinator().recover())
        }
    }

    @Test fun processRestartBeforeNativeCommitRollsBackBothIndependentlyCommittedStores() = run {
        val archive = export(); setState("light", "old")
        val original = journal.readAfter(0)
        assertThrows(SyntheticDeath::class.java) {
            coordinator().restore(archive, time, "synthetic-process", checkpoint = { if (it == "preferences_committed") throw SyntheticDeath() })
        }
        assertEquals("dark", preferences().getString("themeMode", null)); assertEquals("incoming", legacyId())
        reopen(); assertTrue(coordinator().recover())
        assertEquals("light", preferences().getString("themeMode", null)); assertEquals("old", legacyId())
        assertEquals(original, journal.readAfter(0)); assertFalse(coordinator().recover())
    }

    @Test fun restartAfterFinalCommitKeepsNewStateAndRepeatedImportIsSemanticNoop() = run {
        val archive = export(); setState("light", "old")
        assertThrows(SyntheticDeath::class.java) {
            coordinator().restore(archive, time, "synthetic-process", checkpoint = { if (it == "native_committed") throw SyntheticDeath() })
        }
        reopen(); assertTrue(coordinator().recover())
        assertEquals("dark", preferences().getString("themeMode", null)); assertEquals("incoming", legacyId())
        assertEquals(1L, journal.stats()["gapCount"])
        val rows = journal.readAfter(0)
        assertEquals(true, coordinator().restore(archive, time, "synthetic-process")["unchanged"])
        assertEquals(rows, journal.readAfter(0))
        assertEquals(1, File(context.filesDir, "application_recovery").listFiles()!!.size)
        setState("light", "later")
        assertEquals(false, coordinator().restore(archive, time, "synthetic-process")["unchanged"])
        assertEquals("dark", preferences().getString("themeMode", null)); assertEquals("incoming", legacyId())
    }

    @Test fun cancellationBeforeCommitRollsBackButCancellationAfterCommitCannotUndoCommittedState() = run {
        val archive = export(); setState("light", "old"); var cancelled = false
        assertThrows(ArchiveCancelled::class.java) {
            coordinator().restore(archive, time, "synthetic-process", { cancelled }, { if (it == "legacy_committed") cancelled = true })
        }
        assertEquals("light", preferences().getString("themeMode", null)); assertEquals("old", legacyId())
        cancelled = false
        val result = coordinator().restore(archive, time, "synthetic-process", { cancelled }, { if (it == "native_committed") cancelled = true })
        assertEquals(false, result["unchanged"]); assertEquals("incoming", legacyId())
    }

    @Test fun missingRecoveryArchiveRetainsPreparedIntentAndNeverPublishesFalseCancellation() = run {
        val archive = export(); setState("light", "old")
        assertThrows(SyntheticDeath::class.java) {
            coordinator().restore(archive, time, "synthetic-process", checkpoint = { if (it == "legacy_committed") throw SyntheticDeath() })
        }
        val recovery = File(context.filesDir, "application_recovery").listFiles()!!.single()
        val bytes = recovery.readBytes(); assertTrue(recovery.delete()); reopen()
        assertThrows(ApplicationRecoveryRequired::class.java) { coordinator().recover() }
        assertTrue(File(context.filesDir, "application-restore.intent").exists())
        recovery.writeBytes(bytes)
        assertTrue(coordinator().recover()); assertEquals("old", legacyId())
    }

    @Test fun importedDeliveryReceiptsCannotRegressCurrentHighWaterOrClaimImportedDeliverySuccess() = run {
        delivery().edit().putLong("last_day_daily", 1).putString("last_daily", "old receipt").putString("lastResult", "imported_result").commit()
        val archive = export(); setState("light", "old")
        delivery().edit().putLong("last_day_daily", 9).putString("last_daily", "current receipt").putString("lastResult", "current_result").commit()
        coordinator().restore(archive, time, "synthetic-process")
        assertEquals(9L, delivery().getLong("last_day_daily", 0)); assertEquals("current receipt", delivery().getString("last_daily", null))
        assertEquals("current_result", delivery().getString("lastResult", null))
    }

    @Test fun differentSourceRestoreRebuildsWithinOuterRollbackBoundaryAndNeverPromotesConfidence() = run {
        val archived = journal.readAfter(0).single()
        assertThrows(ObservationConflict::class.java) { journal.append(archived.input.copy(payloadJson = "{\"synthetic\":true}")) }
        journal.acknowledge("synthetic_consumer", archived.sequence)
        val archive = export()
        journal.close(); context.deleteDatabase(name); journal = ObservationJournal(context, name)
        journal.applicationDatabase().let {
            it.disableWriteAheadLogging()
            assertEquals("delete", it.rawQuery("PRAGMA journal_mode=DELETE", null).use { rows -> rows.moveToFirst(); rows.getString(0) })
        }
        journal.append(ObservationInput(UUID.randomUUID().toString(), "COLLECTION_STARTED", "synthetic_restore", "new-process", time, "{}"))
        setState("light", "old"); val prior = journal.readAfter(0)
        assertThrows(IllegalStateException::class.java) {
            coordinator().restore(archive, time, "synthetic-process", checkpoint = { if (it == "legacy_committed") error("synthetic interruption") })
        }
        assertEquals(prior, journal.readAfter(0)); assertEquals("old", legacyId())
        coordinator().restore(archive, time, "synthetic-process")
        assertEquals(archived, journal.readAfter(0).first()); assertEquals(0L, journal.listeningSnapshot(0, 10000, "UTC")["confirmedMs"])
        assertEquals(1L, journal.stats()["gapCount"])
        assertEquals(1L, journal.stats()["conflictCount"])
        assertEquals(0L, journal.cursor("synthetic_consumer"))
    }

    @Test fun walTargetsRemainWalAndUnsafeNativeModeIsRejectedWithoutMutation() = run {
        val archive = export(); setState("light", "old")
        assertTrue(journal.applicationDatabase().enableWriteAheadLogging())
        journal.applicationDatabase().execSQL("PRAGMA synchronous=FULL")
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            assertTrue(it.enableWriteAheadLogging())
        }
        coordinator().restore(archive, time, "synthetic-process")
        assertEquals("wal", journal.applicationDatabase().rawQuery("PRAGMA journal_mode", null).use { it.moveToFirst(); it.getString(0) })
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READONLY).use {
            assertEquals("wal", it.rawQuery("PRAGMA journal_mode", null).use { rows -> rows.moveToFirst(); rows.getString(0) })
        }
        setState("light", "later"); val before = journal.readAfter(0)
        journal.applicationDatabase().execSQL("PRAGMA synchronous=OFF")
        assertThrows(IllegalStateException::class.java) { coordinator().restore(archive, time, "synthetic-process") }
        assertEquals(before, journal.readAfter(0)); assertEquals("later", legacyId())
    }

    @Test fun actualIngressStartupCompensatesBeforePreferencesOrReplayCanBeRead() = run {
        val archive = export(); setState("light", "old")
        assertThrows(SyntheticDeath::class.java) {
            coordinator().restore(archive, time, "synthetic-process", checkpoint = { if (it == "preferences_committed") throw SyntheticDeath() })
        }
        journal.close()
        val ingress = NativeObservationIngress(context, {}, {}, name)
        try {
            val preferences = java.util.concurrent.CompletableFuture<Map<String, Any?>>()
            ingress.preferences(null, preferences::complete, { preferences.completeExceptionally(IllegalStateException(it)) })
            assertEquals("light", preferences.get(20, java.util.concurrent.TimeUnit.SECONDS)["themeMode"])
            assertEquals("old", legacyId())
            val replay = java.util.concurrent.CompletableFuture<Map<String, Any?>>()
            ingress.readPage(0, 100, replay::complete, { replay.completeExceptionally(IllegalStateException(it)) })
            val observations = replay.get(20, java.util.concurrent.TimeUnit.SECONDS)["observations"] as List<*>
            assertEquals("COLLECTION_GAP", (observations.last() as Map<*, *>)["kind"])
            assertFalse(File(context.filesDir, "application-restore.intent").exists())
        } finally { ingress.close() }
    }

    @Test fun directorySyncFailureBeforePreparedIntentCannotChangeAnyApplicationState() = run {
        val archive = export(); setState("light", "old"); val before = journal.readAfter(0)
        DirectoryFsyncShadow.failSync = true
        assertThrows(android.system.ErrnoException::class.java) { coordinator().restore(archive, time, "synthetic-process") }
        assertEquals(before, journal.readAfter(0)); assertEquals("old", legacyId())
        assertEquals("light", preferences().getString("themeMode", null))
        assertFalse(File(context.filesDir, "application-restore.intent").exists())
        DirectoryFsyncShadow.failSync = false
        coordinator().restore(archive, time, "synthetic-process")
        assertTrue(DirectoryFsyncShadow.synced.contains(context.filesDir.path))
        assertTrue(DirectoryFsyncShadow.synced.contains(File(context.filesDir, "application_recovery").path))
    }
}
