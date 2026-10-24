import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tracking_platform.dart';
import '../../providers/data_providers.dart';
import '../../providers/permission_provider.dart';

/// Presentation-only health: transport failures never rewrite playback history.
class TrackingHealthNotice extends ConsumerWidget {
  const TrackingHealthNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health =
        ref.watch(trackingStreamHealthProvider).asData?.value ??
        TrackingPlatform.currentStreamHealth;
    final startup = ref.watch(permissionProvider);
    final message = switch (health.status) {
      TrackingStreamStatus.error =>
        'Tracking updates unavailable. Live status may be stale. ${health.message ?? ''}',
      TrackingStreamStatus.closed =>
        'Tracking updates stopped. Live status may be stale. Reopen EarTime to reconnect.',
      TrackingStreamStatus.connecting => 'Waiting for tracking updates.',
      TrackingStreamStatus.inactive => 'Tracking stream is inactive.',
      TrackingStreamStatus.healthy => null,
    };
    final notificationMessage = switch (startup.notifications) {
      NotificationCapability.denied =>
        'Notifications are off; tracking setup is ready.',
      NotificationCapability.unavailable =>
        'Notification status is unavailable; tracking setup is ready.',
      _ => null,
    };
    if (message == null && notificationMessage == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        [?message, ?notificationMessage].join('\n'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
