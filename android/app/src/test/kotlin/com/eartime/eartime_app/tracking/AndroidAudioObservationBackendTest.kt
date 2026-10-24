package com.eartime.eartime_app.tracking

import android.app.Application
import android.os.Handler
import android.os.Looper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 28, 35], manifest = Config.NONE, application = Application::class)
class AndroidAudioObservationBackendTest {
    @Test fun supportedApiRegistrationAndCleanupReturnOnlyScopedUnknownSamples() {
        val backend = AndroidAudioObservationBackend(RuntimeEnvironment.getApplication(), Handler(Looper.getMainLooper())) {}
        val registration = backend.register()
        try {
            val sample = backend.sample()
            assertEquals(false, sample["actualOutputKnown"])
            assertTrue(sample["connectedInventory"] is List<*>)
            assertTrue(sample["globalMusicActive"] is Boolean)
            assertFalse(sample.containsKey("physicalDeviceId"))
            assertEquals(android.os.Build.VERSION.SDK_INT >= 33, sample["predictedMediaSupported"])
            val a2dp = sample["a2dpTransport"] as Map<*, *>
            assertEquals("BluetoothA2dp.isA2dpPlaying", a2dp["apiSource"])
            assertEquals("UNKNOWN", a2dp["confidence"])
            assertEquals(false, a2dp["liveListeningEligible"])
        } finally { registration.close() }
    }
}
