package com.eartime.eartime_app.tracking

import android.content.Context
import android.database.DatabaseErrorHandler
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.os.Looper
import java.io.File

/** Research fixture only: attached commits cannot be the production restore strategy for WAL stores. */
internal class ApplicationRestoreTransaction(private val db: SQLiteDatabase, context: Context) : AutoCloseable {
    private var attached = false
    companion object {
        private val rollbackModes = setOf("delete", "truncate", "persist")
        private fun text(db: SQLiteDatabase, sql: String) = db.rawQuery(sql, null).use { check(it.moveToFirst()); it.getString(0) }
    }

    init {
        check(Looper.myLooper() != Looper.getMainLooper()) { "Application restore on Android main thread" }
        check(!db.inTransaction()) { "Application restore already owns a transaction" }
        check(db.path != ":memory:" && File(db.path).isFile) { "Application restore requires persistent native storage" }
        val nativeMode = text(db, "PRAGMA main.journal_mode")
        check(nativeMode in rollbackModes) { "Application restore requires a native rollback journal ($nativeMode); mode was not changed" }
        check(text(db, "PRAGMA main.synchronous").toInt() >= 2) { "Application restore requires native FULL synchronization" }
        check(db.attachedDbs.map { it.first }.all { it == "main" }) { "Unexpected attached application database" }
        val legacy = ApplicationArchive.legacyFile(context)
        check(legacy.isFile) { "Preserved legacy storage must be prepared by its Drift owner before restore" }
        SQLiteDatabase.openDatabase(legacy.path, null, SQLiteDatabase.OPEN_READONLY,
            DatabaseErrorHandler { throw SQLiteException("Preserved legacy corruption; original retained") }).use {
            check(it.version == 1) { "Unsupported preserved legacy schema" }
            check(text(it, "PRAGMA main.journal_mode") in rollbackModes) { "Application restore requires a legacy rollback journal; mode was not changed" }
        }
        try {
            db.execSQL("ATTACH DATABASE ? AS legacy_restore", arrayOf(legacy.path))
            attached = true
            check(text(db, "PRAGMA legacy_restore.journal_mode") in rollbackModes) { "Legacy journal mode changed during restore preflight" }
            db.execSQL("PRAGMA legacy_restore.synchronous=FULL")
        } catch (error: Throwable) { close(); throw error }
    }

    fun <T> transaction(work: () -> T): T {
        check(attached && !db.inTransaction())
        db.beginTransaction()
        try {
            val value = work()
            db.setTransactionSuccessful()
            return value
        } finally { db.endTransaction() }
    }

    override fun close() {
        if (attached) {
            check(!db.inTransaction()) { "Application restore transaction did not finish" }
            db.execSQL("DETACH DATABASE legacy_restore")
            attached = false
        }
    }
}
