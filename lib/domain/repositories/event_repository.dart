import '../models/eartime_event.dart';
import '../../data/database/database.dart';

abstract class EventRepository {
  Future<List<EarTimeEvent>> getAllEvents();
}

class EventRepositoryImpl implements EventRepository {
  final AppDatabase db;

  EventRepositoryImpl(this.db);

  @override
  Future<List<EarTimeEvent>> getAllEvents() async {
    final entities = await db.select(db.earTimeEvents).get();
    return entities.map((e) => EarTimeEvent(
      id: e.id,
      canonicalDeviceId: e.canonicalDeviceId,
      deviceName: e.deviceName,
      connectionType: e.connectionType,
      eventType: e.eventType,
      playbackState: e.playbackState,
      timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp),
    )).toList();
  }
}
