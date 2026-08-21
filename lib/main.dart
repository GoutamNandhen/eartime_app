import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'features/settings/settings_screen.dart';

void main() {
  debugPrint('[GFLOW] main START');
  debugPrint('[GFLOW] runApp CALL');
  runApp(
    const ProviderScope(
      child: EarTimeApp(),
    ),
  );
  debugPrint('[GFLOW] runApp RETURN');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('[GFLOW] FIRST FLUTTER POST-FRAME CALLBACK');
  });

  int frameCount = 0;
  WidgetsBinding.instance.addPersistentFrameCallback((_) {
    if (frameCount < 5) {
      frameCount++;
      debugPrint('[GFLOW] FLUTTER FRAME $frameCount');
    }
  });
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
