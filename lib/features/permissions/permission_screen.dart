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
    final startup = ref.watch(permissionProvider);
    final permissionState = startup.status;
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
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 48.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.bluetooth_audio,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    permissionState == PermissionStatusState.error
                        ? 'Tracking setup unavailable'
                        : 'Tracking permission',
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
                    'Notification permission is optional for alerts. It does not block tracking setup.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Startup: ${startup.stage.name} (attempt ${startup.generation})',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (permissionState == PermissionStatusState.checking)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  else ...[
                    if (permissionState == PermissionStatusState.error)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          startup.message ?? 'Retry tracking setup.',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (permissionState == PermissionStatusState.denied)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Permissions were denied. EarTime cannot track audio without them.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
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
                          if (permissionState == PermissionStatusState.error) {
                            await notifier.checkPermissions();
                            return;
                          }
                          final granted = await notifier.requestPermissions();
                          if (!granted) return;
                          final generation = notifier.currentGeneration;
                          try {
                            await TrackingPlatform.startMonitoring().timeout(
                              const Duration(seconds: 5),
                            );
                          } catch (error) {
                            notifier.recordPlatformError(generation, error);
                          }
                        },
                        child: Text(
                          permissionState == PermissionStatusState.error
                              ? 'Retry'
                              : 'Grant tracking permission',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (permissionState == PermissionStatusState.denied)
                      TextButton(
                        onPressed: () async {
                          try {
                            await openAppSettings().timeout(
                              const Duration(seconds: 5),
                            );
                          } catch (error) {
                            notifier.recordPlatformError(
                              startup.generation,
                              error,
                            );
                          }
                        },
                        child: const Text('Open Settings'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
