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
    debugPrint('[GFLOW] permissionProvider initialization START');
    // Schedule check after the first frame is rendered to avoid blocking the engine
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
      checkPermissions();
    });
    debugPrint('[GFLOW] permissionProvider initialization END');
    return PermissionStatusState.checking;
  }

  Future<void> checkPermissions() async {
    debugPrint('[GFLOW] permission check START');
    if (!Platform.isAndroid) {
      state = PermissionStatusState.granted;
      debugPrint('[GFLOW] permission check END (Not Android)');
      return;
    }

    debugPrint('[GFLOW] native MethodChannel call START (bluetoothConnect)');
    debugPrint('[GFLOW] WAITING on bluetoothConnect');
    final hasBluetoothConnect = await Permission.bluetoothConnect.isGranted;
    debugPrint('[GFLOW] native MethodChannel call RETURN (bluetoothConnect)');

    debugPrint('[GFLOW] native MethodChannel call START (bluetooth)');
    debugPrint('[GFLOW] WAITING on bluetooth');
    final hasBluetooth = await Permission.bluetooth.isGranted;
    debugPrint('[GFLOW] native MethodChannel call RETURN (bluetooth)');

    debugPrint('[GFLOW] native MethodChannel call START (notification)');
    debugPrint('[GFLOW] WAITING on notification');
    final hasNotification = await Permission.notification.isGranted;
    debugPrint('[GFLOW] native MethodChannel call RETURN (notification)');
    
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
    debugPrint('[GFLOW] permission check END');
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
