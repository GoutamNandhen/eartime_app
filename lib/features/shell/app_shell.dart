import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/listening_projection_provider.dart';
import '../../data/app_navigation.dart';
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
import '../../core/diagnostics/startup_trace.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  String? _lastStartupMilestoneKey;
  late final AppNavigation _navigation;

  @override
  void initState() {
    super.initState();
    _navigation = AppNavigation((index) {
      if (mounted) setState(() => _currentIndex = index);
    })..start();
  }

  @override
  void dispose() {
    _navigation.close();
    super.dispose();
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const AnalyticsScreen(),
    const TimelineScreen(),
    const WellbeingScreen(),
    const DevicesScreen(),
  ];

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[GFLOW] AppShell.build START');
    // Check permission state first
    final permissionState = ref.watch(permissionProvider);
    final startupOwner = ref.read(permissionProvider.notifier).startupOwner;
    final milestoneKey =
        '$startupOwner/${permissionState.generation}/${permissionState.status.name}';
    final newStartupStage = milestoneKey != _lastStartupMilestoneKey;
    if (newStartupStage) {
      _lastStartupMilestoneKey = milestoneKey;
      StartupTrace.mark(
        'APP_SHELL_BUILD',
        'startupOwner=$startupOwner generation=${permissionState.generation} status=${permissionState.status.name}',
      );
    }

    if (permissionState.status != PermissionStatusState.granted) {
      debugPrint('[GFLOW] AppShell.build END (Permission Screen)');
      return const PermissionScreen();
    }

    // Subscribe to committed invalidation hints only after permission is granted.
    ref.watch(trackingProjectionActivationProvider);

    final widget = Scaffold(
      appBar: AppBar(
        title: const Text(
          'EarTime',
          style: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: GlassNavigation(
        currentIndex: _currentIndex,
        onIndexChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
    debugPrint('[GFLOW] AppShell.build END (Main Screen)');
    if (newStartupStage) {
      StartupTrace.mark(
        'APP_SHELL_READY',
        'startupOwner=$startupOwner generation=${permissionState.generation} meaning=shellConstructedNotRasterized',
      );
    }
    return widget;
  }
}
