import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';

enum PermissionStatusState {
  checking,
  granted,
  denied,
}

class PermissionNotifier extends Notifier<PermissionStatusState> {
  @override
  PermissionStatusState build() {
    // Schedule check after the first frame is rendered to avoid blocking the engine
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkPermissions();
    });
    return PermissionStatusState.checking;
  }

  Future<void> checkPermissions() async {
    if (!Platform.isAndroid) {
      state = PermissionStatusState.granted;
      return;
    }

    final hasBluetoothConnect = await Permission.bluetoothConnect.isGranted;
    final hasBluetooth = await Permission.bluetooth.isGranted;
    final hasNotification = await Permission.notification.isGranted;
    
    // On Android 12+ (SDK 31+), bluetoothConnect is required.
    // On Android < 12, bluetooth is required.
    // We can just check if either is granted, or request all relevant ones.
    // However, permission_handler handles SDK version branching internally for .isGranted.
    // But to be safe, if we haven't asked yet, it might return denied.
    
    // In our simplified flow, we will consider it granted if the primary ones are granted.
    // Actually, we should just check the status of all three. If any is denied, we show the screen.
    // Wait, if it's Android 13+, notification is required. If Android 11, bluetooth is required.
    // Let's do a robust check.
    
    bool isAllGranted = true;

    // Check Notifications (Required for FGS on Android 13+)
    if (await Permission.notification.isDenied || await Permission.notification.isPermanentlyDenied) {
       isAllGranted = false;
    }

    // Check Bluetooth Connect (Required on Android 12+)
    if (await Permission.bluetoothConnect.isDenied || await Permission.bluetoothConnect.isPermanentlyDenied) {
      // Check legacy Bluetooth (Required on Android < 12)
      if (await Permission.bluetooth.isDenied || await Permission.bluetooth.isPermanentlyDenied) {
         isAllGranted = false;
      }
    }

    if (isAllGranted) {
      state = PermissionStatusState.granted;
    } else {
      state = PermissionStatusState.denied;
    }
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    
    await [
      Permission.bluetoothConnect,
      Permission.bluetooth,
      Permission.notification,
    ].request();

    await checkPermissions();
    return state == PermissionStatusState.granted;
  }
}

final permissionProvider = NotifierProvider<PermissionNotifier, PermissionStatusState>(() {
  return PermissionNotifier();
});
