package com.eartime.eartime_app.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import com.eartime.eartime_app.MainActivity
import com.eartime.eartime_app.R
import com.eartime.eartime_app.tracking.NativeJournalRuntime
import java.util.Calendar

class ListeningWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        ListeningWidgets.refresh(context) { pending?.finish() }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: android.os.Bundle) {
        onUpdate(context, manager, intArrayOf(id))
    }
}

object ListeningWidgets {
    private val main = Handler(Looper.getMainLooper())
    private var scheduled = false

    fun observationCommitted(context: Context) {
        main.post {
            if (scheduled || ids(context).isEmpty()) return@post
            scheduled = true
            main.postDelayed({ scheduled = false; refresh(context) {} }, 1000)
        }
    }

    private fun ids(context: Context) = AppWidgetManager.getInstance(context)
        .getAppWidgetIds(ComponentName(context, ListeningWidgetProvider::class.java))

    fun refresh(context: Context, completed: () -> Unit) {
        val ids = ids(context)
        if (ids.isEmpty()) { completed(); return }
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val from = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_MONTH, 1)
        NativeJournalRuntime.readListening(from, calendar.timeInMillis, calendar.timeZone.id, 0, 1, { snapshot ->
            try { AppWidgetManager.getInstance(context).updateAppWidget(ids, render(context, snapshot)) }
            finally { completed() }
        }, {
            try {
                val view = render(context, emptyMap())
                view.setTextViewText(R.id.widget_status, "History unavailable")
                AppWidgetManager.getInstance(context).updateAppWidget(ids, view)
            } finally { completed() }
        })
    }

    fun render(context: Context, snapshot: Map<String, Any?>): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.listening_widget)
        val duration = (snapshot["confirmedMs"] as? Long ?: 0) / 1000
        views.setTextViewText(R.id.widget_total, "${duration / 3600}h ${duration / 60 % 60}m")
        views.setTextViewText(R.id.widget_status, if (snapshot["lastError"] != null) "Collection incomplete"
            else if (snapshot.isEmpty()) "History unavailable" else "Confirmed listening today")
        val intent = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_root, intent)
        val devices = (snapshot["devices"] as? List<*>)?.mapNotNull { it as? Map<*, *> }
            ?.sortedByDescending { it["connected"] == true } ?: emptyList()
        val visibleCount = if (context.resources.configuration.fontScale > 1.3f) 2 else 4
        views.setViewVisibility(R.id.widget_second_row, if (visibleCount == 2) android.view.View.GONE else android.view.View.VISIBLE)
        val names = intArrayOf(R.id.device_name_1, R.id.device_name_2, R.id.device_name_3, R.id.device_name_4)
        val states = intArrayOf(R.id.device_state_1, R.id.device_state_2, R.id.device_state_3, R.id.device_state_4)
        val batteries = intArrayOf(R.id.device_battery_1, R.id.device_battery_2, R.id.device_battery_3, R.id.device_battery_4)
        for (index in names.indices) {
            val device = devices.getOrNull(index)
            views.setTextViewText(names[index], device?.get("name") as? String ?: "No device")
            views.setTextViewText(states[index], if (device == null) "Not observed" else if (device["connected"] == true) "Connected" else "Disconnected")
            // No validated battery collector exists. Unknown is never rendered as zero or a stale percentage.
            views.setTextViewText(batteries[index], "Battery unknown")
        }
        val deviceCount = snapshot["deviceCount"] as? Long ?: devices.size.toLong()
        views.setTextViewText(R.id.widget_more, if (deviceCount > visibleCount) "+${deviceCount - visibleCount} devices" else "EarTime")
        return views
    }
}
