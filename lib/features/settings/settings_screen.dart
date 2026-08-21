import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/liquid_glass_surface.dart';
import 'audio_diagnostics_screen.dart';
import 'developer_diagnostics_screen.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Ambient Orbs
          Positioned(
            top: 50,
            left: -50,
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                Text(
                  'APPEARANCE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                LiquidGlassSurface(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _buildThemeOption(
                        context: context,
                        ref: ref,
                        title: 'System Default',
                        mode: ThemeMode.system,
                        currentMode: themeMode,
                      ),
                      const Divider(height: 1, color: AppColors.glassBorder),
                      _buildThemeOption(
                        context: context,
                        ref: ref,
                        title: 'Light Mode',
                        mode: ThemeMode.light,
                        currentMode: themeMode,
                      ),
                      const Divider(height: 1, color: AppColors.glassBorder),
                      _buildThemeOption(
                        context: context,
                        ref: ref,
                        title: 'Dark Mode',
                        mode: ThemeMode.dark,
                        currentMode: themeMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                Text(
                  'DIAGNOSTICS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                LiquidGlassSurface(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Run Device Diagnostic',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AudioDiagnosticsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppColors.glassBorder),
                      ListTile(
                        leading: const Icon(Icons.science, color: AppColors.secondary),
                        title: const Text('Developer Earbud Diagnostics', style: TextStyle(color: AppColors.editorialWhite)),
                        subtitle: const Text('Per-ear protocol capabilities and telemetry', style: TextStyle(color: AppColors.onSurfaceVariant)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const DeveloperDiagnosticsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required ThemeMode mode,
    required ThemeMode currentMode,
  }) {
    final theme = Theme.of(context);
    final isSelected = currentMode == mode;

    return ListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
    );
  }
}
