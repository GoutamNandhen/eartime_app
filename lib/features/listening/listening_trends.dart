import 'package:flutter/material.dart';
import '../../data/listening_projection.dart';

enum _TrendMode { daily, hourly }

/// Presentation only: buckets and durations come from the canonical native projection.
class ListeningTrends extends StatefulWidget {
  const ListeningTrends({super.key, required this.snapshot});
  final ListeningSnapshot snapshot;
  @override
  State<ListeningTrends> createState() => _ListeningTrendsState();
}

class _ListeningTrendsState extends State<ListeningTrends> {
  static const _pageSize = 14;
  _TrendMode _mode = _TrendMode.daily;
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final localizations = MaterialLocalizations.of(context);
    final buckets = _mode == _TrendMode.daily
        ? snapshot.days.reversed
              .map(
                (day) => (
                  label: localizations.formatFullDate(day.start),
                  confirmed: day.confirmed,
                  unverified: day.unverified,
                  starts: day.measuredSessionStarts,
                ),
              )
              .toList()
        : snapshot.hourly
              .map(
                (hour) => (
                  label: localizations.formatTimeOfDay(
                    TimeOfDay(hour: hour.hour, minute: 0),
                    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                      context,
                    ),
                  ),
                  confirmed: hour.duration,
                  unverified: null as Duration?,
                  starts: hour.measuredSessionStarts,
                ),
              )
              .toList();
    final maximum = buckets.fold<int>(
      0,
      (previous, bucket) => bucket.confirmed.inMilliseconds > previous
          ? bucket.confirmed.inMilliseconds
          : previous,
    );
    final offset = _offset.clamp(
      0,
      buckets.isEmpty ? 0 : ((buckets.length - 1) ~/ _pageSize) * _pageSize,
    );
    final end = (offset + _pageSize).clamp(0, buckets.length);
    String recorded(Duration duration) => duration == Duration.zero
        ? 'None recorded'
        : formatListeningDuration(duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Listening trends',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_TrendMode>(
          style: SegmentedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
            selectedBackgroundColor: Theme.of(context).colorScheme.primary,
          ),
          segments: const [
            ButtonSegment(
              value: _TrendMode.daily,
              icon: Icon(Icons.calendar_today_outlined),
              label: Text('Daily'),
            ),
            ButtonSegment(
              value: _TrendMode.hourly,
              icon: Icon(Icons.schedule),
              label: Text('Hourly'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selected) => setState(() {
            _mode = selected.single;
            _offset = 0;
          }),
        ),
        const SizedBox(height: 12),
        Text(
          _mode == _TrendMode.daily
              ? 'Recorded daily totals'
              : 'Recorded totals by local hour across this period',
        ),
        const Text(
          'Confirmed listening excludes unverified output and unobserved gaps.',
        ),
        if (buckets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _mode == _TrendMode.daily
                  ? 'Daily records unavailable.'
                  : 'Hourly records unavailable.',
            ),
          ),
        for (final bucket in buckets.skip(offset).take(_pageSize))
          Semantics(
            container: true,
            label: bucket.label,
            value:
                'Confirmed: ${recorded(bucket.confirmed)}${bucket.unverified == null ? '' : '. Unverified: ${recorded(bucket.unverified!)}'}${bucket.starts == null ? '' : '. Measured starts: ${bucket.starts}'}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      bucket.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('Confirmed: ${recorded(bucket.confirmed)}'),
                    if (bucket.unverified case final duration?)
                      Text('Unverified: ${recorded(duration)}'),
                    if (bucket.starts case final starts?)
                      Text('Measured starts: $starts'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: maximum == 0
                          ? 0
                          : bucket.confirmed.inMilliseconds / maximum,
                      minHeight: 8,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous trend buckets',
              icon: const Icon(Icons.chevron_left),
              onPressed: offset == 0
                  ? null
                  : () => setState(() => _offset = offset - _pageSize),
            ),
            Expanded(
              child: Text(
                '${buckets.isEmpty ? 0 : offset + 1}-$end of ${buckets.length}',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Next trend buckets',
              icon: const Icon(Icons.chevron_right),
              onPressed: end >= buckets.length
                  ? null
                  : () => setState(() => _offset = end),
            ),
          ],
        ),
      ],
    );
  }
}
