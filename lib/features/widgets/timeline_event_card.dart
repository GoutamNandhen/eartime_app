import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/eartime_event.dart';

class TimelineEventCard extends StatelessWidget {
  final EarTimeEvent event;
  final String deviceName;

  const TimelineEventCard({
    super.key,
    required this.event,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Formatting the timestamp to HH:MM format for display
    final timeStr = "${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}";

    IconData eventIcon;
    String eventTitle;
    Color iconColor;

    if (event.eventType == 'DEVICE_CONNECTED') {
      eventIcon = Icons.headset_rounded;
      eventTitle = 'Device Connected';
      iconColor = AppColors.secondary;
    } else if (event.eventType == 'DEVICE_DISCONNECTED') {
      eventIcon = Icons.headset_off_rounded;
      eventTitle = 'Device Disconnected';
      iconColor = AppColors.onSurfaceVariant;
    } else if (event.eventType == 'PLAYBACK_STARTED' || event.eventType == 'PLAYBACK_RESUMED') {
      eventIcon = Icons.play_arrow_rounded;
      eventTitle = 'Playback Started';
      iconColor = AppColors.primary;
    } else if (event.eventType == 'PLAYBACK_PAUSED' || event.eventType == 'PLAYBACK_STOPPED') {
      eventIcon = Icons.pause_rounded;
      eventTitle = 'Playback Paused';
      iconColor = AppColors.editorialWhite;
    } else {
      eventIcon = Icons.event_note_rounded;
      eventTitle = 'Event';
      iconColor = AppColors.editorialWhite;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: (isDark ? AppColors.glassBorder : AppColors.glassBorderLight).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              eventIcon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.editorialWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deviceName.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            timeStr,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
