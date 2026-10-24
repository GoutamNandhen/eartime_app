package com.eartime.eartime_app.tracking

import android.app.Application
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class SupportedAudioObserverTest {
    @Test(timeout = 15000) fun startAndCloseReturnEvenWhenWorkerInitializationIsBlocked() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val stopped = CountDownLatch(1)
        val registrations = AtomicInteger()
        val observer = SupportedAudioObserver(RuntimeEnvironment.getApplication(), { _, _ ->
            entered.countDown()
            check(release.await(10, TimeUnit.SECONDS))
            object : AudioObservationBackend {
                override fun register(): AutoCloseable { registrations.incrementAndGet(); return AutoCloseable {} }
                override fun sample() = emptyMap<String, Any?>()
            }
        }, stopped::countDown)
        try {
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            observer.close() // Must return without waiting for release or joining the worker.
            assertTrue(observer.isClosed)
        } finally { observer.close(); release.countDown() }
        assertTrue(stopped.await(5, TimeUnit.SECONDS))
        assertEquals(0, registrations.get())
    }

    @Test(timeout = 15000) fun runningWorkerCleansUpExactlyOnceOnRepeatedClose() {
        val sampled = CountDownLatch(1)
        val stopped = CountDownLatch(1)
        val cleanups = AtomicInteger()
        val observer = SupportedAudioObserver(RuntimeEnvironment.getApplication(), { _, _ ->
            object : AudioObservationBackend {
                override fun register() = AutoCloseable { cleanups.incrementAndGet() }
                override fun sample(): Map<String, Any?> { sampled.countDown(); return mapOf("actualOutputKnown" to false) }
            }
        }, stopped::countDown)
        try { assertTrue(sampled.await(5, TimeUnit.SECONDS)) }
        finally { observer.close(); observer.close() }
        assertTrue(stopped.await(5, TimeUnit.SECONDS))
        assertEquals(1, cleanups.get())
    }
}
