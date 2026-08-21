import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.obsidianDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.obsidianDeep,
        error: AppColors.error,
        onPrimary: AppColors.obsidianDeep,
        onSecondary: AppColors.obsidianDeep,
        onSurface: AppColors.editorialWhite,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        onError: AppColors.obsidianDeep,
      ),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppColors.editorialWhite,
        displayColor: AppColors.editorialWhite,
      ),
      useMaterial3: true,
      // Liquid glass properties aren't native ThemeData concepts, 
      // they will be implemented in Custom Widgets using AppColors
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4338CA), // Indigo-700
        secondary: Color(0xFF059669), // Emerald-600
        surface: Color(0xFFF5F5F7),
        error: Color(0xFFDC2626), // Red-600
      ),
      textTheme: AppTypography.textTheme,
    );
  }
}
