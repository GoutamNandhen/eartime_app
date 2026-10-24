import 'dart:convert';
import 'dart:io';
import 'package:eartime_app/data/listening_projection.dart';
import 'package:eartime_app/data/listening_report.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:eartime_app/providers/listening_projection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object> report() => {
  'version': 1,
  'scope': 'selected_window_recorded_lower_bound',
  'activeDays': 0,
  'goalMinutes': 30,
  'goalDays': 0,
  'completedCalendarDays': 0,
  'currentRecordedStreak': 0,
  'bestRecordedStreak': 0,
  'averageActiveDayMs': 0,
  'hasUncertainty': true,
  'insight':
      'Playback was observed, but its output is unverified. It is excluded from listening totals.',
  'guidance':
      'Your duration goal is a personal preference, not a safe sound-exposure limit. Unobserved time is excluded.',
};

class ReportClient extends ListeningProjectionClient {
  @override
  Future<ListeningSnapshot> read(
    ListeningWindow window, {
    ProjectionCancellation? cancellation,
  }) async {
    final map = Map<String, dynamic>.from(
      (jsonDecode(
                File(
                  'test/fixtures/listening_continuity.json',
                ).readAsStringSync(),
              )
              as Map)['projection']
          as Map,
    );
    return ListeningSnapshot.fromMap(map..['report'] = report());
  }
}

void main() {
  test(
    'reports reject future contracts and impossible streaks rather than silently displaying them',
    () {
      expect(ListeningReport.fromMap(report()).hasUncertainty, isTrue);
      expect(
        () => ListeningReport.fromMap(report()..['version'] = 2),
        throwsFormatException,
      );
      expect(
        () => ListeningReport.fromMap(report()..['currentRecordedStreak'] = 5),
        throwsFormatException,
      );
      expect(
        () => ListeningReport.fromMap(report()..['goalMinutes'] = 1441),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'Wellbeing displays native report with explicit lower-bound and exposure limitations at large text',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          listeningProjectionClientProvider.overrideWithValue(ReportClient()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: ListeningWorkspace(view: ListeningView.wellbeing),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Your recorded listening report'),
        300,
      );
      expect(find.text('Your recorded listening report'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Recorded totals are lower bounds'),
        300,
      );
      expect(
        find.textContaining('missing record is not proof of a break'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}
