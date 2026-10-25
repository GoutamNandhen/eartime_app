import 'package:flutter/material.dart';
import 'listening_projection.dart';

enum ListeningRange { today, week, month, year, custom }

class ListeningCalendar {
  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool validCustom(DateTimeRange value, DateTime now) {
    final from = day(value.start);
    final end = day(value.end);
    final days =
        DateTime.utc(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
        1;
    return !from.isBefore(DateTime(1970)) &&
        !end.isAfter(day(now)) &&
        days >= 1 &&
        days <= 366;
  }

  static DateTimeRange? pickerInitial(DateTimeRange? value, DateTime now) =>
      value != null && validCustom(value, now) ? value : null;

  static ListeningWindow window(
    ListeningRange range,
    DateTime now, {
    DateTimeRange? custom,
    int offset = 0,
    int deviceOffset = 0,
    String? deviceId,
  }) {
    final today = day(now);
    final from = switch (range) {
      ListeningRange.today => today,
      ListeningRange.week => DateTime(
        today.year,
        today.month,
        today.day - today.weekday + 1,
      ),
      ListeningRange.month => DateTime(today.year, today.month),
      ListeningRange.year => DateTime(today.year),
      ListeningRange.custom => custom == null ? today : day(custom.start),
    };
    final last = range == ListeningRange.custom && custom != null
        ? day(custom.end)
        : today;
    final until = DateTime(last.year, last.month, last.day + 1);
    if (!until.isAfter(from) ||
        until.difference(from) > const Duration(days: 367)) {
      throw ArgumentError('Invalid calendar listening window');
    }
    return ListeningWindow(
      from,
      until,
      offset: offset,
      deviceOffset: deviceOffset,
      deviceId: deviceId,
    );
  }
}
