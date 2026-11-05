import 'package:eartime_app/features/widgets/live_timer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

String _shown(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).data!;

void main() {
  testWidgets('LiveTimerWidget shows the base duration when not playing', (tester) async {
    await tester.pumpWidget(_host(const LiveTimerWidget(baseDuration: Duration(minutes: 75, seconds: 5))));
    expect(_shown(tester), '01:15:05');
  });

  testWidgets('LiveTimerWidget stops ticking when the playback start time is cleared', (tester) async {
    final start = DateTime.now().subtract(const Duration(seconds: 30));
    await tester.pumpWidget(_host(LiveTimerWidget(baseDuration: Duration.zero, currentPlaybackStartTime: start)));
    expect(_shown(tester), anyOf('00:00:30', '00:00:31'));

    // Pause: the base now holds the closed interval and the live start is null.
    await tester.pumpWidget(_host(const LiveTimerWidget(baseDuration: Duration(seconds: 30))));
    final paused = _shown(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_shown(tester), paused, reason: 'timer must not keep counting after pause');
    expect(paused, '00:00:30', reason: 'paused interval must not be counted twice');
  });

  testWidgets('LiveTimerWidget only counts live time from countFrom (midnight)', (tester) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 2));
    await tester.pumpWidget(_host(LiveTimerWidget(
      baseDuration: Duration.zero,
      currentPlaybackStartTime: start,
      countFrom: now.subtract(const Duration(minutes: 10)),
    )));
    expect(_shown(tester), anyOf('00:10:00', '00:10:01'));
  });
}
