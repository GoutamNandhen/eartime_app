import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../home/home_screen.dart';
import '../timeline/timeline_screen.dart';
import '../analytics/analytics_screen.dart';
import '../devices/devices_screen.dart';
import '../wellbeing/wellbeing_screen.dart';
import '../widgets/glass_navigation.dart';
import '../settings/settings_screen.dart';
import '../permissions/permission_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/permission_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AnalyticsScreen(),
    const TimelineScreen(),
    const WellbeingScreen(),
    const DevicesScreen(),
  ];

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[GFLOW] AppShell.build START');
    // Check permission state first
    final permissionState = ref.watch(permissionProvider);
    
    if (permissionState != PermissionStatusState.granted) {
      debugPrint('[GFLOW] AppShell.build END (Permission Screen)');
      return const PermissionScreen();
    }

    // Wake up tracking pipeline passively ONLY if permissions are granted
    ref.watch(trackingPipelineProvider);

    final widget = Scaffold(
      extendBody: true, // Important for floating glass nav
      appBar: AppBar(
        title: const Text('EarTime', style: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 2.0)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: _openSettings,
          )
        ],
      ),
      body: Stack(
        children: [
          // Screen Content with AnimatedSwitcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _screens[_currentIndex],
          ),
          // Floating Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassNavigation(
              currentIndex: _currentIndex,
              onIndexChanged: (index) {
                if (index == 4) {
                  _openSettings();
                  return;
                }
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
    debugPrint('[GFLOW] AppShell.build END (Main Screen)');
    return widget;
  }
}
