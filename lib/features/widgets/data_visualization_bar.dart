import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DataVisualizationBar extends StatelessWidget {
  final double percentage; // 0.0 to 1.0
  final String label;
  final String? valueText;
  final Color? color;
  final bool animate;

  const DataVisualizationBar({
    super.key,
    required this.percentage,
    required this.label,
    this.valueText,
    this.color,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = color ?? AppColors.primary;
    final clampedPercentage = percentage.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (valueText != null) ...[
              const SizedBox(width: 16),
              Text(
                valueText!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.editorialWhite,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: animate ? const Duration(milliseconds: 1000) : Duration.zero,
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * clampedPercentage,
                    height: 8,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
