import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/tracking_platform.dart';
import '../core/diagnostics/startup_trace.dart';

enum PermissionStatusState { checking, granted, denied, error }

enum StartupStage {
  awaitingFirstFrame,
  checkingCollection,
  requestingCollection,
  ready,
  permissionRequired,
  error,
}

enum NotificationCapability { unknown, granted, denied, unavailable }

class PermissionStartupState {
  const PermissionStartupState({
    this.status = PermissionStatusState.checking,
    this.stage = StartupStage.awaitingFirstFrame,
    this.generation = 0,
    this.message,
    this.notifications = NotificationCapability.unknown,
    this.notificationMessage,
  });

  final PermissionStatusState status;
  final StartupStage stage;
  final int generation;
  final String? message;
  final NotificationCapability notifications;
  final String? notificationMessage;

  PermissionStartupState withNotifications(
    NotificationCapability capability, [
    String? diagnostic,
  ]) => PermissionStartupState(
    status: status,
    stage: stage,
    generation: generation,
    message: message,
    notifications: capability,
    notificationMessage: diagnostic,
  );
}

class StartupTimeouts {
  const StartupTimeouts({
    this.collection = const Duration(seconds: 5),
    this.request = const Duration(seconds: 60),
    this.notification = const Duration(seconds: 2),
    this.firstFrameFallback = const Duration(seconds: 1),
  });
  final Duration collection;
  final Duration request;
  final Duration notification;
  final Duration firstFrameFallback;
}

abstract interface class StartupPermissionGateway {
  Future<bool> checkCollectionPermission();
  Future<bool> requestCollectionPermission();
  Future<NotificationCapability> checkNotificationCapability();
}

class PlatformStartupPermissionGateway implements StartupPermissionGateway {
  PlatformStartupPermissionGateway() : _isAndroid = Platform.isAndroid;

  @visibleForTesting
  PlatformStartupPermissionGateway.forTesting({required bool isAndroid})
    : _isAndroid = isAndroid;

  final bool _isAndroid;

  Future<Permission> _collectionPermission() async {
    final sdk = await TrackingPlatform.getAndroidSdkVersion();
    return sdk >= 31 ? Permission.bluetoothConnect : Permission.bluetooth;
  }

  @override
  Future<bool> checkCollectionPermission() async {
    if (!_isAndroid) return true;
    final permission = await _collectionPermission();
    return permission.isGranted;
  }

  @override
  Future<bool> requestCollectionPermission() async {
    if (!_isAndroid) return true;
    final permission = await _collectionPermission();
    return (await permission.request()).isGranted;
  }

  @override
  Future<NotificationCapability> checkNotificationCapability() async {
    if (!_isAndroid) return NotificationCapability.unknown;
    return await Permission.notification.isGranted
        ? NotificationCapability.granted
        : NotificationCapability.denied;
  }
}

final startupPermissionGatewayProvider = Provider<StartupPermissionGateway>(
  (ref) => PlatformStartupPermissionGateway(),
);
final startupTimeoutsProvider = Provider<StartupTimeouts>(
  (ref) => const StartupTimeouts(),
);

class _StartupCancelled implements Exception {
  const _StartupCancelled();
}

class PermissionNotifier extends Notifier<PermissionStartupState> {
  int _generation = 0;
  Timer? _initialStart;
  final _cancelPending = <void Function()>{};
  int get currentGeneration => _generation;
  late final String startupOwner = identityHashCode(this).toRadixString(16);

  void _milestone(String stage, [String fields = '']) {
    StartupTrace.mark(
      stage,
      'startupOwner=$startupOwner generation=$_generation $fields',
    );
  }

  @override
  PermissionStartupState build() {
    final initialGeneration = _generation;
    final timeouts = ref.read(startupTimeoutsProvider);
    ref.onDispose(() {
      _milestone('STARTUP_OWNER_DISPOSED');
      _generation++;
      _initialStart?.cancel();
      _cancelOperations();
    });

    void startIfCurrent(String source) {
      if (!ref.mounted || _generation != initialGeneration) {
        _milestone(
          'STARTUP_CALLBACK_IGNORED',
          'source=$source scheduledGeneration=$initialGeneration',
        );
        return;
      }
      unawaited(checkPermissions());
    }

    // First render a usable shell. The fallback schedules async work and never
    // waits for rasterization or a platform response on the UI thread.
    _milestone('FIRST_FRAME_WAIT_STARTED', 'kind=permissionScheduler');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      _milestone('FIRST_FRAME_OBSERVED', 'kind=permissionPostFrame');
      startIfCurrent('postFrame');
    });
    _initialStart = Timer(timeouts.firstFrameFallback, () {
      _milestone('FIRST_FRAME_FALLBACK_FIRED');
      startIfCurrent('fallback');
    });
    debugPrint(
      '[STARTUP:dart=${TrackingPlatform.dartRuntimeId}] '
      'stage=awaitingFirstFrame generation=$_generation',
    );
    return PermissionStartupState(generation: _generation);
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _cancelOperations() {
    final cancellations = _cancelPending.toList();
    _cancelPending.clear();
    for (final cancel in cancellations) {
      cancel();
    }
  }

  Future<T> _bounded<T>(Future<T> source, Duration limit) {
    final result = Completer<T>();
    late final Timer timer;
    late final void Function() cancel;
    void finish() {
      timer.cancel();
      _cancelPending.remove(cancel);
    }

    cancel = () {
      finish();
      if (!result.isCompleted) result.completeError(const _StartupCancelled());
    };
    timer = Timer(limit, () {
      finish();
      if (!result.isCompleted) {
        result.completeError(
          TimeoutException('Permission operation timed out', limit),
        );
      }
    });
    _cancelPending.add(cancel);
    source.then<void>(
      (value) {
        finish();
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        finish();
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    return result.future;
  }

  Future<void> checkPermissions() async {
    await _run(request: false);
  }

  Future<bool> requestPermissions() => _run(request: true);

  void recordPlatformError(int generation, Object error) {
    if (!_isCurrent(generation)) return;
    _cancelOperations();
    state = PermissionStartupState(
      status: PermissionStatusState.error,
      stage: StartupStage.error,
      generation: generation,
      message: 'Tracking startup command failed: $error',
    );
    debugPrint(
      '[STARTUP:dart=${TrackingPlatform.dartRuntimeId}] '
      'generation=$generation stage=error error=$error',
    );
  }

  Future<bool> _run({required bool request}) async {
    final generation = ++_generation;
    _milestone('STARTUP_GENERATION_STARTED', 'request=$request');
    _initialStart?.cancel();
    _cancelOperations();
    final gateway = ref.read(startupPermissionGatewayProvider);
    final timeouts = ref.read(startupTimeoutsProvider);
    final stage = request
        ? StartupStage.requestingCollection
        : StartupStage.checkingCollection;
    state = PermissionStartupState(generation: generation, stage: stage);
    debugPrint(
      '[STARTUP:dart=${TrackingPlatform.dartRuntimeId}] '
      'generation=$generation stage=${stage.name}',
    );
    try {
      _milestone('PERMISSION_CHECK_BEGIN', 'request=$request');
      final granted = await _bounded(
        request
            ? gateway.requestCollectionPermission()
            : gateway.checkCollectionPermission(),
        request ? timeouts.request : timeouts.collection,
      );
      if (!_isCurrent(generation)) {
        _milestone('PERMISSION_RESULT_IGNORED', 'resultGeneration=$generation');
        return false;
      }
      _milestone('PERMISSION_CHECK_RESULT', 'granted=$granted');
      state = PermissionStartupState(
        status: granted
            ? PermissionStatusState.granted
            : PermissionStatusState.denied,
        stage: granted ? StartupStage.ready : StartupStage.permissionRequired,
        generation: generation,
      );
      debugPrint(
        '[STARTUP:dart=${TrackingPlatform.dartRuntimeId}] '
        'generation=$generation stage=${state.stage.name}',
      );
      if (granted) {
        unawaited(_checkNotifications(gateway, timeouts, generation));
      }
      return granted;
    } catch (error, stack) {
      if (error is _StartupCancelled || !_isCurrent(generation)) return false;
      _milestone('PERMISSION_CHECK_RESULT', 'outcome=error error=$error');
      final message = error is TimeoutException
          ? 'Tracking permission check timed out. Retry to check again.'
          : 'Tracking permission check failed: $error';
      state = PermissionStartupState(
        status: PermissionStatusState.error,
        stage: StartupStage.error,
        generation: generation,
        message: message,
      );
      debugPrint(
        '[STARTUP:dart=${TrackingPlatform.dartRuntimeId}] '
        'generation=$generation stage=error error=$error',
      );
      debugPrintStack(stackTrace: stack, maxFrames: 8);
      return false;
    }
  }

  Future<void> _checkNotifications(
    StartupPermissionGateway gateway,
    StartupTimeouts timeouts,
    int generation,
  ) async {
    try {
      final capability = await _bounded(
        gateway.checkNotificationCapability(),
        timeouts.notification,
      );
      if (!_isCurrent(generation)) return;
      state = state.withNotifications(capability);
      debugPrint(
        '[STARTUP:dart=${TrackingPlatform.dartRuntimeId}] '
        'generation=$generation notifications=${capability.name}',
      );
    } catch (error, stack) {
      if (error is _StartupCancelled || !_isCurrent(generation)) return;
      state = state.withNotifications(
        NotificationCapability.unavailable,
        'Notification check unavailable: $error',
      );
      debugPrint(
        '[STARTUP:dart=${TrackingPlatform.dartRuntimeId}] '
        'generation=$generation notifications=unavailable error=$error',
      );
      debugPrintStack(stackTrace: stack, maxFrames: 8);
    }
  }
}

final permissionProvider =
    NotifierProvider<PermissionNotifier, PermissionStartupState>(
      PermissionNotifier.new,
    );
