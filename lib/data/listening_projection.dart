import 'dart:async';
import 'package:flutter/services.dart';

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
  });
  final DateTime from;
  final DateTime until;
  final int offset;
  final int deviceOffset;

  @override
  bool operator ==(Object other) =>
      other is ListeningWindow &&
      from == other.from &&
      until == other.until &&
      offset == other.offset &&
      deviceOffset == other.deviceOffset;
  @override
  int get hashCode => Object.hash(from, until, offset, deviceOffset);
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
      closeReason = map['closeReason'] as String? {
    if (end.isBefore(start) || duration.isNegative) {
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
}

class ProjectedDevice {
  ProjectedDevice(Map<dynamic, dynamic> map)
    : id = map['id'] as String,
      name = map['name'] as String,
      connected = map['connected'] as bool,
      identityVerified = map['identityVerified'] as bool;
  final String id;
  final String name;
  final bool connected;
  final bool identityVerified;
}

class ProjectedDay {
  ProjectedDay(Map<dynamic, dynamic> map)
    : start = DateTime.fromMillisecondsSinceEpoch(map['startUtcMs'] as int),
      confirmed = Duration(milliseconds: map['confirmedMs'] as int),
      unverified = Duration(milliseconds: map['unverifiedMs'] as int);
  final DateTime start;
  final Duration confirmed;
  final Duration unverified;
}

class ProjectedHour {
  ProjectedHour(Map<dynamic, dynamic> map)
    : hour = map['hour'] as int,
      duration = Duration(milliseconds: map['durationMs'] as int);
  final int hour;
  final Duration duration;
}

class ProjectedDeviceTotal {
  ProjectedDeviceTotal(Map<dynamic, dynamic> map)
    : deviceId = map['deviceId'] as String,
      duration = Duration(milliseconds: map['durationMs'] as int);
  final String deviceId;
  final Duration duration;
}

class ListeningSnapshot {
  ListeningSnapshot.fromMap(Map<dynamic, dynamic> map)
    : sourceId = map['sourceId'] as String,
      sequence = map['sequence'] as int,
      confirmed = Duration(milliseconds: map['confirmedMs'] as int),
      unverified = Duration(milliseconds: map['unverifiedMs'] as int),
      gapCount = map['gapCount'] as int,
      lastError = map['lastError'] as String?,
      pendingCount = map['pendingCount'] as int? ?? 0,
      failedCount = map['failedCount'] as int? ?? 0,
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
      hasMoreDevices = map['hasMoreDevices'] as bool? ?? false {
    if (![1, 2].contains(map['projectionVersion']) ||
        sequence < 0 ||
        confirmed.isNegative ||
        unverified.isNegative ||
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
  final int sequence;
  final Duration confirmed;
  final Duration unverified;
  final int gapCount;
  final String? lastError;
  final int pendingCount;
  final int failedCount;
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
        window.offset < 0 ||
        window.deviceOffset < 0 ||
        window.offset > 2147483547 ||
        window.deviceOffset > 2147483547 ||
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
        snapshot.deviceOffset != window.deviceOffset) {
      throw const FormatException('Listening window does not match request');
    }
    return snapshot;
  }
}

String formatListeningDuration(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
