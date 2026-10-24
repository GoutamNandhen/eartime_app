package com.eartime.eartime_app.tracking

import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat

/** Public read-only APIs. Broadcast extras are hints, never accepted as current stream evidence. */
internal class AndroidA2dpProfileConnector(private val context: Context, private val changed: () -> Unit) : A2dpProfileConnector {
    private val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    private var registered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { changed() }
    }
    override fun request(connected: (A2dpProfileRead) -> Unit, disconnected: () -> Unit): Boolean {
        val bluetooth = adapter ?: return false
        if (!registered) {
            ContextCompat.registerReceiver(context, receiver, IntentFilter().apply {
                addAction(BluetoothA2dp.ACTION_PLAYING_STATE_CHANGED)
                addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            }, ContextCompat.RECEIVER_EXPORTED)
            registered = true
        }
        if (!bluetooth.isEnabled) return false
        var wrapper: A2dpProfileRead? = null
        var platformProxy: BluetoothProfile? = null
        return bluetooth.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                val value = if (platformProxy === proxy && wrapper != null) wrapper!! else object : A2dpProfileRead {
                    override fun devices(): List<A2dpDeviceRead> {
                        check(profile == BluetoothProfile.A2DP && proxy is BluetoothA2dp) { "Unexpected profile proxy" }
                        val devices = proxy.connectedDevices
                        check(devices.size <= 16) { "A2DP inventory exceeds sample bound" }
                        return devices.map { device ->
                            object : A2dpDeviceRead {
                                override val address: String get() = device.address
                                override fun connected() = proxy.getConnectionState(device) == BluetoothProfile.STATE_CONNECTED
                                override fun streaming() = proxy.isA2dpPlaying(device)
                            }
                        }
                    }
                    override fun close() { bluetooth.closeProfileProxy(profile, proxy) }
                }.also { wrapper = it; platformProxy = proxy }
                connected(value)
            }
            override fun onServiceDisconnected(profile: Int) { if (profile == BluetoothProfile.A2DP) disconnected() }
        }, BluetoothProfile.A2DP)
    }
    override fun close() {
        if (registered) { registered = false; context.unregisterReceiver(receiver) }
    }
}
