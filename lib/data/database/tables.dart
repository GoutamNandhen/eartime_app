import 'package:drift/drift.dart';

@DataClassName('EarTimeEventEntity')
class EarTimeEvents extends Table {
  TextColumn get id => text()();
  TextColumn get canonicalDeviceId => text()();
  TextColumn get deviceName => text().withDefault(const Constant('Unknown Device'))();
  TextColumn get connectionType => text().withDefault(const Constant('bluetooth'))();
  TextColumn get eventType => text()(); // DEVICE_CONNECTED, DEVICE_DISCONNECTED, PLAYBACK_STARTED, PLAYBACK_PAUSED, PLAYBACK_RESUMED, PLAYBACK_STOPPED
  TextColumn get playbackState => text().nullable()();
  IntColumn get timestamp => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
