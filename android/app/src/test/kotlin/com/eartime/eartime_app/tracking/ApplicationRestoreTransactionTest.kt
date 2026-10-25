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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class ApplicationRestoreTransactionTest {
    private lateinit var context: Context
    private lateinit var db: SQLiteDatabase
    private val worker = Executors.newSingleThreadExecutor()
    private val name = "tx-${UUID.randomUUID().toString().take(6)}.db"
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        run {
            db = context.openOrCreateDatabase(name, 0, null)
            db.disableWriteAheadLogging()
            assertEquals("delete", db.rawQuery("PRAGMA journal_mode=DELETE", null).use { it.moveToFirst(); it.getString(0) })
            db.execSQL("PRAGMA synchronous=FULL")
            db.execSQL("CREATE TABLE restore_fixture(value INTEGER NOT NULL)"); db.execSQL("INSERT INTO restore_fixture VALUES (1)")
            SQLiteDatabase.openOrCreateDatabase(ApplicationArchive.legacyFile(context), null).use {
                it.disableWriteAheadLogging()
                assertEquals("delete", it.rawQuery("PRAGMA journal_mode=DELETE", null).use { rows -> rows.moveToFirst(); rows.getString(0) })
                it.version = 1; it.execSQL("CREATE TABLE restore_fixture(value INTEGER NOT NULL)"); it.execSQL("INSERT INTO restore_fixture VALUES (2)")
            }
        }
    }
    @After fun cleanup() { run { db.close() }; worker.shutdownNow(); context.deleteDatabase(name); SQLiteDatabase.deleteDatabase(ApplicationArchive.legacyFile(context)) }
    private fun scalar(db: SQLiteDatabase, sql: String) = db.rawQuery(sql, null).use { it.moveToFirst(); it.getLong(0) }
    private fun legacyValue() = SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READONLY).use {
        scalar(it, "SELECT value FROM restore_fixture")
    }
    @Test fun attachedCommitAndRollbackKeepNativeAndLegacyRowsTogether() = run {
        ApplicationRestoreTransaction(db, context).use { transaction ->
            assertThrows(IllegalStateException::class.java) { transaction.transaction {
                db.execSQL("UPDATE main.restore_fixture SET value=10")
                db.execSQL("UPDATE legacy_restore.restore_fixture SET value=20")
                error("synthetic before-commit interruption")
            } }
            assertEquals(1L, scalar(db, "SELECT value FROM main.restore_fixture")); assertEquals(2L, legacyValue())
            transaction.transaction {
                db.execSQL("UPDATE main.restore_fixture SET value=10")
                db.execSQL("UPDATE legacy_restore.restore_fixture SET value=20")
            }
        }
        assertEquals(10L, scalar(db, "SELECT value FROM main.restore_fixture")); assertEquals(20L, legacyValue())
        assertEquals(listOf("main"), db.attachedDbs.map { it.first })
    }
    @Test fun nativeWalIsRefusedBeforeAttachWithoutChangingItsJournalMode() = run {
        assertTrue(db.enableWriteAheadLogging())
        val failure = assertThrows(IllegalStateException::class.java) { ApplicationRestoreTransaction(db, context) }
        assertTrue(failure.message!!.contains("native rollback journal (wal)"))
        assertEquals("wal", db.rawQuery("PRAGMA journal_mode", null).use { it.moveToFirst(); it.getString(0) })
        assertEquals(listOf("main"), db.attachedDbs.map { it.first }); assertEquals(2L, legacyValue())
    }
    @Test fun legacyWalIsRefusedWithoutMutatingEitherDatabase() = run {
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            assertTrue(it.enableWriteAheadLogging())
        }
        val failure = assertThrows(IllegalStateException::class.java) { ApplicationRestoreTransaction(db, context) }
        assertTrue(failure.message!!.contains("legacy rollback journal"))
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READONLY).use {
            assertEquals("wal", it.rawQuery("PRAGMA journal_mode", null).use { rows -> rows.moveToFirst(); rows.getString(0) })
        }
        assertEquals(1L, scalar(db, "SELECT value FROM restore_fixture")); assertEquals(2L, legacyValue())
    }
    @Test fun unsafeSynchronizationOrAnExistingTransactionCannotBeSilentlyOverridden() = run {
        db.execSQL("PRAGMA synchronous=OFF")
        assertThrows(IllegalStateException::class.java) { ApplicationRestoreTransaction(db, context) }
        assertEquals(0L, scalar(db, "PRAGMA synchronous"))
        db.execSQL("PRAGMA synchronous=FULL"); db.beginTransaction()
        try { assertThrows(IllegalStateException::class.java) { ApplicationRestoreTransaction(db, context) } }
        finally { db.endTransaction() }
        assertEquals(1L, scalar(db, "SELECT value FROM restore_fixture"))
    }
}
