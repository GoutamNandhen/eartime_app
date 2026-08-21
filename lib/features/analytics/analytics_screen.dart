import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../widgets/data_visualization_bar.dart';
import '../widgets/editorial_metric.dart';
import '../widgets/liquid_glass_surface.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedTab = 0; // 0: Today, 1: Week, 2: Month, 3: Year

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analyticsDataAsync = ref.watch(analyticsDataProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 100, spreadRadius: 30),
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
                          'YOUR INSIGHTS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Analytics',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppColors.editorialWhite,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Time Range Selector
                        LiquidGlassSurface(
                          padding: const EdgeInsets.all(8),
                          borderRadius: 100,
                          child: Row(
                            children: [
                              _buildTabItem(0, 'TODAY'),
                              _buildTabItem(1, 'WEEK'),
                              _buildTabItem(2, 'MONTH'),
                              _buildTabItem(3, 'YEAR'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        analyticsDataAsync.when(
                          data: (analyticsData) {
                            if (analyticsData == null) {
                              return LiquidGlassSurface(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'Not enough data yet',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Calculate percentages for UI
                            // For simplicity, we fallback to 0 if total time is zero
                            double getPct(Duration duration) {
                              if (analyticsData.totalListenTime == Duration.zero) return 0;
                              return duration.inMinutes / analyticsData.totalListenTime.inMinutes;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Main Chart Area
                                LiquidGlassSurface(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'LISTENING CONSISTENCY',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      DataVisualizationBar(
                                        percentage: getPct(analyticsData.timeOfDayUsage.morning), 
                                        label: 'Morning', 
                                        valueText: '${analyticsData.timeOfDayUsage.morning.inHours}H ${analyticsData.timeOfDayUsage.morning.inMinutes % 60}M'
                                      ),
                                      const SizedBox(height: 16),
                                      DataVisualizationBar(
                                        percentage: getPct(analyticsData.timeOfDayUsage.afternoon), 
                                        label: 'Afternoon', 
                                        valueText: '${analyticsData.timeOfDayUsage.afternoon.inHours}H ${analyticsData.timeOfDayUsage.afternoon.inMinutes % 60}M'
                                      ),
                                      const SizedBox(height: 16),
                                      DataVisualizationBar(
                                        percentage: getPct(analyticsData.timeOfDayUsage.evening), 
                                        label: 'Evening', 
                                        valueText: '${analyticsData.timeOfDayUsage.evening.inHours}H ${analyticsData.timeOfDayUsage.evening.inMinutes % 60}M'
                                      ),
                                      const SizedBox(height: 16),
                                      DataVisualizationBar(
                                        percentage: getPct(analyticsData.timeOfDayUsage.night), 
                                        label: 'Night', 
                                        valueText: '${analyticsData.timeOfDayUsage.night.inHours}H ${analyticsData.timeOfDayUsage.night.inMinutes % 60}M'
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Stats Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: LiquidGlassSurface(
                                        padding: const EdgeInsets.all(24),
                                        child: EditorialMetric(label: 'Avg Session', value: analyticsData.averageSession.inMinutes.toString(), unit: 'MIN'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: LiquidGlassSurface(
                                        padding: const EdgeInsets.all(24),
                                        child: EditorialMetric(label: 'Longest', value: analyticsData.longestSession.inHours.toString(), unit: 'HRS'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Device Usage
                                if (analyticsData.deviceUsagePercentages.isNotEmpty)
                                  LiquidGlassSurface(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DEVICE USAGE',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        ...analyticsData.deviceUsagePercentages.entries.map((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 16.0),
                                            child: DataVisualizationBar(
                                              percentage: entry.value, 
                                              label: entry.key, 
                                              valueText: '${(entry.value * 100).toInt()}%', 
                                              color: AppColors.secondary
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('Loading analytics...', style: TextStyle(color: AppColors.onSurfaceVariant)),
                            ),
                          ),
                          error: (error, stackTrace) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('Error loading analytics', style: TextStyle(color: AppColors.error)),
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

  Widget _buildTabItem(int index, String title) {
    final isSelected = _selectedTab == index;
    final theme = Theme.of(context);
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.editorialWhite.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Center(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected ? AppColors.editorialWhite : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
