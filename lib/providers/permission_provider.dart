import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';

enum PermissionStatusState {
  checking,
  /// Not granted and not asked yet in this run.
  notRequested,
  granted,
  denied,
  /// The OS will no longer show the dialog; only the system settings can grant it.
  permanentlyDenied,
}

class PermissionNotifier extends Notifier<PermissionStatusState> {
  bool _requested = false;

  @override
  PermissionStatusState build() {
    // Re-check whenever the app comes back to the foreground, e.g. after the user granted the
    // permission in system settings. Without this the app stayed stuck on the permission screen.
    final lifecycle = AppLifecycleListener(onResume: checkPermissions);
    ref.onDispose(lifecycle.dispose);

    // Schedule check after the first frame is rendered to avoid blocking the engine
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkPermissions();
    });
    return PermissionStatusState.checking;
  }

  /// Tracking only needs BLUETOOTH_CONNECT (Android 12+; permission_handler reports it as
  /// granted on older releases, where the install-time BLUETOOTH permission applies).
  /// Notifications are requested but not required: on Android 13+ a denied
  /// POST_NOTIFICATIONS only hides the foreground-service notification, the service still runs.
  Future<void> checkPermissions() async {
    if (!Platform.isAndroid) {
      state = PermissionStatusState.granted;
      return;
    }

    final status = await Permission.bluetoothConnect.status;
    if (status.isGranted || status.isLimited) {
      state = PermissionStatusState.granted;
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      state = PermissionStatusState.permanentlyDenied;
    } else {
      state = _requested ? PermissionStatusState.denied : PermissionStatusState.notRequested;
    }
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    _requested = true;
    await Permission.bluetoothConnect.request();
    // Optional: lets the user see the tracking notification. Never blocks the app.
    await Permission.notification.request();

    await checkPermissions();
    return state == PermissionStatusState.granted;
  }
}

final permissionProvider = NotifierProvider<PermissionNotifier, PermissionStatusState>(PermissionNotifier.new);
