package com.eartime.eartime_app

import android.app.Application
import android.content.pm.PackageManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], application = Application::class)
class PrivacyConfigurationTest {
    @Test fun permissionDisclosureMatchesManifestWithoutAudioLocationOrScanningGrants() {
        val context = RuntimeEnvironment.getApplication()
        val permissions = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
            .requestedPermissions.orEmpty().toSet()
        assertTrue(permissions.containsAll(setOf("android.permission.BLUETOOTH_CONNECT",
            "android.permission.POST_NOTIFICATIONS", "android.permission.RECEIVE_BOOT_COMPLETED",
            "android.permission.FOREGROUND_SERVICE", "android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE")))
        for (permission in listOf("RECORD_AUDIO", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION",
            "BLUETOOTH_SCAN", "READ_MEDIA_AUDIO", "SCHEDULE_EXACT_ALARM")) {
            assertFalse(permissions.contains("android.permission.$permission"))
        }
        assertEquals(0, context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_ALLOW_BACKUP)
    }
    @Test fun everyAppDataDomainIsExcludedFromCloudBackupAndTransferRules() {
        val context = RuntimeEnvironment.getApplication()
        val expected = setOf("root", "database", "sharedpref", "file", "external")
        val cloud = mutableSetOf<String>(); val transfer = mutableSetOf<String>()
        context.resources.getXml(R.xml.data_extraction_rules).use { parser ->
            var group = ""
            while (parser.next() != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) {
                if (parser.eventType == org.xmlpull.v1.XmlPullParser.START_TAG) {
                    if (parser.name in setOf("cloud-backup", "device-transfer")) group = parser.name
                    if (parser.name == "exclude") {
                        assertEquals(".", parser.getAttributeValue(null, "path"))
                        val domain = parser.getAttributeValue(null, "domain")
                        when (group) { "cloud-backup" -> cloud.add(domain); "device-transfer" -> transfer.add(domain); else -> fail("Unscoped exclusion") }
                    }
                    assertNotEquals("include", parser.name)
                }
            }
        }
        assertEquals(expected, cloud); assertEquals(expected, transfer)
        val legacy = mutableSetOf<String>()
        context.resources.getXml(R.xml.backup_rules).use { parser ->
            while (parser.next() != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) {
                if (parser.eventType == org.xmlpull.v1.XmlPullParser.START_TAG && parser.name == "exclude") {
                    assertEquals(".", parser.getAttributeValue(null, "path")); legacy.add(parser.getAttributeValue(null, "domain"))
                }
            }
        }
        assertEquals(expected, legacy)
    }
}
