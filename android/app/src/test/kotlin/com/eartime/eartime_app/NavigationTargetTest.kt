package com.eartime.eartime_app

import android.app.Application
import android.content.Intent
import android.net.Uri
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], application = Application::class)
class NavigationTargetTest {
    @Test fun summaryComponentsArePrivateOptInAndJobPermissionProtected() {
        val context = RuntimeEnvironment.getApplication()
        val manager = context.packageManager
        val receiver = manager.getReceiverInfo(android.content.ComponentName(context,
            com.eartime.eartime_app.tracking.WellbeingSummaryReceiver::class.java), android.content.pm.PackageManager.MATCH_DISABLED_COMPONENTS)
        assertFalse(receiver.exported); assertFalse(receiver.enabled)
        val job = manager.getServiceInfo(android.content.ComponentName(context,
            com.eartime.eartime_app.tracking.WellbeingSummaryJob::class.java), 0)
        assertFalse(job.exported); assertEquals("android.permission.BIND_JOB_SERVICE", job.permission)
        val permissions = manager.getPackageInfo(context.packageName, android.content.pm.PackageManager.GET_PERMISSIONS).requestedPermissions.orEmpty().toList()
        assertTrue(permissions.contains("android.permission.RECEIVE_BOOT_COMPLETED"))
        assertFalse(permissions.contains("android.permission.SCHEDULE_EXACT_ALARM"))
    }
    @Test fun manifestDisablesCompetingFlutterUriHandlerAndDeclaresFourValidShortcuts() {
        val context = RuntimeEnvironment.getApplication()
        val info = context.packageManager.getActivityInfo(android.content.ComponentName(context, MainActivity::class.java),
            android.content.pm.PackageManager.GET_META_DATA)
        assertFalse(info.metaData.getBoolean("flutter_deeplinking_enabled", true))
        var count = 0
        context.resources.getXml(R.xml.shortcuts).use { xml ->
            while (xml.next() != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) {
                if (xml.eventType == org.xmlpull.v1.XmlPullParser.START_TAG && xml.name == "intent") {
                    val data = xml.getAttributeValue("http://schemas.android.com/apk/res/android", "data")
                    assertNotNull(NavigationTarget.parse(Intent(Intent.ACTION_VIEW, Uri.parse(data))))
                    count++
                }
            }
        }
        assertEquals(4, count)
    }

    @Test fun allWidgetAndShortcutDestinationsRoundTripWithExplicitComponent() {
        NavigationTarget.destinations.forEach {
            val intent = NavigationTarget.intent(RuntimeEnvironment.getApplication(), it)
            assertEquals(it, NavigationTarget.parse(intent))
            assertEquals(MainActivity::class.java.name, intent.component!!.className)
        }
    }
    @Test fun untrustedIntentsCannotInvokeCommandsOrCarryPrivateArguments() {
        listOf("eartime://open/delete", "eartime://open/devices?address=private",
            "eartime://open/home#command", "eartime://open/home/extra", "https://open/home",
            "eartime://user@open/home", "eartime://open:123/home").forEach {
            assertNull(NavigationTarget.parse(Intent(Intent.ACTION_VIEW, Uri.parse(it))))
        }
        assertNull(NavigationTarget.parse(Intent(Intent.ACTION_SEND, Uri.parse("eartime://open/home"))))
        assertNull(NavigationTarget.parse(null))
    }
}
