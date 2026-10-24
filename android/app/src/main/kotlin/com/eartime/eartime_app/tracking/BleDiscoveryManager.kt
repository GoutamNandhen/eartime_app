package com.eartime.eartime_app.tracking

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.content.Context
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Executor
import java.util.concurrent.Semaphore
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.atomic.AtomicBoolean

/** One-shot service catalog inspection; never automatic, subscribed or hardware-verified. */
class BleDiscoveryManager internal constructor(
    private val consent: BleDiagnosticConsent,
    private val connect: (BluetoothDevice, BluetoothGattCallback) -> BluetoothGatt?,
    private val worker: Executor,
    private val cleanup: Executor,
    private val permits: Semaphore,
    private val schedule: (Runnable) -> AutoCloseable,
    private val publish: (Map<String, Any?>) -> Unit,
) {
    @SuppressLint("MissingPermission")
    constructor(context: Context) : this(BleDiagnosticAuthorization.consent,
        { device, callback -> device.connectGatt(context.applicationContext, false, callback) },
        workers, cleaners, capacity, { job ->
            val task = deadlines.schedule(job, 10, TimeUnit.SECONDS)
            AutoCloseable { task.cancel(false) }
        }, { event -> NativeJournalRuntime.submitDiagnostic(event, android.os.SystemClock.elapsedRealtime()) })

    companion object {
        internal const val SOURCE = "optional_read_only_gatt_catalog"
        private fun pool(name: String, threads: Int, queue: Int) = ThreadPoolExecutor(threads, threads,
            0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue(queue), { job -> Thread(job, name).apply { isDaemon = true } })
        private val workers = pool("EarTimeOptionalGatt", 2, 8)
        private val cleaners = pool("EarTimeOptionalGattClose", 2, 2)
        private val capacity = Semaphore(2)
        private val deadlines = ScheduledThreadPoolExecutor(1) { job -> Thread(job, "EarTimeGattDeadline").apply { isDaemon = true } }
            .apply { removeOnCancelPolicy = true }

        internal fun catalog(services: List<BluetoothGattService>): List<Map<String, Any?>> {
            require(services.size <= 32) { "Service inventory exceeds bound" }
            var count = 0
            return services.map { service ->
                require(service.characteristics.size <= 64) { "Characteristic inventory exceeds bound" }
                val rows = service.characteristics.map { characteristic ->
                    require(++count <= 256) { "Total characteristic inventory exceeds bound" }
                    mapOf("uuid" to characteristic.uuid.toString().uppercase(), "properties" to buildList {
                        if (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ != 0) add("READ")
                        if (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) add("WRITE")
                        if (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) add("NOTIFY")
                    })
                }
                mapOf("uuid" to service.uuid.toString().uppercase(), "type" to
                    if (service.type == BluetoothGattService.SERVICE_TYPE_PRIMARY) "PRIMARY" else "SECONDARY",
                    "characteristics" to rows)
            }
        }
    }
    @Volatile private var active: Session? = null

    @SuppressLint("MissingPermission")
    fun discover(device: BluetoothDevice, forceRefresh: Boolean = false) {
        // Ordinary collector inventory calls cannot authorize device interaction.
        if (!forceRefresh) return
        val address = try { device.address } catch (_: Exception) { state("UNAVAILABLE", "endpoint_unavailable"); return }
        if (!consent.consume(address)) { state("UNAVAILABLE", "explicit_authorization_required"); return }
        if (!permits.tryAcquire()) { state("UNAVAILABLE", "diagnostic_capacity_unavailable"); return }
        val session = Session(device)
        active?.close(); active = session
        try {
            session.deadline = schedule(Runnable { session.close("diagnostic_deadline") })
            worker.execute {
                try {
                    if (!session.closed.get()) session.gatt = connect(device, session.callback)
                } catch (_: Exception) { session.close("connection_unavailable") }
                finally {
                    session.opened.set(true)
                    if (session.gatt == null) session.close("connection_unavailable")
                    if (session.closed.get()) session.dispose()
                }
            }
        } catch (_: Exception) {
            session.opened.set(true); session.close("diagnostic_worker_unavailable")
        }
    }

    fun disconnect() { active?.close() }
    private fun state(phase: String, reason: String) {
        runCatching { publish(mapOf("type" to "BLE_DIAGNOSTIC_STATE", "state" to phase,
            "reason" to reason, "readOnly" to true, "timestamp" to System.currentTimeMillis())) }
    }

    private inner class Session(val device: BluetoothDevice) {
        val closed = AtomicBoolean(false)
        val opened = AtomicBoolean(false)
        private val disposing = AtomicBoolean(false)
        private val discoveryRequested = AtomicBoolean(false)
        @Volatile var gatt: BluetoothGatt? = null
        @Volatile var deadline: AutoCloseable? = null
        fun close(reason: String = "diagnostic_closed") {
            if (synchronized(this) { closed.compareAndSet(false, true) }) {
                deadline?.close()
                state("STOPPED", reason)
            }
            if (opened.get()) dispose()
        }
        @SuppressLint("MissingPermission")
        fun dispose() {
            if (!disposing.compareAndSet(false, true)) return
            try { cleanup.execute {
                try { gatt?.close(); permits.release() }
                catch (_: Exception) { state("UNAVAILABLE", "cleanup_unconfirmed") }
                // Failed/blocked cleanup retains capacity instead of growing replacement handles.
            } } catch (_: Exception) { state("UNAVAILABLE", "cleanup_worker_unavailable") }
        }
        private fun handle(value: BluetoothGatt, work: () -> Unit) {
            try { worker.execute {
                if (closed.get() || active !== this || gatt !== value) return@execute
                try { work() } catch (_: Exception) { close("inspection_unavailable") }
            } } catch (_: Exception) { close("callback_capacity_unavailable") }
        }
        val callback = object : BluetoothGattCallback() {
            @SuppressLint("MissingPermission")
            override fun onConnectionStateChange(value: BluetoothGatt, status: Int, newState: Int) = handle(value) {
                if (status != BluetoothGatt.GATT_SUCCESS || newState == BluetoothProfile.STATE_DISCONNECTED) close("connection_lost")
                else if (newState == BluetoothProfile.STATE_CONNECTED && discoveryRequested.compareAndSet(false, true) &&
                    !value.discoverServices()) close("inspection_unavailable")
            }
            @SuppressLint("MissingPermission")
            override fun onServicesDiscovered(value: BluetoothGatt, status: Int) = handle(value) {
                try {
                    if (status != BluetoothGatt.GATT_SUCCESS) { close("inspection_unavailable"); return@handle }
                    val services = catalog(value.services)
                    val name = device.name?.filterNot { it.isISOControl() }?.take(80) ?: "Unknown"
                    synchronized(this@Session) {
                        if (!closed.get() && active === this@Session) publish(mapOf("type" to "BLE_DISCOVERY_RESULT",
                            "deviceId" to device.address, "device" to mapOf("deviceName" to name,
                                "deviceAddress" to device.address, "gattConnected" to true, "services" to services,
                                "readOnly" to true, "telemetryVerified" to false), "timestamp" to System.currentTimeMillis()))
                    }
                    close("read_only_inspection_finished")
                } catch (_: Exception) { close("inspection_unavailable") }
            }
        }
    }
}
