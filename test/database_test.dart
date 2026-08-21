import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/domain/models/eartime_event.dart';
import 'package:eartime_app/domain/logic/session_manager.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  EarTimeEvent createEvent(String id, String deviceId, String type, DateTime time) {
    return EarTimeEvent(
      id: id,
      canonicalDeviceId: deviceId,
      deviceName: 'Test Buds',
      connectionType: 'bluetooth',
      eventType: type,
      timestamp: time,
    );
  }

  test('SessionManager handles connected -> playing -> paused -> resumed -> disconnected', () {
    final t0 = DateTime(2026, 8, 1, 10, 0); // connected
    final t1 = DateTime(2026, 8, 1, 10, 5); // playing
    final t2 = DateTime(2026, 8, 1, 10, 20); // paused (15 min active)
    final t3 = DateTime(2026, 8, 1, 10, 30); // resumed
    final t4 = DateTime(2026, 8, 1, 10, 45); // disconnected (15 min active)

    final events = [
      createEvent('1', 'dev1', 'DEVICE_CONNECTED', t0),
      createEvent('2', 'dev1', 'PLAYBACK_STARTED', t1),
      createEvent('3', 'dev1', 'PLAYBACK_PAUSED', t2),
      createEvent('4', 'dev1', 'PLAYBACK_RESUMED', t3),
      createEvent('5', 'dev1', 'DEVICE_DISCONNECTED', t4),
    ];

    final sessions = SessionManager.reconstruct(events);
    expect(sessions.length, 1);
    
    final session = sessions.first;
    expect(session.isDisconnected, true);
    expect(session.isPlaying, false);
    expect(session.totalActiveDuration.inMinutes, 30); // 15 + 15
  });

  test('SessionManager handles multiple devices independently', () {
    final t0 = DateTime(2026, 8, 1, 10, 0);
    final t1 = DateTime(2026, 8, 1, 10, 10);
    final t2 = DateTime(2026, 8, 1, 10, 20);

    final events = [
      createEvent('1', 'dev1', 'DEVICE_CONNECTED', t0),
      createEvent('2', 'dev2', 'DEVICE_CONNECTED', t0),
      createEvent('3', 'dev1', 'PLAYBACK_STARTED', t0),
      createEvent('4', 'dev2', 'PLAYBACK_STARTED', t1),
      createEvent('5', 'dev1', 'PLAYBACK_PAUSED', t1), // dev1 active for 10 min
      createEvent('6', 'dev2', 'PLAYBACK_PAUSED', t2), // dev2 active for 10 min
    ];

    final sessions = SessionManager.reconstruct(events);
    expect(sessions.length, 2);

    final s1 = sessions.firstWhere((s) => s.canonicalDeviceId == 'dev1');
    final s2 = sessions.firstWhere((s) => s.canonicalDeviceId == 'dev2');

    expect(s1.totalActiveDuration.inMinutes, 10);
    expect(s2.totalActiveDuration.inMinutes, 10);
  });

  test('SessionManager handles midnight crossing correctly', () {
    final t0 = DateTime(2026, 8, 1, 23, 50); // playing starts
    final t1 = DateTime(2026, 8, 2, 0, 10); // playing paused

    // Provide today's start manually by tricking todayActiveDuration
    // Wait, todayActiveDuration uses DateTime.now(). We should test activeDurationToday directly.
    final events = [
      createEvent('1', 'dev1', 'DEVICE_CONNECTED', t0),
      createEvent('2', 'dev1', 'PLAYBACK_STARTED', t0),
      createEvent('3', 'dev1', 'PLAYBACK_PAUSED', t1),
    ];

    final sessions = SessionManager.reconstruct(events);
    final session = sessions.first;

    expect(session.totalActiveDuration.inMinutes, 20); // 23:50 to 00:10
    
    // Check specific interval behavior
    final interval = session.intervals.first;
    
    // Pass 'today' as Aug 2nd 00:00
    final todayStart = DateTime(2026, 8, 2, 0, 0);
    expect(interval.activeDurationToday(todayStart).inMinutes, 10); // Only 10 mins fall in "today"
  });
}
