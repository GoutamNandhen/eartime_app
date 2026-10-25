import 'dart:async';
import 'package:flutter/services.dart';
import 'listening_report.dart';
import 'device_identity.dart';

class ProjectionCancellation {
  bool _cancelled = false;
  void Function()? _callback;
  void cancel() {
    _cancelled = true;
    _callback?.call();
  }
}

class ListeningWindow {
  const ListeningWindow(
    this.from,
    this.until, {
    this.offset = 0,
    this.deviceOffset = 0,
    this.deviceId,
    this.sessionId,
  });
  final DateTime from;
  final DateTime until;
  final int offset;
  final int deviceOffset;
  final String? deviceId;
  final String? sessionId;

  @override
  bool operator ==(Object other) =>
      other is ListeningWindow &&
      from == other.from &&
      until == other.until &&
      offset == other.offset &&
      deviceOffset == other.deviceOffset &&
      deviceId == other.deviceId &&
      sessionId == other.sessionId;
  @override
  int get hashCode =>
      Object.hash(from, until, offset, deviceOffset, deviceId, sessionId);
}

class ProjectedInterval {
  ProjectedInterval(Map<dynamic, dynamic> map)
    : id = map['id'] as String,
      deviceId = map['deviceId'] as String?,
      confirmed = map['attribution'] == 'CONFIRMED',
      start = DateTime.fromMillisecondsSinceEpoch(map['startUtcMs'] as int),
      end = DateTime.fromMillisecondsSinceEpoch(map['endUtcMs'] as int),
      duration = Duration(milliseconds: map['durationMs'] as int),
      open = map['open'] as bool,
      live = map['live'] as bool,
      closeReason = map['closeReason'] as String?,
      transition = map['transition'] as String? {
    if (end.isBefore(start) ||
        duration.isNegative ||
        duration > end.difference(start)) {
      throw const FormatException('Invalid listening interval');
    }
  }
  final String id;
  final String? deviceId;
  final bool confirmed;
  final DateTime start;
  final DateTime end;
  final Duration duration;
  final bool open;
  final bool live;
  final String? closeReason;
  final String? transition;
}

class ProjectedSession {
  ProjectedSession(Map<dynamic, dynamic> map)
    : id = map['id'] as String,
      confirmed = map['attribution'] == 'CONFIRMED',
      start = DateTime.fromMillisecondsSinceEpoch(map['startUtcMs'] as int),
      end = DateTime.fromMillisecondsSinceEpoch(map['endUtcMs'] as int),
      duration = Duration(milliseconds: map['durationMs'] as int),
      segmentCount = map['segmentCount'] as int,
      deviceCount = map['deviceCount'] as int,
      incomplete = map['incomplete'] as bool,
      clipped = map['clipped'] as bool {
    if (id.isEmpty ||
        id.length > 512 ||
        end.isBefore(start) ||
        duration.isNegative ||
        duration != end.difference(start) ||
        segmentCount < 1 ||
        deviceCount < 0 ||
        deviceCount > segmentCount ||
        !const {'CONFIRMED', 'UNVERIFIED'}.contains(map['attribution'])) {
      throw const FormatException('Invalid listening session');
    }
  }
  final String id;
  final bool confirmed;
  final DateTime start;
  final DateTime end;
  final Duration duration;
  final int segmentCount;
  final int deviceCount;
  final bool incomplete;
  final bool clipped;
}

class ProjectedSessionDetail extends ProjectedSession {
  ProjectedSessionDetail(super.map)
    : offset = map['offset'] as int,
      nextOffset = map['nextOffset'] as int,
      hasMore = map['hasMore'] as bool,
      intervals = List.unmodifiable(
        (map['intervals'] as List).map((e) => ProjectedInterval(e as Map)),
      ) {
    if (offset < 0 ||
        intervals.length > 100 ||
        nextOffset != (offset + intervals.length).clamp(0, segmentCount) ||
        hasMore != (nextOffset < segmentCount) ||
        intervals.map((e) => e.id).toSet().length != intervals.length ||
        intervals.any((e) => e.confirmed != confirmed)) {
      throw const FormatException('Invalid session detail page');
    }
  }
  final int offset;
  final int nextOffset;
  final bool hasMore;
  final List<ProjectedInterval> intervals;
}

class ProjectedDevice {
  ProjectedDevice(Map<dynamic, dynamic> map)
    : id = map['id'] as String,
      name = map['name'] as String,
      connected = map['connected'] as bool,
      identityVerified = map['identityVerified'] as bool,
      identityKind = map['identityKind'] as String? ?? 'PROVISIONAL',
      connectionState = map['connectionState'] as String?,
      lastSeen = map['lastSeenUtcMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['lastSeenUtcMs'] as int);
  final String id;
  final String name;
  final bool connected;
  final bool identityVerified;
  final String identityKind;
  final String? connectionState;
  final DateTime? lastSeen;
  bool get hasEndpointIdentity => identityKind == 'ENDPOINT_ASSOCIATED';
  String get connectionLabel => connectionState == 'UNKNOWN'
      ? 'Connection unknown'
      : connected
      ? 'Last observed connected'
      : connectionState == 'DISCONNECTED_REPORTED'
      ? 'Disconnection reported'
      : 'Connection unknown';
}

class ProjectedDay {
  ProjectedDay(Map<dynamic, dynamic> map)
    : start = DateTime.fromMillisecondsSinceEpoch(map['startUtcMs'] as int),
      confirmed = Duration(milliseconds: map['confirmedMs'] as int),
      unverified = Duration(milliseconds: map['unverifiedMs'] as int),
      measuredSessionStarts = map['measuredSessionStarts'] as int? {
    if (confirmed.isNegative || unverified.isNegative) {
      throw const FormatException('Invalid day totals');
    }
  }
  final DateTime start;
  final Duration confirmed;
  final Duration unverified;
  final int? measuredSessionStarts;
}

class ProjectedHour {
  ProjectedHour(Map<dynamic, dynamic> map)
    : hour = map['hour'] as int,
      duration = Duration(milliseconds: map['durationMs'] as int),
      measuredSessionStarts = map['measuredSessionStarts'] as int? {
    if (hour < 0 || hour > 23 || duration.isNegative) {
      throw const FormatException('Invalid hourly totals');
    }
  }
  final int hour;
  final Duration duration;
  final int? measuredSessionStarts;
}

class ProjectedDeviceTotal {
  ProjectedDeviceTotal(Map<dynamic, dynamic> map)
    : deviceId = map['deviceId'] as String,
      duration = Duration(milliseconds: map['durationMs'] as int) {
    if (duration.isNegative) {
      throw const FormatException('Invalid device total');
    }
  }
  final String deviceId;
  final Duration duration;
}

class ProjectedCollectorHealth {
  ProjectedCollectorHealth(Map<dynamic, dynamic>? map)
    : state = map?['state'] as String? ?? 'UNKNOWN',
      reason = map?['reason'] as String? ?? 'no_collector_acknowledgment',
      scope = map?['scope'] as String? ?? 'inventory_and_global_activity' {
    if (map != null &&
        (map['contractVersion'] != 1 ||
            map['liveListeningEligible'] != false ||
            scope != 'inventory_and_global_activity')) {
      throw const FormatException('Unsupported collector health contract');
    }
    if (!const {
      'NOT_STARTED',
      'STARTING',
      'HEALTHY',
      'TEMPORARILY_UNAVAILABLE',
      'PERMISSION_BLOCKED',
      'SUSPENDED',
      'STOPPED',
      'UNKNOWN',
      'CONTINUITY_LOST',
    }.contains(state)) {
      throw const FormatException('Unknown collector health state');
    }
  }
  final String state;
  final String reason;
  final String scope;
  String get label => switch (state) {
    'NOT_STARTED' => 'Collection has not started',
    'STARTING' => 'Starting audio observation',
    'HEALTHY' => 'Audio inventory and activity observation available',
    'TEMPORARILY_UNAVAILABLE' => 'Audio observation temporarily unavailable',
    'PERMISSION_BLOCKED' => 'Audio observation permission blocked',
    'SUSPENDED' => 'Audio observation suspended',
    'STOPPED' => 'Audio observation stopped',
    'CONTINUITY_LOST' => 'Audio observation continuity lost',
    _ => 'Audio observation health unknown',
  };
}

enum ListeningRecordState { empty, unverified, durationUnknown, confirmed }

class ListeningSnapshot {
  ListeningSnapshot.fromMap(Map<dynamic, dynamic> map)
    : sourceId = map['sourceId'] as String,
      measuredSessionStarts = map['measuredSessionStarts'] as int?,
      sequence = map['sequence'] as int,
      confirmed = Duration(milliseconds: map['confirmedMs'] as int),
      unverified = Duration(milliseconds: map['unverifiedMs'] as int),
      gapCount = map['gapCount'] as int,
      lastError = map['lastError'] as String?,
      pendingCount = map['pendingCount'] as int? ?? 0,
      failedCount = map['failedCount'] as int? ?? 0,
      collectorHealth = ProjectedCollectorHealth(
        map['collectorHealth'] as Map?,
      ),
      report = map['report'] == null
          ? null
          : ListeningReport.fromMap(map['report'] as Map),
      longest = Duration(milliseconds: map['longestMs'] as int? ?? 0),
      average = Duration(milliseconds: map['averageMs'] as int? ?? 0),
      listeningRuns = map['listeningRuns'] as int? ?? 0,
      intervalCount = map['intervalCount'] as int,
      nextOffset = map['nextOffset'] as int,
      hasMore = map['hasMore'] as bool,
      intervals = List.unmodifiable(
        (map['intervals'] as List).map((e) => ProjectedInterval(e as Map)),
      ),
      devices = List.unmodifiable(
        (map['devices'] as List).map((e) => ProjectedDevice(e as Map)),
      ),
      days = List.unmodifiable(
        (map['days'] as List).map((e) => ProjectedDay(e as Map)),
      ),
      hourly = List.unmodifiable(
        (map['hourly'] as List? ?? []).map((e) => ProjectedHour(e as Map)),
      ),
      perDevice = List.unmodifiable(
        (map['perDevice'] as List? ?? []).map(
          (e) => ProjectedDeviceTotal(e as Map),
        ),
      ),
      deviceCount =
          map['deviceCount'] as int? ?? (map['devices'] as List).length,
      deviceOffset = map['deviceOffset'] as int? ?? 0,
      nextDeviceOffset =
          map['nextDeviceOffset'] as int? ?? (map['devices'] as List).length,
      hasMoreDevices = map['hasMoreDevices'] as bool? ?? false,
      hasSessionContract = map['sessionContractVersion'] != null,
      sessions = List.unmodifiable(
        (map['sessions'] as List? ?? []).map((e) => ProjectedSession(e as Map)),
      ),
      sessionCount = map['sessionCount'] as int? ?? 0,
      nextSessionOffset = map['nextSessionOffset'] as int? ?? 0,
      hasMoreSessions = map['hasMoreSessions'] as bool? ?? false,
      measuredSessionCount = map['measuredSessionCount'] as int? ?? 0,
      longestSession = Duration(
        milliseconds: map['longestSessionMs'] as int? ?? 0,
      ),
      averageSession = Duration(
        milliseconds: map['averageSessionMs'] as int? ?? 0,
      ),
      sessionDetail = map['sessionDetail'] == null
          ? null
          : ProjectedSessionDetail(map['sessionDetail'] as Map) {
    if (map.containsKey('frequencyContractVersion')) {
      final count = measuredSessionStarts;
      if (map['frequencyContractVersion'] != 1 ||
          count == null ||
          count < 0 ||
          count > intervalCount ||
          !hasSessionContract ||
          count > measuredSessionCount ||
          days.any(
            (day) =>
                day.measuredSessionStarts == null ||
                day.measuredSessionStarts! < 0,
          ) ||
          hourly.length != 24 ||
          hourly.any(
            (hour) =>
                hour.measuredSessionStarts == null ||
                hour.measuredSessionStarts! < 0,
          ) ||
          days.fold<int>(0, (sum, day) => sum + day.measuredSessionStarts!) !=
              count ||
          hourly.fold<int>(
                0,
                (sum, hour) => sum + hour.measuredSessionStarts!,
              ) !=
              count) {
        throw const FormatException(
          'Inconsistent measured-start frequency contract',
        );
      }
    } else if (measuredSessionStarts != null ||
        days.any((day) => day.measuredSessionStarts != null) ||
        hourly.any((hour) => hour.measuredSessionStarts != null)) {
      throw const FormatException('Missing measured-start frequency contract');
    }
    if (map.containsKey('hourly') &&
        (hourly.length != 24 ||
            hourly.asMap().entries.any(
              (entry) => entry.key != entry.value.hour,
            ) ||
            hourly.fold<Duration>(
                  Duration.zero,
                  (sum, bucket) => sum + bucket.duration,
                ) !=
                confirmed)) {
      throw const FormatException('Inconsistent hourly bucket contract');
    }
    if (map['sessionContractVersion'] != null) {
      if (map['sessionContractVersion'] != 1) {
        throw const FormatException('Unsupported session contract');
      }
      if (map['sessions'] is! List ||
          map['sessionCount'] is! int ||
          map['nextSessionOffset'] is! int ||
          map['hasMoreSessions'] is! bool ||
          map['measuredSessionCount'] is! int ||
          map['longestSessionMs'] is! int ||
          map['averageSessionMs'] is! int ||
          measuredSessionCount < 0 ||
          measuredSessionCount > sessionCount ||
          longestSession.isNegative ||
          averageSession.isNegative ||
          averageSession > longestSession ||
          (measuredSessionCount == 0 && longestSession != Duration.zero) ||
          sessions.length > 100 ||
          sessionCount > intervalCount ||
          sessionCount < sessions.length ||
          nextSessionOffset < 0 ||
          nextSessionOffset > sessionCount ||
          hasMoreSessions != (nextSessionOffset < sessionCount) ||
          sessions.map((e) => e.id).toSet().length != sessions.length) {
        throw const FormatException('Inconsistent session page');
      }
    }
    if (![1, 2, 3, 4, 5].contains(map['projectionVersion']) ||
        sequence < 0 ||
        confirmed.isNegative ||
        unverified.isNegative ||
        gapCount < 0 ||
        pendingCount < 0 ||
        failedCount < 0 ||
        longest.isNegative ||
        average.isNegative ||
        listeningRuns < 0 ||
        intervalCount < intervals.length ||
        nextOffset < 0 ||
        nextOffset > intervalCount ||
        deviceOffset < 0 ||
        deviceCount < devices.length ||
        nextDeviceOffset < 0 ||
        nextDeviceOffset > deviceCount ||
        devices.map((device) => device.id).toSet().length != devices.length) {
      throw const FormatException(
        'Unsupported or inconsistent listening projection',
      );
    }
    if (map.containsKey('deviceOffset') &&
        (nextDeviceOffset !=
                (deviceOffset + devices.length).clamp(0, deviceCount) ||
            hasMoreDevices != (nextDeviceOffset < deviceCount))) {
      throw const FormatException('Inconsistent device page cursor');
    }
  }
  final String sourceId;
  final int? measuredSessionStarts;
  final int sequence;
  final Duration confirmed;
  final Duration unverified;
  final int gapCount;
  final String? lastError;
  final int pendingCount;
  final int failedCount;
  final ProjectedCollectorHealth collectorHealth;
  final ListeningReport? report;
  final Duration longest;
  final Duration average;
  final int listeningRuns;
  final int intervalCount;
  final int nextOffset;
  final bool hasMore;
  final List<ProjectedInterval> intervals;
  final List<ProjectedDevice> devices;
  final List<ProjectedDay> days;
  final List<ProjectedHour> hourly;
  final List<ProjectedDeviceTotal> perDevice;
  final int deviceCount;
  final int deviceOffset;
  final int nextDeviceOffset;
  final bool hasMoreDevices;
  final bool hasSessionContract;
  final List<ProjectedSession> sessions;
  final int sessionCount;
  final int nextSessionOffset;
  final bool hasMoreSessions;
  final int measuredSessionCount;
  final Duration longestSession;
  final Duration averageSession;
  final ProjectedSessionDetail? sessionDetail;

  bool get hasCollectionUncertainty =>
      gapCount > 0 || pendingCount > 0 || failedCount > 0 || lastError != null;
  ListeningRecordState get recordState => confirmed > Duration.zero
      ? ListeningRecordState.confirmed
      : unverified > Duration.zero
      ? ListeningRecordState.unverified
      : intervalCount > 0
      ? ListeningRecordState.durationUnknown
      : ListeningRecordState.empty;
}

class ListeningProjectionClient {
  const ListeningProjectionClient({
    MethodChannel channel = const MethodChannel('com.eartime.app/tracking'),
  }) : _channel = channel;
  final MethodChannel _channel;

  Future<ListeningSnapshot> read(
    ListeningWindow window, {
    ProjectionCancellation? cancellation,
  }) async {
    if (!window.until.isAfter(window.from) ||
        (window.deviceId != null &&
            !DeviceIdentityClient.validId(window.deviceId)) ||
        window.offset < 0 ||
        window.deviceOffset < 0 ||
        window.offset > 2147483547 ||
        window.deviceOffset > 2147483547 ||
        (window.sessionId != null &&
            (window.sessionId!.isEmpty || window.sessionId!.length > 512)) ||
        window.until.difference(window.from) > const Duration(days: 367)) {
      throw ArgumentError('Invalid listening window');
    }
    final response = Completer<Map<dynamic, dynamic>?>();
    final deadline = Timer(const Duration(seconds: 8), () {
      if (!response.isCompleted) {
        response.completeError(
          TimeoutException('Listening projection timed out'),
        );
      }
    });
    cancellation?._callback = () {
      deadline.cancel();
      if (!response.isCompleted) {
        response.completeError(StateError('Listening request cancelled'));
      }
    };
    if (cancellation?._cancelled == true) cancellation!._callback!();
    unawaited(
      _channel
          .invokeMapMethod<dynamic, dynamic>('readListeningProjection', {
            'fromUtcMs': window.from.millisecondsSinceEpoch,
            'untilUtcMs': window.until.millisecondsSinceEpoch,
            'offset': window.offset,
            'limit': 100,
            'deviceOffset': window.deviceOffset,
            if (window.deviceId != null) 'deviceId': window.deviceId,
            if (window.sessionId != null) 'sessionId': window.sessionId,
          })
          .then(
            (value) {
              if (!response.isCompleted) response.complete(value);
            },
            onError: (Object error, StackTrace stack) {
              if (!response.isCompleted) response.completeError(error, stack);
            },
          ),
    );
    final Map<dynamic, dynamic>? raw;
    try {
      raw = await response.future;
    } finally {
      deadline.cancel();
      cancellation?._callback = null;
    }
    if (raw == null) {
      throw const FormatException('Missing listening projection');
    }
    final snapshot = ListeningSnapshot.fromMap(raw);
    if (raw['fromUtcMs'] != window.from.millisecondsSinceEpoch ||
        raw['untilUtcMs'] != window.until.millisecondsSinceEpoch ||
        snapshot.intervals.length > 100 ||
        snapshot.devices.length > 100 ||
        snapshot.deviceOffset != window.deviceOffset ||
        raw['filterDeviceId'] != window.deviceId ||
        snapshot.sessions.any(
          (session) =>
              session.start.isBefore(window.from) ||
              session.end.isAfter(window.until),
        ) ||
        (snapshot.sessionDetail != null &&
            (snapshot.sessionDetail!.start.isBefore(window.from) ||
                snapshot.sessionDetail!.end.isAfter(window.until))) ||
        (raw['sessionContractVersion'] != null &&
            snapshot.nextSessionOffset !=
                (window.offset + snapshot.sessions.length).clamp(
                  0,
                  snapshot.sessionCount,
                )) ||
        (window.sessionId != null &&
            (snapshot.sessionDetail?.id != window.sessionId ||
                snapshot.sessionDetail?.offset != window.offset)) ||
        (window.deviceId != null &&
            (snapshot.intervals.any(
                  (item) => item.deviceId != window.deviceId,
                ) ||
                snapshot.devices.any((item) => item.id != window.deviceId) ||
                snapshot.perDevice.any(
                  (item) => item.deviceId != window.deviceId,
                ) ||
                (snapshot.sessionDetail?.intervals.any(
                      (item) => item.deviceId != window.deviceId,
                    ) ??
                    false)))) {
      throw const FormatException('Listening window does not match request');
    }
    return snapshot;
  }
}

String formatListeningDuration(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
