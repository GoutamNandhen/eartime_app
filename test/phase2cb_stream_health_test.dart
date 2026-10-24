import 'dart:async';

import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';
import 'package:eartime_app/providers/data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StreamController<dynamic> raw;
  late ProviderContainer container;
  late int listenCount;

  setUp(() {
    listenCount = 0;
    raw = StreamController<dynamic>.broadcast(onListen: () => listenCount++);
    TrackingPlatform.setRawStreamForTesting(raw.stream);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    TrackingPlatform.resetForTesting();
    await raw.close();
    await pumpEventQueue();
  });

  test(
    'I shared consumers and health observers establish one raw subscription',
    () async {
      final eventsA = <TrackingEvent>[];
      final eventsB = <TrackingEvent>[];
      final subA = TrackingPlatform.eventStream.listen(eventsA.add);
      final subB = TrackingPlatform.eventStream.listen(eventsB.add);
      final health = container.listen(trackingStreamHealthProvider, (_, _) {});
      raw.add({
        'type': 'SYNC_STATE',
        'connectedDevices': [],
        'isPlaying': false,
        'timestamp': 1,
      });
      await pumpEventQueue();
      expect(listenCount, 1);
      expect(eventsA.length, 1);
      expect(eventsB.length, 1);
      expect(
        container.read(trackingStreamHealthProvider).asData?.value.status,
        TrackingStreamStatus.healthy,
      );
      health.close();
      await subA.cancel();
      await subB.cancel();
    },
  );

  test(
    'J raw stream error is visible and a later valid event recovers health',
    () async {
      final errors = <Object>[];
      final sub = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object error, StackTrace stack) => errors.add(error),
      );
      raw.addError(StateError('native connection failed'));
      await pumpEventQueue();
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.error,
      );
      expect(
        TrackingPlatform.currentStreamHealth.message,
        contains('native connection failed'),
      );
      expect(errors.length, 1);
      expect(listenCount, 1);
      raw.add({'type': 'PLAYBACK_STARTED', 'timestamp': 2});
      await pumpEventQueue();
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.healthy,
      );
      await sub.cancel();
    },
  );

  test(
    'J unexpected close remains observable without another raw subscription',
    () async {
      final sub = TrackingPlatform.eventStream.listen((_) {});
      await raw.close();
      await pumpEventQueue();
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.closed,
      );
      expect(listenCount, 1);
      await sub.cancel();
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.closed,
      );
    },
  );

  test(
    'malformed envelope becomes health error and does not escape parsing',
    () async {
      final errors = <Object>[];
      final sub = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object error, StackTrace stack) => errors.add(error),
      );
      raw.add('not an event envelope');
      await pumpEventQueue();
      expect(errors.length, 1);
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.error,
      );
      await sub.cancel();
    },
  );

  test('last consumer cancellation returns health to inactive', () async {
    final subA = TrackingPlatform.eventStream.listen((_) {});
    final subB = TrackingPlatform.eventStream.listen((_) {});
    await subA.cancel();
    expect(TrackingPlatform.hasActiveListeners, isTrue);
    await subB.cancel();
    await pumpEventQueue();
    expect(TrackingPlatform.hasActiveListeners, isFalse);
    expect(
      TrackingPlatform.currentStreamHealth.status,
      TrackingStreamStatus.inactive,
    );
  });

  test(
    'native EventChannel activation failure is an observable stream error',
    () async {
      const channel = MethodChannel('com.eartime.app/tracking_events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final originalErrorHandler = FlutterError.onError;
      FlutterError.onError =
          (_) {}; // Capture the old framework-only failure path.
      var nativeListens = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'listen') {
          nativeListens++;
          throw PlatformException(
            code: 'attach_failed',
            message: 'engine unavailable',
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        FlutterError.onError = originalErrorHandler;
      });
      TrackingPlatform.setRawStreamForTesting(null);
      final errors = <Object>[];
      final sub = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object error, StackTrace stack) => errors.add(error),
      );
      await pumpEventQueue();
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.error,
      );
      expect(errors.length, 1);
      expect(nativeListens, 1);
      await sub.cancel();
      await pumpEventQueue();
    },
  );

  test(
    'native protocol shares listen, forwards envelopes, and cancels once',
    () async {
      const channel = MethodChannel('com.eartime.app/tracking_events');
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      TrackingPlatform.setRawStreamForTesting(null);
      final events = <TrackingEvent>[];
      final errors = <Object>[];
      final subA = TrackingPlatform.eventStream.listen(
        events.add,
        onError: (Object error) => errors.add(error),
      );
      final subB = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object _) {},
      );
      final health = TrackingPlatform.healthStream.listen((_) {});
      await pumpEventQueue();
      expect(methods, ['listen']);
      ServicesBinding.instance.channelBuffers.push(
        channel.name,
        codec.encodeSuccessEnvelope({
          'type': 'PLAYBACK_STARTED',
          'timestamp': 3,
        }),
        (_) {},
      );
      await pumpEventQueue();
      expect(events.single.timestamp, 3);
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.healthy,
      );
      ServicesBinding.instance.channelBuffers.push(
        channel.name,
        codec.encodeErrorEnvelope(code: 'native_error', message: 'failed'),
        (_) {},
      );
      await pumpEventQueue();
      expect(errors.single, isA<PlatformException>());
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.error,
      );
      await subA.cancel();
      await pumpEventQueue();
      expect(methods, ['listen']);
      ServicesBinding.instance.channelBuffers.push(channel.name, null, (_) {});
      await pumpEventQueue();
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.closed,
      );
      expect(methods, ['listen', 'cancel']);
      await subB.cancel();
      await health.cancel();
    },
  );

  test(
    'late activation failure cannot poison a replacement subscription',
    () async {
      const channel = MethodChannel('com.eartime.app/tracking_events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final oldActivation = Completer<dynamic>();
      var listens = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'listen' && ++listens == 1) {
          return oldActivation.future;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      TrackingPlatform.setRawStreamForTesting(null);
      final oldSub = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object _) {},
      );
      await pumpEventQueue();
      await oldSub.cancel();
      final errors = <Object>[];
      final nextSub = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object error) => errors.add(error),
      );
      await pumpEventQueue();
      oldActivation.completeError(
        PlatformException(code: 'old_attachment_failed'),
      );
      await pumpEventQueue();
      expect(errors, isEmpty);
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.connecting,
      );
      expect(listens, 2);
      await nextSub.cancel();
      await pumpEventQueue();
    },
  );
}
