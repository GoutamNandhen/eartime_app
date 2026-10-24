package com.eartime.eartime_app

import android.content.Context
import android.content.Intent
import android.net.Uri

/** Only presentation destinations. External intents never carry journal/device commands. */
object NavigationTarget {
    val destinations = setOf("home", "timeline", "analytics", "devices", "wellbeing")
    fun parse(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        if (uri.scheme != "eartime" || uri.host != "open" || uri.query != null || uri.fragment != null ||
            uri.userInfo != null || uri.port != -1 || uri.pathSegments.size != 1) return null
        return uri.pathSegments.single().takeIf { it in destinations }
    }
    fun intent(context: Context, destination: String): Intent {
        require(destination in destinations)
        return Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("eartime://open/$destination")
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
    }
}
