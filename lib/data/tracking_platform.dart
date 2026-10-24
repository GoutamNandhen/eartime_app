import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';
import '../core/diagnostics/startup_trace.dart';

enum TrackingStreamStatus { inactive, connecting, healthy, error, closed }

class TrackingStreamHealth {
  const TrackingStreamHealth({required this.status, this.message});
  final TrackingStreamStatus status;
  final String? message;
}

class TrackingPlatform {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.eartime.app/tracking',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.eartime.app/tracking_events',
  );

  static Future<int> getAndroidSdkVersion() async {
    final sdk = await _methodChannel.invokeMethod<int>('getAndroidSdkVersion', {
      'dart': dartRuntimeId,
    });
    if (sdk == null) throw StateError('Android SDK response was absent');
    return sdk;
  }

  static Future<void> startMonitoring() async {
    await _methodChannel.invokeMethod('startMonitoring');
  }

  static Future<void> stopMonitoring() async {
    await _methodChannel.invokeMethod('stopMonitoring');
  }

  static Future<Map<String, dynamic>> getAudioDiagnostics() async {
    final result = await _methodChannel.invokeMethod('getAudioDiagnostics');
    return Map<String, dynamic>.from(result);
  }

  static Future<void> startBleDiagnostic(
    String hardwareAddress, {
    required bool confirmed,
  }) async {
    await _methodChannel.invokeMethod('startBleDiagnostic', {
      'address': hardwareAddress,
      'confirmed': confirmed,
    });
  }

  static final String dartRuntimeId = StartupTrace.runtimeId;
  static Stream<dynamic>? _rawEventChannelStream;
  static Stream<dynamic>? _rawStreamForTesting;
  static Stream<TrackingEvent>? _sharedEventStream;
  static StreamController<TrackingEvent>? _streamController;
  static StreamSubscription<dynamic>? _nativeSubscription;
  static int _subscriptionGeneration = 0;
  static int _transportGeneration = 0;

  static TrackingStreamHealth _health = const TrackingStreamHealth(
    status: TrackingStreamStatus.inactive,
  );
  static final _healthChanges =
      StreamController<TrackingStreamHealth>.broadcast();
  static TrackingStreamHealth get currentStreamHealth => _health;

  // Health observers do not subscribe to the EventChannel.
  static final Stream<TrackingStreamHealth> healthStream =
      Stream<TrackingStreamHealth>.multi((controller) {
        controller.add(_health);
        final subscription = _healthChanges.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      }, isBroadcast: true);

  static void _setHealth(TrackingStreamStatus status, [String? message]) {
    if (_health.status == status && _health.message == message) return;
    _health = TrackingStreamHealth(status: status, message: message);
    debugPrint(
      '[STREAM_HEALTH:dart=$dartRuntimeId] status=${status.name} '
      'message=${message ?? 'none'} generation=$_subscriptionGeneration',
    );
    _healthChanges.add(_health);
  }

  static Stream<dynamic> _getRawStream() {
    return _rawStreamForTesting ??
        (_rawEventChannelStream ??= _createNativeStream());
  }

  // Same EventChannel wire protocol, but activation errors reach the stream.
  // receiveBroadcastStream reports those only through FlutterError.onError.
  static Stream<dynamic> _createNativeStream() {
    final messenger = _eventChannel.binaryMessenger;
    final method = MethodChannel(
      _eventChannel.name,
      _eventChannel.codec,
      messenger,
    );
    late final StreamController<dynamic> controller;
    var generation = 0;
    controller = StreamController<dynamic>.broadcast(
      onListen: () async {
        generation = ++_transportGeneration;
        final attachment = generation;
        messenger.setMessageHandler(_eventChannel.name, (reply) async {
          if (attachment != _transportGeneration || controller.isClosed) {
            return null;
          }
          if (reply == null) {
            unawaited(controller.close());
          } else {
            try {
              controller.add(_eventChannel.codec.decodeEnvelope(reply));
            } catch (error, stack) {
              controller.addError(error, stack);
            }
          }
          return null;
        });
        try {
          await method.invokeMethod<void>('listen');
        } catch (error, stack) {
          if (attachment == _transportGeneration && !controller.isClosed) {
            controller.addError(error, stack);
          }
        }
      },
      onCancel: () async {
        if (generation != _transportGeneration) return;
        final cancellation = ++_transportGeneration;
        messenger.setMessageHandler(_eventChannel.name, null);
        try {
          await method.invokeMethod<void>('cancel');
        } catch (error, stack) {
          if (cancellation != _transportGeneration) return;
          _setHealth(
            TrackingStreamStatus.error,
            'Native cancellation failed: $error',
          );
          debugPrintStack(stackTrace: stack, maxFrames: 8);
        }
      },
    );
    return controller.stream;
  }

  /// ONE parsed broadcast stream over ONE native subscription per Dart runtime.
  static Stream<TrackingEvent> get eventStream =>
      _sharedEventStream ??= _createSharedStream();

  static Stream<TrackingEvent> _createSharedStream() {
    late final StreamController<TrackingEvent> controller;
    controller = StreamController<TrackingEvent>.broadcast(
      onListen: () {
        final generation = ++_subscriptionGeneration;
        _setHealth(TrackingStreamStatus.connecting);
        _nativeSubscription = _getRawStream().listen(
          (dynamic raw) {
            if (generation != _subscriptionGeneration || controller.isClosed) {
              return;
            }
            try {
              final map = Map<String, dynamic>.from(raw);
              final parsed = TrackingEvent.fromJson(map);
              debugPrint(
                '[LIFECYCLE:dart=$dartRuntimeId] DART_EVENT_RECEIVED '
                'type=${parsed.type} ts=${parsed.timestamp} devId=${parsed.deviceId}',
              );
              // Avoid formatting whole GATT maps or raw payloads during startup.
              _setHealth(TrackingStreamStatus.healthy);
              controller.add(parsed);
            } catch (error, stack) {
              _setHealth(
                TrackingStreamStatus.error,
                'Event parsing failed: $error',
              );
              debugPrintStack(stackTrace: stack, maxFrames: 8);
              controller.addError(error, stack);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (generation != _subscriptionGeneration || controller.isClosed) {
              return;
            }
            _setHealth(
              TrackingStreamStatus.error,
              'Native stream failed: $error',
            );
            controller.addError(error, stack);
          },
          onDone: () {
            if (generation != _subscriptionGeneration || controller.isClosed) {
              return;
            }
            _setHealth(
              TrackingStreamStatus.closed,
              'Tracking updates stopped unexpectedly',
            );
            unawaited(controller.close());
          },
        );
      },
      onCancel: () {
        _subscriptionGeneration++;
        final subscription = _nativeSubscription;
        _nativeSubscription = null;
        if (subscription != null) unawaited(subscription.cancel());
        if (_health.status != TrackingStreamStatus.closed) {
          _setHealth(TrackingStreamStatus.inactive);
        }
      },
    );
    _streamController = controller;
    return controller.stream;
  }

  @visibleForTesting
  static void setRawStreamForTesting(Stream<dynamic>? stream) {
    resetForTesting();
    _rawStreamForTesting = stream;
  }

  @visibleForTesting
  static void resetForTesting() {
    _subscriptionGeneration++;
    final subscription = _nativeSubscription;
    _nativeSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    final controller = _streamController;
    if (controller != null) unawaited(controller.close());
    _streamController = null;
    _sharedEventStream = null;
    _rawStreamForTesting = null;
    _rawEventChannelStream = null;
    _setHealth(TrackingStreamStatus.inactive);
  }

  @visibleForTesting
  static bool get hasActiveListeners => _streamController?.hasListener ?? false;
}
