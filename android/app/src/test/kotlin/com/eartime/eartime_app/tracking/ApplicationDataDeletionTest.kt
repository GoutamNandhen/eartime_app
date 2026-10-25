package com.eartime.eartime_app.tracking

import android.app.ActivityManager
import android.app.Application
import android.content.Context
import android.content.ContextWrapper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 28, 35], manifest = Config.NONE, application = Application::class)
class ApplicationDataDeletionTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val manager get() = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    @Test fun missingConfirmationWrongScopeAndRetiredOwnersNeverReachAndroidDeletion() {
        val deletion = ApplicationDataDeletion(context)
        assertThrows(IllegalArgumentException::class.java) { deletion.request(false, "all_app_private_data") { true } }
        assertThrows(IllegalArgumentException::class.java) { deletion.request(true, "native_history") { true } }
        assertThrows(IllegalStateException::class.java) { deletion.request(true, "all_app_private_data") { false } }
        assertFalse(shadowOf(manager).isApplicationUserDataCleared)
    }
    @Test fun confirmedRequestUsesTheSupportedSelfDataApiButDoesNotClaimCompletion() {
        val fixture = File(context.filesDir, "synthetic-retained-fixture").apply { writeText("synthetic") }
        val result = ApplicationDataDeletion(context).request(true, "all_app_private_data") { true }
        assertEquals(true, result["requested"]); assertEquals(false, result["completed"])
        assertTrue(shadowOf(manager).isApplicationUserDataCleared)
        assertTrue(fixture.exists()) // Robolectric acknowledges; it does not establish actual OS wipe/termination.
    }
    @Test fun ownerIsRecheckedAfterServiceLookup() {
        var active = true
        val wrapped = object : ContextWrapper(context) {
            override fun getApplicationContext(): Context = this
            override fun getSystemService(name: String): Any? { active = false; return super.getSystemService(name) }
        }
        assertThrows(IllegalStateException::class.java) { ApplicationDataDeletion(wrapped).request(true, "all_app_private_data") { active } }
        assertFalse(shadowOf(manager).isApplicationUserDataCleared)
    }
    @Test @Config(shadows = [DeletionManager::class]) fun rejectionCanRetryButAcceptedRequestsAreNotSentTwice() {
        DeletionManager.calls = 0; DeletionManager.accepted = false; DeletionManager.failure = null
        val deletion = ApplicationDataDeletion(context)
        assertEquals(false, deletion.request(true, "all_app_private_data") { true }["requested"])
        DeletionManager.accepted = true
        assertEquals(true, deletion.request(true, "all_app_private_data") { true }["requested"])
        assertEquals(true, deletion.request(true, "all_app_private_data") { true }["requested"])
        assertEquals(2, DeletionManager.calls)
    }
    @Test fun unavailableServiceCannotAcknowledgeDeletion() {
        val wrapped = object : ContextWrapper(context) {
            override fun getApplicationContext(): Context = this
            override fun getSystemService(name: String): Any? = null
        }
        assertThrows(IllegalStateException::class.java) { ApplicationDataDeletion(wrapped).request(true, "all_app_private_data") { true } }
        assertFalse(shadowOf(manager).isApplicationUserDataCleared)
    }
    @Test @Config(shadows = [DeletionManager::class]) fun platformFailureCannotInventAnAcknowledgment() {
        DeletionManager.calls = 0; DeletionManager.failure = SecurityException("synthetic platform rejection")
        val deletion = ApplicationDataDeletion(context)
        assertThrows(SecurityException::class.java) { deletion.request(true, "all_app_private_data") { true } }
        DeletionManager.failure = null; DeletionManager.accepted = false
        assertEquals(false, deletion.request(true, "all_app_private_data") { true }["requested"])
        assertEquals(2, DeletionManager.calls)
    }
    @Test @Config(sdk = [28]) fun queuedDeletionRejectsRetiredEngine() {
        val entered = CountDownLatch(1); val release = CountDownLatch(1)
        val active = AtomicBoolean(true)
        val name = "del-${UUID.randomUUID().toString().take(6)}.db"
        val ingress = NativeObservationIngress(context, { entered.countDown(); check(release.await(10, TimeUnit.SECONDS)) }, {}, name)
        try {
            ingress.submit(mapOf("type" to "PLAYBACK_STARTED", "timestamp" to 1000L))
            assertTrue(entered.await(10, TimeUnit.SECONDS))
            val outcome = CompletableFuture<String>()
            ingress.deleteApplicationData(true, "all_app_private_data", active::get,
                { outcome.complete("unexpected_success") }, { outcome.complete(it) })
            active.set(false); release.countDown()
            assertEquals("IllegalStateException: Deletion command owner retired", outcome.get(10, TimeUnit.SECONDS))
            assertFalse(shadowOf(manager).isApplicationUserDataCleared)
        } finally { release.countDown(); ingress.close(); context.deleteDatabase(name) }
    }
    @Implements(ActivityManager::class)
    class DeletionManager {
        companion object { var calls = 0; var accepted = false; var failure: RuntimeException? = null }
        @Implementation protected fun clearApplicationUserData(): Boolean { calls++; failure?.let { throw it }; return accepted }
    }
}
