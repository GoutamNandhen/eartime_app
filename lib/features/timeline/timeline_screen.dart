import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../widgets/liquid_glass_surface.dart';
import '../widgets/timeline_event_card.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentEventsAsync = ref.watch(recentEventsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: 100,
            left: -150,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(color: AppColors.secondary.withValues(alpha: 0.1), blurRadius: 100, spreadRadius: 40),
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
                          'YOUR LISTENING HISTORY',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Timeline',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppColors.editorialWhite,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                
                recentEventsAsync.when(
                  data: (events) {
                    if (events.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: LiquidGlassSurface(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No listening activity yet',
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

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = events[index];
                          
                          return TimelineEventCard(
                            event: event,
                            deviceName: event.deviceName,
                          );
                        },
                        childCount: events.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Loading timeline...', style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                  ),
                  error: (error, stackTrace) => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Error loading timeline', style: TextStyle(color: AppColors.error)),
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
