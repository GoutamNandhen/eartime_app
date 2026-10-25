package com.eartime.eartime_app.tracking

import android.app.ActivityManager
import android.content.Context

/** Android owns the complete self-data wipe; success here acknowledges only its request. */
internal class ApplicationDataDeletion(context: Context) {
    private val context = context.applicationContext
    private var requested = false

    fun request(confirmed: Boolean, scope: String, ownerActive: () -> Boolean): Map<String, Any?> {
        require(confirmed && scope == "all_app_private_data") { "Explicit full-data confirmation required" }
        check(ownerActive()) { "Deletion command owner retired" }
        if (!requested) {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: error("Android data deletion unavailable")
            check(ownerActive()) { "Deletion command owner retired" }
            requested = manager.clearApplicationUserData()
        }
        return mapOf("version" to 1, "scope" to "all_app_private_data", "requested" to requested, "completed" to false)
    }
}
