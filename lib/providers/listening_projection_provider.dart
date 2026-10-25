import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/listening_projection.dart';
import '../data/tracking_platform.dart';

final listeningProjectionClientProvider = Provider(
  (ref) => const ListeningProjectionClient(),
);

final trackingProjectionActivationProvider = Provider<void>((ref) {
  final subscription = TrackingPlatform.eventStream.listen(
    (_) {},
    onError: (Object error, StackTrace stack) {},
  );
  ref.onDispose(() => unawaited(subscription.cancel()));
});

/// Flutter holds no interval reducer or durable cursor. Events are only invalidation hints.
/// This stream owns foreground retry; framework retries must not replace its owner.
final listeningProjectionProvider = StreamProvider.autoDispose
    .family<ListeningSnapshot, ListeningWindow>((ref, window) {
      final controller = StreamController<ListeningSnapshot>();
      var disposed = false;
      var reading = false;
      var again = false;
      ProjectionCancellation? request;
      var foreground =
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      Future<void> refresh() async {
        if (disposed || !foreground) return;
        if (reading) {
          again = true;
          return;
        }
        reading = true;
        request = ProjectionCancellation();
        try {
          final snapshot = await ref
              .read(listeningProjectionClientProvider)
              .read(window, cancellation: request);
          if (!disposed) controller.add(snapshot);
        } catch (error, stack) {
          if (!disposed) controller.addError(error, stack);
        } finally {
          reading = false;
          if (again && !disposed) {
            again = false;
            unawaited(refresh());
          }
        }
      }

      final lifecycle = AppLifecycleListener(
        onStateChange: (state) {
          foreground = state == AppLifecycleState.resumed;
          if (foreground) unawaited(refresh());
        },
      );
      final subscription = TrackingPlatform.eventStream.listen(
        (_) => refresh(),
        onError: (Object error, StackTrace stack) {
          if (!disposed) controller.addError(error, stack);
        },
      );
      final timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => refresh(),
      );
      unawaited(refresh());
      ref.onDispose(() {
        disposed = true;
        request?.cancel();
        timer.cancel();
        lifecycle.dispose();
        unawaited(subscription.cancel());
        unawaited(controller.close());
      });
      return controller.stream;
    }, retry: (_, _) => null);
