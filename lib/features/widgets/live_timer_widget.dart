import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Shows [baseDuration] plus, while [currentPlaybackStartTime] is set, the time elapsed since
/// playback started. Setting the start time to null stops the timer.
class LiveTimerWidget extends StatefulWidget {
  final Duration baseDuration;
  final DateTime? currentPlaybackStartTime;

  /// When set, live time before this instant is not counted (e.g. start of today, so a session
  /// that began before midnight only contributes today's part).
  final DateTime? countFrom;

  const LiveTimerWidget({
    super.key,
    required this.baseDuration,
    this.currentPlaybackStartTime,
    this.countFrom,
  });

  @override
  State<LiveTimerWidget> createState() => _LiveTimerWidgetState();
}

class _LiveTimerWidgetState extends State<LiveTimerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(LiveTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPlaybackStartTime != oldWidget.currentPlaybackStartTime) {
      _syncTimer();
    }
  }

  /// A 1 Hz timer is enough for an hh:mm:ss display; the previous Ticker rebuilt every frame.
  void _syncTimer() {
    if (widget.currentPlaybackStartTime != null) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Duration get _liveElapsed {
    final start = widget.currentPlaybackStartTime;
    if (start == null) return Duration.zero;
    final from = widget.countFrom;
    final effectiveStart = (from != null && start.isBefore(from)) ? from : start;
    final elapsed = DateTime.now().difference(effectiveStart);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalTime = widget.baseDuration + _liveElapsed;

    final hours = totalTime.inHours.toString().padLeft(2, '0');
    final minutes = (totalTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (totalTime.inSeconds % 60).toString().padLeft(2, '0');
    final timeStr = "$hours:$minutes:$seconds";

    return Text(
      timeStr,
      style: theme.textTheme.displayLarge?.copyWith(
        color: AppColors.editorialWhite,
        shadows: [
          Shadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20),
        ],
      ),
    );
  }
}
