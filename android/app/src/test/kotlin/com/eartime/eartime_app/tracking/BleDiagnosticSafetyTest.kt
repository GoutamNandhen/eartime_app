package com.eartime.eartime_app.tracking

import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowBluetoothGatt
import java.util.UUID
import java.util.concurrent.Executor
import java.util.concurrent.Semaphore

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class BleDiagnosticSafetyTest {
    private val address = "02:11:22:33:44:55"
    private class Fixture {
        var now = 1000L
        val consent = BleDiagnosticConsent { now }
        val device = BluetoothAdapter.getDefaultAdapter().getRemoteDevice("02:11:22:33:44:55")
        val gatt = ShadowBluetoothGatt.newInstance(device)
        val jobs = ArrayDeque<Runnable>()
        val cleanup = ArrayDeque<Runnable>()
        val capacity = Semaphore(1)
        val events = mutableListOf<Map<String, Any?>>()
        lateinit var callback: BluetoothGattCallback
        lateinit var timeout: Runnable
        var connects = 0
        var cancels = 0
        var reject = false
        var rejectCleanup = false
        var duringConnect: () -> Unit = {}
        val manager = BleDiscoveryManager(consent, { _, cb ->
            connects++; callback = cb; shadowOf(gatt).setGattCallback(cb); duringConnect(); gatt
        }, Executor { if (reject) error("synthetic worker refusal") else jobs.add(it) },
            Executor { if (rejectCleanup) error("synthetic cleanup refusal") else cleanup.add(it) }, capacity,
            { timeout = it; AutoCloseable { cancels++ } }, events::add)
        fun begin() { consent.grant(device.address); manager.discover(device, true); drain() }
        fun drain() { while (jobs.isNotEmpty()) jobs.removeFirst().run() }
        fun clean() { while (cleanup.isNotEmpty()) cleanup.removeFirst().run() }
    }

    @Test fun authorizationIsOneShotEndpointBoundExpiringAndNotDurable() {
        var now = 1000L
        val gate = BleDiagnosticConsent { now }
        assertFalse(gate.consume(address)); gate.grant(address)
        assertTrue(gate.consume(address.lowercase())); assertFalse(gate.consume(address))
        gate.grant(address); now = 16001; assertFalse(gate.consume(address))
        gate.grant(address); now = 15000; assertFalse(gate.consume(address))
        gate.grant(address); assertFalse(gate.consume("00:11:22:33:44:55")); assertFalse(gate.consume(address))
        gate.grant(address); gate.revoke(); assertFalse(gate.consume(address))
        assertThrows(IllegalArgumentException::class.java) { gate.grant("02:00:00:00:00:00") }
    }
    @Test fun ordinaryCollectorCallsAndUnconfirmedForcedCallsNeverConnect() {
        val f = Fixture()
        repeat(500) { f.manager.discover(f.device) }
        f.manager.discover(f.device, true); f.drain()
        assertEquals(0, f.connects); assertEquals(1, f.capacity.availablePermits())
        assertTrue(f.events.any { it["reason"] == "explicit_authorization_required" })
    }
    @Test fun authorizedConnectionIsOffCallerAndCannotBeReused() {
        val f = Fixture(); f.consent.grant(address); f.manager.discover(f.device); f.manager.discover(f.device, true)
        assertEquals(0, f.connects); f.drain(); assertEquals(1, f.connects)
        f.manager.discover(f.device, true); f.drain(); assertEquals(1, f.connects)
        f.manager.disconnect(); f.clean()
        assertTrue(shadowOf(f.gatt).isClosed); assertEquals(1, f.capacity.availablePermits())
    }
    @Test fun deadlineBeforeConnectionRunsDoesNotStartHardwareAndReleasesCapacity() {
        val f = Fixture(); f.consent.grant(address); f.manager.discover(f.device, true)
        f.timeout.run(); f.drain(); f.clean()
        assertEquals(0, f.connects); assertEquals(1, f.capacity.availablePermits()); assertEquals(1, f.cancels)
    }
    @Test fun deadlineDuringConnectionClosesLateHandleWithoutPublishingCatalog() {
        val f = Fixture(); f.duringConnect = { f.timeout.run() }; f.begin(); f.clean()
        assertTrue(shadowOf(f.gatt).isClosed); assertEquals(1, f.capacity.availablePermits())
        f.callback.onServicesDiscovered(f.gatt, BluetoothGatt.GATT_SUCCESS); f.drain()
        assertFalse(f.events.any { it["type"] == "BLE_DISCOVERY_RESULT" })
    }
    @Test fun catalogOnlyInspectionNeverReadsValuesSubscribesOrWritesAndCloses() {
        val f = Fixture()
        val service = BluetoothGattService(UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb"), BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(BluetoothGattCharacteristic(UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb"),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY, 0))
        shadowOf(f.gatt).addDiscoverableService(service)
        f.begin(); shadowOf(f.gatt).notifyConnection(address)
        f.drain(); f.callback.onServicesDiscovered(f.gatt, BluetoothGatt.GATT_SUCCESS); f.drain(); f.clean()
        val result = f.events.single { it["type"] == "BLE_DISCOVERY_RESULT" }["device"] as Map<*, *>
        assertEquals(true, result["readOnly"]); assertEquals(false, result["telemetryVerified"])
        assertEquals(1, (result["services"] as List<*>).size)
        assertNull(shadowOf(f.gatt).latestWrittenBytes); assertNull(shadowOf(f.gatt).latestReadBytes)
        assertTrue(shadowOf(f.gatt).isClosed)
    }
    @Test fun workerRefusalAndDuplicateCloseDoNotLeakOrDoubleReleaseCapacity() {
        val f = Fixture(); f.reject = true; f.consent.grant(address); f.manager.discover(f.device, true)
        f.manager.disconnect(); f.timeout.run(); f.clean()
        assertEquals(0, f.connects); assertEquals(1, f.capacity.availablePermits())
    }
    @Test fun failedCleanupRetainsCapacityAndRefusesUnboundedReplacements() {
        val f = Fixture(); f.begin(); f.rejectCleanup = true; f.manager.disconnect()
        assertEquals(0, f.capacity.availablePermits())
        f.consent.grant(address); f.manager.discover(f.device, true); f.drain()
        assertEquals(1, f.connects); assertTrue(f.events.any { it["reason"] == "diagnostic_capacity_unavailable" })
        f.gatt.close()
    }
    @Test fun callbackQueueRefusalClosesOnceAndCannotPublishStaleCatalog() {
        val f = Fixture(); f.begin(); f.reject = true
        repeat(500) { f.callback.onServicesDiscovered(f.gatt, BluetoothGatt.GATT_SUCCESS) }
        f.clean(); f.timeout.run(); f.clean()
        assertTrue(shadowOf(f.gatt).isClosed); assertEquals(1, f.capacity.availablePermits())
        assertFalse(f.events.any { it["type"] == "BLE_DISCOVERY_RESULT" })
    }
    @Test fun oversizeLiveCatalogClosesWithoutPublishingATruncatedResult() {
        val f = Fixture()
        repeat(33) { shadowOf(f.gatt).addDiscoverableService(BluetoothGattService(UUID.randomUUID(), BluetoothGattService.SERVICE_TYPE_PRIMARY)) }
        f.begin(); shadowOf(f.gatt).notifyConnection(address); f.drain(); f.clean()
        assertTrue(shadowOf(f.gatt).isClosed)
        assertFalse(f.events.any { it["type"] == "BLE_DISCOVERY_RESULT" })
        assertTrue(f.events.any { it["reason"] == "inspection_unavailable" })
    }
    @Test fun serviceAndCharacteristicBoundsRefusePartialCatalogs() {
        fun service() = BluetoothGattService(UUID.randomUUID(), BluetoothGattService.SERVICE_TYPE_PRIMARY)
        assertThrows(IllegalArgumentException::class.java) { BleDiscoveryManager.catalog(List(33) { service() }) }
        val crowded = service()
        repeat(65) { crowded.addCharacteristic(BluetoothGattCharacteristic(UUID.randomUUID(), BluetoothGattCharacteristic.PROPERTY_READ, 0)) }
        assertThrows(IllegalArgumentException::class.java) { BleDiscoveryManager.catalog(listOf(crowded)) }
        val total = List(5) { service().apply {
            repeat(64) { addCharacteristic(BluetoothGattCharacteristic(UUID.randomUUID(), BluetoothGattCharacteristic.PROPERTY_NOTIFY, 0)) }
        } }
        assertThrows(IllegalArgumentException::class.java) { BleDiscoveryManager.catalog(total) }
    }
}
