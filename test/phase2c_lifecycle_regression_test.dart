import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/logic/session_manager.dart';
import 'package:eartime_app/domain/models/eartime_event.dart';
import 'package:eartime_app/domain/models/playback_state.dart';
import 'package:eartime_app/features/widgets/live_timer_widget.dart';
import 'package:eartime_app/providers/data_providers.dart';

void main() {
  group('EarTime Phase 2C-A — Lifecycle Evidence & Regression Contract Tests', () {
    test(
      'Contract A: Loss of Dart live state causes B02 disagreement between DB open interval (T1) and SYNC_STATE (S)',
      () async {
        // Shared persistent Drift database (representing persistent disk storage across process/engine restarts)
        final db = AppDatabase.forTesting(NativeDatabase.memory());

        // -------------------------------------------------------------
        // 1. First lifecycle phase: Dart Pipeline #1 runs
        // -------------------------------------------------------------
        final rawController1 = StreamController<dynamic>.broadcast();
        TrackingPlatform.setRawStreamForTesting(rawController1.stream);

        final container1 = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        container1.read(trackingPipelineProvider);

        const int t0 = 1000000; // Device connected
        const int t1 = 1010000; // Playback started (+10s)

        rawController1.add({
          'type': 'DEVICE_CONNECTED',
          'deviceId': 'EARBUDS_ONEPLUS_11',
          'device': {
            'id': 'EARBUDS_ONEPLUS_11',
            'friendlyName': 'OnePlus Buds Pro',
            'connectionType': 'bluetooth',
            'nativeType': 8,
          },
          'timestamp': t0,
        });
        await pumpEventQueue();

        rawController1.add({
          'type': 'PLAYBACK_STARTED',
          'deviceId': 'EARBUDS_ONEPLUS_11',
          'device': {
            'id': 'EARBUDS_ONEPLUS_11',
            'friendlyName': 'OnePlus Buds Pro',
            'connectionType': 'bluetooth',
          },
          'timestamp': t1,
        });
        await pumpEventQueue();

        final liveState1 = container1.read(liveSessionProvider);
        expect(liveState1.activeDevice, isNotNull);
        expect(liveState1.activeDevice!.playbackState, PlaybackState.playing);
        expect(
          liveState1.activeDevice!.currentPlaybackStartTime,
          equals(DateTime.fromMillisecondsSinceEpoch(t1)),
        );

        // Verify that database has both events persisted
        final persistedRows1 = await db.watchAllEvents().first;
        expect(persistedRows1.length, equals(2));

        // -------------------------------------------------------------
        // 2. Simulate Dart Engine / Activity destruction on swipe from recents
        // -------------------------------------------------------------
        container1.dispose();
        TrackingPlatform.resetForTesting();
        await rawController1.close();

        // -------------------------------------------------------------
        // 3. App Reopened: Dart Engine #2 launches with a fresh container
        // -------------------------------------------------------------
        final rawController2 = StreamController<dynamic>.broadcast();
        TrackingPlatform.setRawStreamForTesting(rawController2.stream);

        final container2 = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        container2.read(trackingPipelineProvider);

        // Fresh Dart container starts uninitialized
        expect(container2.read(liveSessionProvider).activeDevice, isNull);

        // -------------------------------------------------------------
        // 4. Native emits SYNC_STATE at time S (60 seconds after T1)
        // -------------------------------------------------------------
        const int snapshotTimeS = 1070000; // +60s after T1
        rawController2.add({
          'type': 'SYNC_STATE',
          'isPlaying': true,
          'connectedDevices': [
            {
              'id': 'EARBUDS_ONEPLUS_11',
              'friendlyName': 'OnePlus Buds Pro',
              'connectionType': 'bluetooth',
              'nativeType': 8,
            },
          ],
          'timestamp': snapshotTimeS,
        });
        await pumpEventQueue();

        // -------------------------------------------------------------
        // 5. DEMONSTRATE CURRENT PRODUCTION BEHAVIOR BEFORE FIXING B02
        // -------------------------------------------------------------
        // A. Reconstruct sessions from persistent database history
        final dbRows = await db.watchAllEvents().first;
        final domainEvents = dbRows
            .map(
              (e) => EarTimeEvent(
                id: e.id,
                canonicalDeviceId: e.canonicalDeviceId,
                deviceName: e.deviceName,
                connectionType: e.connectionType,
                eventType: e.eventType,
                playbackState: e.playbackState,
                timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp),
              ),
            )
            .toList()
            .reversed
            .toList();

        final reconstructedSessions = SessionManager.reconstruct(domainEvents);
        expect(reconstructedSessions.length, equals(1));
        final dbSession = reconstructedSessions.first;
        expect(dbSession.isPlaying, isTrue);
        expect(dbSession.intervals.length, equals(1));

        final dbOpenInterval = dbSession.intervals.first;
        expect(
          dbOpenInterval.endTime,
          isNull,
          reason: 'Interval is currently active / open in DB',
        );
        expect(
          dbOpenInterval.startTime,
          equals(DateTime.fromMillisecondsSinceEpoch(t1)),
          reason:
              'Database history accurately records open interval beginning at T1',
        );

        // B. Fresh live state chooses snapshot time S
        final freshLiveState = container2.read(liveSessionProvider);
        expect(freshLiveState.activeDevice, isNotNull);
        expect(
          freshLiveState.activeDevice!.playbackState,
          PlaybackState.playing,
        );
        expect(
          freshLiveState.activeDevice!.currentPlaybackStartTime,
          equals(DateTime.fromMillisecondsSinceEpoch(snapshotTimeS)),
          reason:
              'Fresh live state chooses S for currentPlaybackStartTime because activeDevice was null on reopen',
        );

        // C. THE B02 CONTRADICTION CONTRACT:
        // The open interval in DB begins at T1, but LiveSessionState begins at S.
        // Elapsed duration according to DB is (S - T1) = 60 seconds.
        // Elapsed duration according to LiveSessionState is (S - S) = 0 seconds.
        final t1Date = DateTime.fromMillisecondsSinceEpoch(t1);
        final sDate = DateTime.fromMillisecondsSinceEpoch(snapshotTimeS);

        expect(dbOpenInterval.startTime, equals(t1Date));
        expect(
          freshLiveState.activeDevice!.currentPlaybackStartTime,
          equals(sDate),
        );
        expect(
          freshLiveState.activeDevice!.currentPlaybackStartTime,
          isNot(equals(dbOpenInterval.startTime)),
          reason:
              'B02 BUG EXPOSED: Live timer start time ($sDate) contradicts open DB interval start ($t1Date)',
        );

        final lostDuration = freshLiveState
            .activeDevice!
            .currentPlaybackStartTime!
            .difference(dbOpenInterval.startTime);
        expect(
          lostDuration,
          equals(const Duration(seconds: 60)),
          reason:
              'B02 BUG PROOF: Exactly 60 seconds of continuous playback was dropped on reopen',
        );

        // Cleanup
        container2.dispose();
        await db.close();
        TrackingPlatform.resetForTesting();
        await rawController2.close();
      },
    );

    testWidgets(
      'Contract B: LiveTimerWidget catches up elapsed time based on retained start timestamp without background ticks',
      (tester) async {
        // Scenario 1: App renders after 10 minutes of background playback with ZERO previous ticks
        final startTime10m = DateTime.now().subtract(
          const Duration(minutes: 10),
        );
        final baseDuration = const Duration(
          minutes: 5,
        ); // 5 minutes accumulated from prior sessions

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiveTimerWidget(
                baseDuration: baseDuration,
                currentPlaybackStartTime: startTime10m,
              ),
            ),
          ),
        );

        // 5 min (base) + 10 min (elapsed) = 15 min (00:15:00)
        // The widget instantly displays 00:15:00 upon mounting without needing any background execution!
        expect(find.text('00:15:00'), findsOneWidget);

        // Scenario 2: App was in background / killed for an additional 20 minutes (total 30 minutes elapsed).
        // When remounted, with a retained start timestamp 30 minutes in the past, it catches up immediately.
        await tester.pumpWidget(const SizedBox.shrink()); // Unmounted / killed

        final startTime30m = DateTime.now().subtract(
          const Duration(minutes: 30),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiveTimerWidget(
                baseDuration: baseDuration,
                currentPlaybackStartTime: startTime30m,
              ),
            ),
          ),
        );

        // 5 min (base) + 30 min (elapsed) = 35 min (00:35:00)
        // Catches up completely without any ticks having run while unmounted
        expect(find.text('00:35:00'), findsOneWidget);
      },
    );

    test(
      'Contract C: SessionManager closes open active interval and starts new session upon subsequent DEVICE_CONNECTED without disconnect',
      () {
        final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
        final t1 = DateTime.fromMillisecondsSinceEpoch(1010000);
        final t2 = DateTime.fromMillisecondsSinceEpoch(1050000);

        final events = [
          EarTimeEvent(
            id: 'evt_1',
            canonicalDeviceId: 'BT_DEVICE_A',
            deviceName: 'Buds A',
            connectionType: 'bluetooth',
            eventType: 'DEVICE_CONNECTED',
            timestamp: t0,
          ),
          EarTimeEvent(
            id: 'evt_2',
            canonicalDeviceId: 'BT_DEVICE_A',
            deviceName: 'Buds A',
            connectionType: 'bluetooth',
            eventType: 'PLAYBACK_STARTED',
            timestamp: t1,
          ),
          // Repeated DEVICE_CONNECTED occurs without intervening pause or disconnect
          EarTimeEvent(
            id: 'evt_3',
            canonicalDeviceId: 'BT_DEVICE_A',
            deviceName: 'Buds A',
            connectionType: 'bluetooth',
            eventType: 'DEVICE_CONNECTED',
            timestamp: t2,
          ),
        ];

        final sessions = SessionManager.reconstruct(events);

        // Document exact SessionManager production behavior:
        expect(sessions.length, equals(2));

        // Session 1: completed, marked isDisconnected=true, and its open interval closed at T2
        final firstSession = sessions[0];
        expect(firstSession.isDisconnected, isTrue);
        expect(firstSession.disconnectTime, equals(t2));
        expect(firstSession.intervals.length, equals(1));
        expect(firstSession.intervals.first.startTime, equals(t1));
        expect(
          firstSession.intervals.first.endTime,
          equals(t2),
          reason:
              'SessionManager terminates active interval at the arrival of the new DEVICE_CONNECTED',
        );
        expect(
          firstSession.staticTotalActiveDuration,
          equals(const Duration(seconds: 40)),
        );

        // Session 2: brand new session created for the device at T2 with empty intervals
        final secondSession = sessions[1];
        expect(secondSession.isDisconnected, isFalse);
        expect(secondSession.connectTime, equals(t2));
        expect(secondSession.disconnectTime, isNull);
        expect(secondSession.isPlaying, isFalse);
        expect(secondSession.intervals, isEmpty);
      },
    );
  });
}
