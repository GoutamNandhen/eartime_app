import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/permission_provider.dart';
import '../../data/tracking_platform.dart';
import '../settings/privacy_screen.dart';

class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(permissionProvider);
    final status = startup.status;
    final notifier = ref.read(permissionProvider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.bluetooth_audio,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  status == PermissionStatusState.error
                      ? 'Tracking setup unavailable'
                      : 'Tracking permission',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bluetooth access lets EarTime observe connected audio devices. A connection alone does not prove that a device is playing audio.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Notification permission is optional for alerts. It does not block tracking setup. Android may still display the required foreground-service status.',
              ),
              const SizedBox(height: 24),
              Text(
                'Startup: ${startup.stage.name} (attempt ${startup.generation})',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (status == PermissionStatusState.checking)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Checking tracking permission',
                  ),
                )
              else ...[
                if (status == PermissionStatusState.error)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        startup.message ?? 'Retry tracking setup.',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                if (status == PermissionStatusState.denied)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Bluetooth access is unavailable. Device observations may be missing; existing local history is retained.',
                    ),
                  ),
                FilledButton(
                  onPressed: () async {
                    if (status == PermissionStatusState.error) {
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
                    status == PermissionStatusState.error
                        ? 'Retry'
                        : 'Grant tracking permission',
                  ),
                ),
                if (status == PermissionStatusState.denied)
                  TextButton(
                    onPressed: () async {
                      try {
                        await openAppSettings().timeout(
                          const Duration(seconds: 5),
                        );
                      } catch (error) {
                        notifier.recordPlatformError(startup.generation, error);
                      }
                    },
                    child: const Text('Open Settings'),
                  ),
              ],
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy and permissions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
