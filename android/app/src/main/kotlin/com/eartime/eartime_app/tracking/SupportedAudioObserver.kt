package com.eartime.eartime_app.tracking

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/** Passive public-API samples only. No routing, playback, Bluetooth/GATT or pairing writes. */
internal class AndroidAudioObservationBackend(
    context: Context, private val handler: Handler, private val changed: () -> Unit,
) : AudioObservationBackend {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        ?: throw IllegalStateException("AudioManager unavailable")
    override fun register(): AutoCloseable {
        val devices = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = changed()
            override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = changed()
        }
        val playback = if (Build.VERSION.SDK_INT >= 26) object : AudioManager.AudioPlaybackCallback() {
            // Callback configurations may be delayed/redacted: sample fresh public state instead.
            override fun onPlaybackConfigChanged(configs: MutableList<AudioPlaybackConfiguration>?) = changed()
        } else null
        var deviceRegistered = false
        var playbackRegistered = false
        fun cleanup() {
            try { if (deviceRegistered) audio.unregisterAudioDeviceCallback(devices) }
            finally { if (playbackRegistered && playback != null) audio.unregisterAudioPlaybackCallback(playback) }
        }
        try {
            audio.registerAudioDeviceCallback(devices, handler); deviceRegistered = true
            if (playback != null) { audio.registerAudioPlaybackCallback(playback, handler); playbackRegistered = true }
        } catch (error: Exception) {
            try { cleanup() } catch (cleanup: Exception) { error.addSuppressed(cleanup) }
            throw error
        }
        return AutoCloseable { cleanup() }
    }

    override fun sample(): Map<String, Any?> {
        val devices = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        check(devices.size <= 128) { "Audio inventory exceeds bounded sample" }
        fun device(info: AudioDeviceInfo) = mapOf("systemRouteId" to info.id.toString(),
            "nativeType" to info.type, "isSink" to info.isSink)
        val communication = if (Build.VERSION.SDK_INT >= 31) audio.communicationDevice?.let(::device) else null
        val predicted = if (Build.VERSION.SDK_INT >= 33) audio.getAudioDevicesForAttributes(
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build()) else emptyList()
        check(predicted.size <= 128) { "Predicted routing exceeds bounded sample" }
        return mapOf("connectedInventory" to devices.map(::device), "globalMusicActive" to audio.isMusicActive,
            "communicationDevice" to communication, "predictedMediaDevices" to predicted.map(::device),
            "predictedMediaSupported" to (Build.VERSION.SDK_INT >= 33),
            "activityObservation" to if (Build.VERSION.SDK_INT >= 26) "callback_and_poll" else "poll",
            "actualOutputKnown" to false)
    }
}

/** Service-owned lifecycle; all registration/sampling/cleanup is off the main thread. */
class SupportedAudioObserver private constructor(context: Context) : AutoCloseable {
    companion object {
        private val generations = AtomicLong()
        fun start(context: Context): SupportedAudioObserver? = try { SupportedAudioObserver(context.applicationContext) }
            catch (_: Exception) { TrackingEventBroker.reportPersistenceFailure("Supported audio observer worker unavailable"); null }
    }
    private val closed = AtomicBoolean(false)
    val isClosed: Boolean get() = closed.get()
    private val sampleQueued = AtomicBoolean(false)
    private val thread = HandlerThread("EarTimeAudioEvidence").apply { start() }
    private val handler = Handler(thread.looper)
    private val backend = object : AudioObservationBackend {
        private var platform: AndroidAudioObservationBackend? = null
        override fun register(): AutoCloseable {
            val target = AndroidAudioObservationBackend(context, handler, ::requestSample)
            platform = target
            return target.register()
        }
        override fun sample() = checkNotNull(platform).sample()
    }
    private val owner = AudioObserverOwner(backend,
        { AudioSampleTime(System.currentTimeMillis(), SystemClock.elapsedRealtime()) }, generations::incrementAndGet,
        { event, captured, completion -> NativeJournalRuntime.submitObserver(event, captured.elapsedMs) { accepted ->
            handler.post { completion(accepted) }
        } })
    private val sample = Runnable { sampleQueued.set(false); if (!closed.get()) owner.sample() }
    private val poll = object : Runnable {
        override fun run() {
            if (!closed.get()) { owner.sample(); handler.postDelayed(this, 10000) }
        }
    }
    init { handler.post { if (!closed.get()) { owner.start(); handler.postDelayed(poll, 10000) } } }
    private fun requestSample() {
        if (!closed.get() && sampleQueued.compareAndSet(false, true)) handler.postDelayed(sample, 250)
    }
    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        handler.removeCallbacks(sample); handler.removeCallbacks(poll)
        handler.post { try { owner.close() } finally { thread.quitSafely() } }
    }
}
