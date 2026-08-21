import 'package:freezed_annotation/freezed_annotation.dart';

part 'listening_session.freezed.dart';

@freezed
sealed class PlaybackInterval with _$PlaybackInterval {
  const PlaybackInterval._();

  const factory PlaybackInterval({
    required DateTime startTime,
    DateTime? endTime,
  }) = _PlaybackInterval;

  Duration get activeDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  Duration get staticDuration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return Duration.zero;
  }
  
  Duration activeDurationToday(DateTime startOfDay) {
    var effectiveStart = startTime;
    if (startTime.isBefore(startOfDay)) {
      effectiveStart = startOfDay;
    }
    final end = endTime ?? DateTime.now();
    if (end.isBefore(effectiveStart)) return Duration.zero;
    return end.difference(effectiveStart);
  }
}

@freezed
sealed class ListeningSession with _$ListeningSession {
  const ListeningSession._();

  const factory ListeningSession({
    required String id,
    required String canonicalDeviceId,
    required String deviceName,
    required DateTime connectTime,
    DateTime? disconnectTime,
    required List<PlaybackInterval> intervals,
    @Default(false) bool isPlaying,
    @Default(false) bool isDisconnected,
  }) = _ListeningSession;

  Duration get totalActiveDuration {
    return intervals.fold(
      Duration.zero,
      (total, interval) => total + interval.activeDuration,
    );
  }

  Duration get staticTotalActiveDuration {
    return intervals.fold(
      Duration.zero,
      (total, interval) => total + interval.staticDuration,
    );
  }

  DateTime? get currentPlaybackStartTime {
    if (isPlaying && intervals.isNotEmpty && intervals.last.endTime == null) {
      return intervals.last.startTime;
    }
    return null;
  }

  Duration get todayActiveDuration {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return intervals.fold(
      Duration.zero,
      (total, interval) => total + interval.activeDurationToday(startOfDay),
    );
  }
}
