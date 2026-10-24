package com.eartime.eartime_app

import android.app.Application
import android.content.pm.ApplicationInfo
import android.os.Build
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 28, 35], application = Application::class)
class AppBuildInformationTest {
    private val context get() = RuntimeEnvironment.getApplication()
    @Suppress("DEPRECATION")
    private fun installed(name: String?, code: Long) {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        info.versionName = name
        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode = code else info.versionCode = code.toInt()
        shadowOf(context.packageManager).installPackage(info)
    }
    @Test fun readsPackagedManifestRatherThanHardcodedDisplayVersion() {
        val value = AppBuildInformation.read(context)
        assertEquals("1.1.0-dev.1", value["versionName"])
        assertEquals(2L, value["versionCode"])
        assertEquals(context.packageName, value["packageName"])
        assertEquals(1, value["version"])
    }
    @Test fun installedOverrideIsReadFreshAndLongCodeIsNotTruncated() {
        val code = if (Build.VERSION.SDK_INT >= 28) (1L shl 32) + 9 else 9L
        installed("2.0.0-rc.2", code)
        assertEquals(code, AppBuildInformation.read(context)["versionCode"])
        assertEquals("2.0.0-rc.2", AppBuildInformation.read(context)["versionName"])
        installed("2.0.0", 10)
        assertEquals("2.0.0", AppBuildInformation.read(context)["versionName"])
    }
    @Test fun missingMalformedVersionFailsRatherThanInventingMetadata() {
        for (name in listOf(null, "", "private\nvalue", "x".repeat(129))) {
            installed(name, 1)
            assertThrows(Exception::class.java) { AppBuildInformation.read(context) }
        }
        installed("1.0.0", 0)
        assertThrows(Exception::class.java) { AppBuildInformation.read(context) }
    }
    @Test fun debugFlagIsIndependentOfVersionOrReleaseReadiness() {
        installed("2.0.0", 10)
        context.applicationInfo.flags = context.applicationInfo.flags or ApplicationInfo.FLAG_DEBUGGABLE
        assertEquals(true, AppBuildInformation.read(context)["debuggable"])
        context.applicationInfo.flags = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE.inv()
        assertEquals(false, AppBuildInformation.read(context)["debuggable"])
        assertEquals(setOf("version", "packageName", "versionName", "versionCode", "debuggable"), AppBuildInformation.read(context).keys)
    }
}
