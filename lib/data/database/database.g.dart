// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EarTimeEventsTable extends EarTimeEvents
    with TableInfo<$EarTimeEventsTable, EarTimeEventEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EarTimeEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalDeviceIdMeta = const VerificationMeta(
    'canonicalDeviceId',
  );
  @override
  late final GeneratedColumn<String> canonicalDeviceId =
      GeneratedColumn<String>(
        'canonical_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Unknown Device'),
  );
  static const VerificationMeta _connectionTypeMeta = const VerificationMeta(
    'connectionType',
  );
  @override
  late final GeneratedColumn<String> connectionType = GeneratedColumn<String>(
    'connection_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bluetooth'),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackStateMeta = const VerificationMeta(
    'playbackState',
  );
  @override
  late final GeneratedColumn<String> playbackState = GeneratedColumn<String>(
    'playback_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    canonicalDeviceId,
    deviceName,
    connectionType,
    eventType,
    playbackState,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ear_time_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EarTimeEventEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('canonical_device_id')) {
      context.handle(
        _canonicalDeviceIdMeta,
        canonicalDeviceId.isAcceptableOrUnknown(
          data['canonical_device_id']!,
          _canonicalDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalDeviceIdMeta);
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    }
    if (data.containsKey('connection_type')) {
      context.handle(
        _connectionTypeMeta,
        connectionType.isAcceptableOrUnknown(
          data['connection_type']!,
          _connectionTypeMeta,
        ),
      );
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('playback_state')) {
      context.handle(
        _playbackStateMeta,
        playbackState.isAcceptableOrUnknown(
          data['playback_state']!,
          _playbackStateMeta,
        ),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EarTimeEventEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EarTimeEventEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      canonicalDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_device_id'],
      )!,
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      )!,
      connectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_type'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      playbackState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_state'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $EarTimeEventsTable createAlias(String alias) {
    return $EarTimeEventsTable(attachedDatabase, alias);
  }
}

class EarTimeEventEntity extends DataClass
    implements Insertable<EarTimeEventEntity> {
  final String id;
  final String canonicalDeviceId;
  final String deviceName;
  final String connectionType;
  final String eventType;
  final String? playbackState;
  final int timestamp;
  const EarTimeEventEntity({
    required this.id,
    required this.canonicalDeviceId,
    required this.deviceName,
    required this.connectionType,
    required this.eventType,
    this.playbackState,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['canonical_device_id'] = Variable<String>(canonicalDeviceId);
    map['device_name'] = Variable<String>(deviceName);
    map['connection_type'] = Variable<String>(connectionType);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || playbackState != null) {
      map['playback_state'] = Variable<String>(playbackState);
    }
    map['timestamp'] = Variable<int>(timestamp);
    return map;
  }

  EarTimeEventsCompanion toCompanion(bool nullToAbsent) {
    return EarTimeEventsCompanion(
      id: Value(id),
      canonicalDeviceId: Value(canonicalDeviceId),
      deviceName: Value(deviceName),
      connectionType: Value(connectionType),
      eventType: Value(eventType),
      playbackState: playbackState == null && nullToAbsent
          ? const Value.absent()
          : Value(playbackState),
      timestamp: Value(timestamp),
    );
  }

  factory EarTimeEventEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EarTimeEventEntity(
      id: serializer.fromJson<String>(json['id']),
      canonicalDeviceId: serializer.fromJson<String>(json['canonicalDeviceId']),
      deviceName: serializer.fromJson<String>(json['deviceName']),
      connectionType: serializer.fromJson<String>(json['connectionType']),
      eventType: serializer.fromJson<String>(json['eventType']),
      playbackState: serializer.fromJson<String?>(json['playbackState']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'canonicalDeviceId': serializer.toJson<String>(canonicalDeviceId),
      'deviceName': serializer.toJson<String>(deviceName),
      'connectionType': serializer.toJson<String>(connectionType),
      'eventType': serializer.toJson<String>(eventType),
      'playbackState': serializer.toJson<String?>(playbackState),
      'timestamp': serializer.toJson<int>(timestamp),
    };
  }

  EarTimeEventEntity copyWith({
    String? id,
    String? canonicalDeviceId,
    String? deviceName,
    String? connectionType,
    String? eventType,
    Value<String?> playbackState = const Value.absent(),
    int? timestamp,
  }) => EarTimeEventEntity(
    id: id ?? this.id,
    canonicalDeviceId: canonicalDeviceId ?? this.canonicalDeviceId,
    deviceName: deviceName ?? this.deviceName,
    connectionType: connectionType ?? this.connectionType,
    eventType: eventType ?? this.eventType,
    playbackState: playbackState.present
        ? playbackState.value
        : this.playbackState,
    timestamp: timestamp ?? this.timestamp,
  );
  EarTimeEventEntity copyWithCompanion(EarTimeEventsCompanion data) {
    return EarTimeEventEntity(
      id: data.id.present ? data.id.value : this.id,
      canonicalDeviceId: data.canonicalDeviceId.present
          ? data.canonicalDeviceId.value
          : this.canonicalDeviceId,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      connectionType: data.connectionType.present
          ? data.connectionType.value
          : this.connectionType,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      playbackState: data.playbackState.present
          ? data.playbackState.value
          : this.playbackState,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EarTimeEventEntity(')
          ..write('id: $id, ')
          ..write('canonicalDeviceId: $canonicalDeviceId, ')
          ..write('deviceName: $deviceName, ')
          ..write('connectionType: $connectionType, ')
          ..write('eventType: $eventType, ')
          ..write('playbackState: $playbackState, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    canonicalDeviceId,
    deviceName,
    connectionType,
    eventType,
    playbackState,
    timestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EarTimeEventEntity &&
          other.id == this.id &&
          other.canonicalDeviceId == this.canonicalDeviceId &&
          other.deviceName == this.deviceName &&
          other.connectionType == this.connectionType &&
          other.eventType == this.eventType &&
          other.playbackState == this.playbackState &&
          other.timestamp == this.timestamp);
}

class EarTimeEventsCompanion extends UpdateCompanion<EarTimeEventEntity> {
  final Value<String> id;
  final Value<String> canonicalDeviceId;
  final Value<String> deviceName;
  final Value<String> connectionType;
  final Value<String> eventType;
  final Value<String?> playbackState;
  final Value<int> timestamp;
  final Value<int> rowid;
  const EarTimeEventsCompanion({
    this.id = const Value.absent(),
    this.canonicalDeviceId = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.connectionType = const Value.absent(),
    this.eventType = const Value.absent(),
    this.playbackState = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EarTimeEventsCompanion.insert({
    required String id,
    required String canonicalDeviceId,
    this.deviceName = const Value.absent(),
    this.connectionType = const Value.absent(),
    required String eventType,
    this.playbackState = const Value.absent(),
    required int timestamp,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       canonicalDeviceId = Value(canonicalDeviceId),
       eventType = Value(eventType),
       timestamp = Value(timestamp);
  static Insertable<EarTimeEventEntity> custom({
    Expression<String>? id,
    Expression<String>? canonicalDeviceId,
    Expression<String>? deviceName,
    Expression<String>? connectionType,
    Expression<String>? eventType,
    Expression<String>? playbackState,
    Expression<int>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (canonicalDeviceId != null) 'canonical_device_id': canonicalDeviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (connectionType != null) 'connection_type': connectionType,
      if (eventType != null) 'event_type': eventType,
      if (playbackState != null) 'playback_state': playbackState,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EarTimeEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? canonicalDeviceId,
    Value<String>? deviceName,
    Value<String>? connectionType,
    Value<String>? eventType,
    Value<String?>? playbackState,
    Value<int>? timestamp,
    Value<int>? rowid,
  }) {
    return EarTimeEventsCompanion(
      id: id ?? this.id,
      canonicalDeviceId: canonicalDeviceId ?? this.canonicalDeviceId,
      deviceName: deviceName ?? this.deviceName,
      connectionType: connectionType ?? this.connectionType,
      eventType: eventType ?? this.eventType,
      playbackState: playbackState ?? this.playbackState,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (canonicalDeviceId.present) {
      map['canonical_device_id'] = Variable<String>(canonicalDeviceId.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (connectionType.present) {
      map['connection_type'] = Variable<String>(connectionType.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (playbackState.present) {
      map['playback_state'] = Variable<String>(playbackState.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EarTimeEventsCompanion(')
          ..write('id: $id, ')
          ..write('canonicalDeviceId: $canonicalDeviceId, ')
          ..write('deviceName: $deviceName, ')
          ..write('connectionType: $connectionType, ')
          ..write('eventType: $eventType, ')
          ..write('playbackState: $playbackState, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EarTimeEventsTable earTimeEvents = $EarTimeEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [earTimeEvents];
}

typedef $$EarTimeEventsTableCreateCompanionBuilder =
    EarTimeEventsCompanion Function({
      required String id,
      required String canonicalDeviceId,
      Value<String> deviceName,
      Value<String> connectionType,
      required String eventType,
      Value<String?> playbackState,
      required int timestamp,
      Value<int> rowid,
    });
typedef $$EarTimeEventsTableUpdateCompanionBuilder =
    EarTimeEventsCompanion Function({
      Value<String> id,
      Value<String> canonicalDeviceId,
      Value<String> deviceName,
      Value<String> connectionType,
      Value<String> eventType,
      Value<String?> playbackState,
      Value<int> timestamp,
      Value<int> rowid,
    });

class $$EarTimeEventsTableFilterComposer
    extends Composer<_$AppDatabase, $EarTimeEventsTable> {
  $$EarTimeEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalDeviceId => $composableBuilder(
    column: $table.canonicalDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get connectionType => $composableBuilder(
    column: $table.connectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackState => $composableBuilder(
    column: $table.playbackState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EarTimeEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EarTimeEventsTable> {
  $$EarTimeEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalDeviceId => $composableBuilder(
    column: $table.canonicalDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get connectionType => $composableBuilder(
    column: $table.connectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackState => $composableBuilder(
    column: $table.playbackState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EarTimeEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EarTimeEventsTable> {
  $$EarTimeEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get canonicalDeviceId => $composableBuilder(
    column: $table.canonicalDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get connectionType => $composableBuilder(
    column: $table.connectionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get playbackState => $composableBuilder(
    column: $table.playbackState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$EarTimeEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EarTimeEventsTable,
          EarTimeEventEntity,
          $$EarTimeEventsTableFilterComposer,
          $$EarTimeEventsTableOrderingComposer,
          $$EarTimeEventsTableAnnotationComposer,
          $$EarTimeEventsTableCreateCompanionBuilder,
          $$EarTimeEventsTableUpdateCompanionBuilder,
          (
            EarTimeEventEntity,
            BaseReferences<
              _$AppDatabase,
              $EarTimeEventsTable,
              EarTimeEventEntity
            >,
          ),
          EarTimeEventEntity,
          PrefetchHooks Function()
        > {
  $$EarTimeEventsTableTableManager(_$AppDatabase db, $EarTimeEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EarTimeEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EarTimeEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EarTimeEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> canonicalDeviceId = const Value.absent(),
                Value<String> deviceName = const Value.absent(),
                Value<String> connectionType = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String?> playbackState = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EarTimeEventsCompanion(
                id: id,
                canonicalDeviceId: canonicalDeviceId,
                deviceName: deviceName,
                connectionType: connectionType,
                eventType: eventType,
                playbackState: playbackState,
                timestamp: timestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String canonicalDeviceId,
                Value<String> deviceName = const Value.absent(),
                Value<String> connectionType = const Value.absent(),
                required String eventType,
                Value<String?> playbackState = const Value.absent(),
                required int timestamp,
                Value<int> rowid = const Value.absent(),
              }) => EarTimeEventsCompanion.insert(
                id: id,
                canonicalDeviceId: canonicalDeviceId,
                deviceName: deviceName,
                connectionType: connectionType,
                eventType: eventType,
                playbackState: playbackState,
                timestamp: timestamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EarTimeEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EarTimeEventsTable,
      EarTimeEventEntity,
      $$EarTimeEventsTableFilterComposer,
      $$EarTimeEventsTableOrderingComposer,
      $$EarTimeEventsTableAnnotationComposer,
      $$EarTimeEventsTableCreateCompanionBuilder,
      $$EarTimeEventsTableUpdateCompanionBuilder,
      (
        EarTimeEventEntity,
        BaseReferences<_$AppDatabase, $EarTimeEventsTable, EarTimeEventEntity>,
      ),
      EarTimeEventEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EarTimeEventsTableTableManager get earTimeEvents =>
      $$EarTimeEventsTableTableManager(_db, _db.earTimeEvents);
}
