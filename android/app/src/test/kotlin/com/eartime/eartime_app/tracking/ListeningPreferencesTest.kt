package com.eartime.eartime_app.tracking

import android.app.Application
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class ListeningPreferencesTest {
    @Before fun clean() { RuntimeEnvironment.getApplication().getSharedPreferences("eartime_preferences_v1", 0).edit().clear().commit() }
    @Test fun defaultsHaveNoFabricatedGoalOrForcedTheme() {
        val value = ListeningPreferences(RuntimeEnvironment.getApplication()).snapshot()
        assertEquals(0, value["dailyGoalMinutes"]); assertEquals("system", value["themeMode"])
    }
    @Test fun goalAndThemePersistAcrossNewOwner() {
        val context = RuntimeEnvironment.getApplication()
        val saved = ListeningPreferences(context).update(mapOf("dailyGoalMinutes" to 45, "themeMode" to "dark"))
        assertEquals(saved, ListeningPreferences(context).snapshot())
    }
    @Test fun invalidUpdateDoesNotPartiallyCommitValidFields() {
        val preferences = ListeningPreferences(RuntimeEnvironment.getApplication())
        assertThrows(IllegalArgumentException::class.java) { preferences.update(mapOf("themeMode" to "light", "dailyGoalMinutes" to -1)) }
        assertEquals("system", preferences.snapshot()["themeMode"])
    }
    @Test fun unsupportedOrFractionalValuesAreRejected() {
        val preferences = ListeningPreferences(RuntimeEnvironment.getApplication())
        assertThrows(IllegalArgumentException::class.java) { preferences.update(mapOf("dailyGoalMinutes" to 30.5)) }
        assertThrows(IllegalArgumentException::class.java) { preferences.update(mapOf("arbitrary" to true)) }
        assertThrows(IllegalArgumentException::class.java) { preferences.update(mapOf("themeMode" to "invalid")) }
    }
    @Test fun disablingGoalIsDurableAndDoesNotEraseTheme() {
        val preferences = ListeningPreferences(RuntimeEnvironment.getApplication())
        preferences.update(mapOf("themeMode" to "light", "dailyGoalMinutes" to 30))
        val value = preferences.update(mapOf("dailyGoalMinutes" to 0))
        assertEquals(0, value["dailyGoalMinutes"]); assertEquals("light", value["themeMode"])
    }

    @Test fun deviceNamesRequireOpaqueIdsAndRejectControlCharactersWithoutPartialWrites() {
        val preferences = ListeningPreferences(RuntimeEnvironment.getApplication())
        val id = "00000000-0000-4000-8000-000000000001"
        assertThrows(IllegalArgumentException::class.java) { preferences.update(mapOf("deviceNames" to mapOf("Buds" to "Name"))) }
        assertThrows(IllegalArgumentException::class.java) { preferences.update(mapOf("themeMode" to "dark", "deviceNames" to mapOf(id to "bad\nname"))) }
        assertEquals("system", preferences.snapshot()["themeMode"])
        preferences.update(mapOf("deviceNames" to mapOf(id to "Custom")))
        assertEquals("Custom", preferences.deviceName(id))
        preferences.update(mapOf("deviceNames" to mapOf(id to "")))
        assertNull(preferences.deviceName(id))
    }
}
