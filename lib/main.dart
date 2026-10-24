import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'features/settings/settings_screen.dart';
import 'core/diagnostics/startup_trace.dart';

void main() {
  StartupTrace.mark('DART_ENTRY');
  debugPrint('[GFLOW] main START');
  debugPrint('[GFLOW] runApp CALL');
  runApp(const ProviderScope(child: EarTimeApp()));
  debugPrint('[GFLOW] runApp RETURN');
  StartupTrace.mark('RUN_APP_RETURNED');
  StartupTrace.mark('FIRST_FRAME_WAIT_STARTED', 'kind=observationalOnly');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupTrace.mark('FIRST_FRAME_OBSERVED', 'kind=frameworkPostFrame');
    debugPrint('[GFLOW] FIRST FLUTTER POST-FRAME CALLBACK');
  });

  // Observe rasterization without awaiting it or gating runApp/permissions.
  unawaited(
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
      StartupTrace.mark('FIRST_FRAME_RASTERIZED', 'kind=frameworkRasterizer');
    }),
  );
}

class EarTimeApp extends ConsumerWidget {
  const EarTimeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('[GFLOW] EarTimeApp.build START');
    final themeMode = ref.watch(themeModeProvider);

    final widget = MaterialApp(
      title: 'EarTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AppShell(),
    );
    debugPrint('[GFLOW] EarTimeApp.build END');
    return widget;
  }
}
