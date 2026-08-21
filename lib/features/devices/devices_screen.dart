import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../widgets/device_row.dart';
import '../widgets/liquid_glass_surface.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devicesAsync = ref.watch(knownDevicesProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: 200,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 120, spreadRadius: 60),
                ],
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        Text(
                          'YOUR AUDIO DEVICES',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Devices',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppColors.editorialWhite,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                
                devicesAsync.when(
                  data: (devices) {
                    if (devices.isEmpty) {
                      debugPrint('[DEVICES_SCREEN]\nreceived devices count=0');
                      debugPrint('[DEVICES_SCREEN]\ndevice names=');
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: LiquidGlassSurface(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No compatible audio device connected',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0) {
                              debugPrint('[DEVICES_SCREEN]\nreceived devices count=${devices.length}');
                              debugPrint('[DEVICES_SCREEN]\ndevice names=${devices.map((d) => d.displayName).join(", ")}');
                            }
                            final device = devices[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DeviceRow(
                                device: device,
                                durationText: '', // Omit hardcoded duration entirely
                                onTap: () {},
                              ),
                            );
                          },
                          childCount: devices.length,
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Loading devices...', style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                  ),
                  error: (error, stackTrace) => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Error loading devices', style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom nav
              ],
            ),
          ),
        ],
      ),
    );
  }
}
