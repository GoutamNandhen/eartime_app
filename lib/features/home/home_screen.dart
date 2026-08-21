import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../widgets/editorial_metric.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/status_indicator.dart';
import '../widgets/live_timer_widget.dart';
import 'diagnostic_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final liveSessionState = ref.watch(liveSessionProvider);
    final activeDevice = liveSessionState.activeDevice;
    final analyticsDataAsync = ref.watch(analyticsDataProvider);
    final wellbeingDataAsync = ref.watch(wellbeingDataProvider);
    final recentEventsAsync = ref.watch(recentEventsProvider);

    return Scaffold(
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
          Positioned(
            bottom: 0,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(color: AppColors.secondary.withValues(alpha: 0.1), blurRadius: 100, spreadRadius: 50),
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
                        // Hero Timer
                        const SizedBox(height: 32),
                        Text(
                          'TOTAL LISTEN TIME',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        analyticsDataAsync.when(
                          data: (analyticsData) {
                            final totalTime = analyticsData?.totalListenTime ?? Duration.zero;
                            return LiveTimerWidget(
                              baseDuration: totalTime,
                              currentPlaybackStartTime: activeDevice?.currentPlaybackStartTime,
                            );
                          },
                          loading: () => const Text('Loading...', style: TextStyle(color: AppColors.onSurfaceVariant)),
                          error: (error, stackTrace) => const Text('Error loading data', style: TextStyle(color: AppColors.error)),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        StatusIndicator(
                          isActive: activeDevice != null, 
                          label: activeDevice != null ? 'Live Session Active' : 'No Active Session'
                        ),
                        
                        const SizedBox(height: 48),

                        // Connected Device
                        Builder(builder: (context) {
                            if (activeDevice != null) {
                              final isPlaying = activeDevice.playbackState.name == 'playing';
                              return Column(
                                children: [
                                  LiquidGlassSurface(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isPlaying ? 'NOW PLAYING' : (activeDevice.playbackState.name == 'paused' ? 'PLAYBACK PAUSED' : 'EARPHONES CONNECTED'),
                                                style: theme.textTheme.labelMedium?.copyWith(
                                                  color: AppColors.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                activeDevice.displayName,
                                                style: theme.textTheme.headlineMedium?.copyWith(
                                                  color: AppColors.editorialWhite,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Icon(isPlaying ? Icons.headset_rounded : Icons.headset_off_rounded, color: isPlaying ? AppColors.secondary : AppColors.onSurfaceVariant, size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isPlaying ? 'Playing' : (activeDevice.playbackState.name == 'paused' ? 'Paused' : 'Not playing'),
                                                    style: theme.textTheme.labelLarge?.copyWith(
                                                      color: AppColors.editorialWhite,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  LiquidGlassSurface(
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'No active audio device',
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            }
                        }),

                        // Metrics Row
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: LiquidGlassSurface(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                child: wellbeingDataAsync.when(
                                  data: (wellbeingData) {
                                    final volAvg = wellbeingData?.volumeAvgDb.toString() ?? '--';
                                    final volPeak = wellbeingData?.volumePeakDb.toString() ?? '--';
                                    final breaks = wellbeingData?.breaksCount.toString() ?? '--';
                                    
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(child: EditorialMetric(label: 'Vol Avg', value: volAvg, unit: 'dB')),
                                        Container(width: 1, height: 48, color: AppColors.glassBorder),
                                        Expanded(child: EditorialMetric(label: 'Peak', value: volPeak, unit: 'dB', valueColor: AppColors.error)),
                                        Container(width: 1, height: 48, color: AppColors.glassBorder),
                                        Expanded(child: EditorialMetric(label: 'Breaks', value: breaks)),
                                      ],
                                    );
                                  },
                                  loading: () => const Center(child: Text('Loading...', style: TextStyle(color: AppColors.onSurfaceVariant))),
                                  error: (error, stackTrace) => const Center(child: Text('Error', style: TextStyle(color: AppColors.error))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: LiquidGlassSurface(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                child: wellbeingDataAsync.when(
                                  data: (wellbeingData) {
                                    final score = wellbeingData?.healthScore?.toString() ?? '--';
                                    return EditorialMetric(
                                      label: 'Health Score',
                                      value: score,
                                      valueColor: wellbeingData?.healthScore != null ? AppColors.secondary : AppColors.onSurfaceVariant,
                                      glow: wellbeingData?.healthScore != null,
                                    );
                                  },
                                  loading: () => const EditorialMetric(label: 'Health Score', value: '--'),
                                  error: (error, stackTrace) => const EditorialMetric(label: 'Health Score', value: 'Err'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Recent Activity Header
                        Text(
                          'RECENT ACTIVITY',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                
                // Recent Activity List
                recentEventsAsync.when(
                  data: (events) {
                    if (events.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: LiquidGlassSurface(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No recent activity',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = events[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: LiquidGlassSurface(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.headset_rounded, color: AppColors.onSurfaceVariant, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.eventType.toUpperCase(),
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            color: AppColors.editorialWhite,
                                          ),
                                        ),
                                        Text(
                                          'Device: ${event.canonicalDeviceId}',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: events.length.clamp(0, 3), // Show only top 3
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Loading events...', style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                  ),
                  error: (error, stackTrace) => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Error loading events', style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom nav
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DiagnosticScreen()),
          );
        },
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.bug_report, color: AppColors.background),
      ),
    );
  }
}
