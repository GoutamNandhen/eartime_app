package com.eartime.eartime_app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build

internal object AppBuildInformation {
    @Suppress("DEPRECATION")
    fun read(context: Context): Map<String, Any> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val name = info.versionName?.takeIf { it.length in 1..128 && it.none(Char::isISOControl) }
            ?: error("Package version unavailable")
        val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
        check(code > 0) { "Package build number unavailable" }
        check(info.packageName == context.packageName) { "Package identity mismatch" }
        return mapOf("version" to 1, "packageName" to context.packageName,
            "versionName" to name, "versionCode" to code,
            "debuggable" to ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0))
    }
}
