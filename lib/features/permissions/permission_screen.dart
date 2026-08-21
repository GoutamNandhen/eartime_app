import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/permission_provider.dart';
import '../../data/tracking_platform.dart';

class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final permissionState = ref.watch(permissionProvider);
    final notifier = ref.read(permissionProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 50),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bluetooth_audio, size: 48, color: AppColors.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Permissions Required',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.editorialWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'EarTime needs access to Bluetooth to automatically detect when your earbuds connect and disconnect.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'We also need Notification permissions to keep the tracking service alive reliably in the background.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (permissionState == PermissionStatusState.checking)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  else ...[
                    if (permissionState == PermissionStatusState.denied)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Permissions were denied. EarTime cannot track audio without them.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.obsidianDeep,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if (permissionState == PermissionStatusState.denied) {
                            // First, try requesting again. If permanently denied, Android ignores it.
                            final granted = await notifier.requestPermissions();
                            if (!granted) {
                              // If still denied after request, open settings.
                              openAppSettings();
                            } else {
                               // Start tracking now that it's granted
                               TrackingPlatform.startMonitoring();
                            }
                          } else {
                            final granted = await notifier.requestPermissions();
                            if (granted) {
                               TrackingPlatform.startMonitoring();
                            }
                          }
                        },
                        child: Text(
                          permissionState == PermissionStatusState.denied ? 'Open Settings' : 'Grant Permissions',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
