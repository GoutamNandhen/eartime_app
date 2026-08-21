import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../widgets/editorial_metric.dart';
import '../widgets/liquid_glass_surface.dart';

class WellbeingScreen extends ConsumerWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wellbeingDataAsync = ref.watch(wellbeingDataProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: -100,
            left: 50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(color: AppColors.secondary.withValues(alpha: 0.15), blurRadius: 100, spreadRadius: 40),
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
                          'YOUR LISTENING HABITS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Wellbeing',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppColors.editorialWhite,
                          ),
                        ),
                        const SizedBox(height: 32),

                        wellbeingDataAsync.when(
                          data: (wellbeingData) {
                            if (wellbeingData == null || wellbeingData.healthScore == null) {
                              return Column(
                                children: [
                                  LiquidGlassSurface(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          const Icon(Icons.health_and_safety_rounded, color: AppColors.onSurfaceVariant, size: 48),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Health score will appear after enough listening data is collected.',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  LiquidGlassSurface(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'RECOMMENDATION',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Continue listening to generate personalized insights.',
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            color: AppColors.editorialWhite,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                // Main Score
                                LiquidGlassSurface(
                                  padding: const EdgeInsets.all(32),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        EditorialMetric(
                                          label: 'Health Score',
                                          value: wellbeingData.healthScore.toString(),
                                          valueColor: AppColors.secondary,
                                          glow: true,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Your listening pattern looks balanced.',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Insight Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: LiquidGlassSurface(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.waves_rounded, color: AppColors.primary),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Exposure Pattern',
                                              style: theme.textTheme.labelLarge?.copyWith(
                                                color: AppColors.editorialWhite,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Safe volume levels maintained.',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: LiquidGlassSurface(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.access_time_rounded, color: AppColors.secondary),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Break Pattern',
                                              style: theme.textTheme.labelLarge?.copyWith(
                                                color: AppColors.editorialWhite,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Good rest intervals detected.',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Recommendation
                                if (wellbeingData.recommendation != null)
                                  LiquidGlassSurface(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'RECOMMENDATION',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          wellbeingData.recommendation!,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            color: AppColors.editorialWhite,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('Loading wellbeing data...', style: TextStyle(color: AppColors.onSurfaceVariant)),
                            ),
                          ),
                          error: (error, stackTrace) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('Error loading wellbeing data', style: TextStyle(color: AppColors.error)),
                            ),
                          ),
                        ),
                      ],
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
