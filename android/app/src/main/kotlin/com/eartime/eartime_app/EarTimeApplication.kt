package com.eartime.eartime_app

import android.app.Application
import com.eartime.eartime_app.tracking.NativeJournalRuntime

class EarTimeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Creates a worker; SQLite opening and recovery execute there without a Flutter dependency.
        NativeJournalRuntime.initialize(this)
    }
}
