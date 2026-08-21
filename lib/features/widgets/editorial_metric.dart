import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class EditorialMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  final bool glow;

  const EditorialMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valColor = valueColor ?? AppColors.editorialWhite;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: valColor,
                  shadows: glow
                      ? [
                          Shadow(
                            color: valColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                          )
                        ]
                      : null,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
