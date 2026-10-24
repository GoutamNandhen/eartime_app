package com.eartime.eartime_app.tracking

import android.os.SystemClock
import android.util.Log
import java.util.UUID

/** Low-volume lifecycle milestones; uptime is diagnostic, not an event timestamp. */
object StartupTrace {
    val procGen: String = UUID.randomUUID().toString().substring(0, 8)
    val pid: Int get() = android.os.Process.myPid()

    init { mark("PROCESS_OBSERVED") }

    fun mark(stage: String, fields: String = "") {
        Log.i("EarTimeDiag", "[STARTUP_TRACE:proc=$procGen:pid=$pid] $stage elapsedMs=${SystemClock.elapsedRealtime()} $fields")
    }
}
