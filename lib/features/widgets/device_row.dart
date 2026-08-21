import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'liquid_glass_surface.dart';
import '../../domain/models/audio_device.dart';
import '../../domain/models/connection_state.dart' as eartime;
import '../../domain/models/playback_state.dart';

class DeviceRow extends StatelessWidget {
  final AudioDevice device;
  final String durationText;
  final VoidCallback? onTap;

  const DeviceRow({
    super.key,
    required this.device,
    required this.durationText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = device.connectionState == eartime.ConnectionState.connected;

    return LiquidGlassSurface(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONNECTED DEVICE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.displayName.toUpperCase(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.editorialWhite,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (isConnected) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        _buildStateString(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isConnected ? AppColors.editorialWhite : AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  durationText.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1),
            ),
            child: const Center(
              child: Icon(
                Icons.settings_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildStateString() {
    final conn = device.connectionState == eartime.ConnectionState.connected ? 'CONNECTED' : 'DISCONNECTED';
    if (device.connectionState == eartime.ConnectionState.connected) {
      if (device.playbackState == PlaybackState.playing) return '$conn · PLAYING';
      if (device.playbackState == PlaybackState.paused) return '$conn · PAUSED';
    }
    return conn;
  }
}
