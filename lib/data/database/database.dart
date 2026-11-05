import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [EarTimeEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Stream<List<EarTimeEventEntity>> watchAllEvents() {
    return (select(earTimeEvents)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<EarTimeEventEntity>> getAllEvents() {
    return (select(earTimeEvents)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)]))
        .get();
  }

  /// Inserts an event, ignoring exact duplicates (same id). Ids are derived from
  /// timestamp + device + type, so a replayed native event is not stored twice and two
  /// different events in the same millisecond no longer collide.
  Future<int> insertEvent(EarTimeEventsCompanion event) {
    return into(earTimeEvents).insert(event, mode: InsertMode.insertOrIgnore);
  }

  Future<void> clearAllEvents() {
    return delete(earTimeEvents).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'eartime_db.sqlite'));

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
