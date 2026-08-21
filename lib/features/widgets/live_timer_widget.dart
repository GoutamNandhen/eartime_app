import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/theme/app_colors.dart';

class LiveTimerWidget extends StatefulWidget {
  final Duration baseDuration;
  final DateTime? currentPlaybackStartTime;

  const LiveTimerWidget({
    super.key,
    required this.baseDuration,
    this.currentPlaybackStartTime,
  });

  @override
  State<LiveTimerWidget> createState() => _LiveTimerWidgetState();
}

class _LiveTimerWidgetState extends State<LiveTimerWidget> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (widget.currentPlaybackStartTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.currentPlaybackStartTime!);
        });
      }
    });

    if (widget.currentPlaybackStartTime != null) {
      _ticker.start();
      _elapsed = DateTime.now().difference(widget.currentPlaybackStartTime!);
    }
  }

  @override
  void didUpdateWidget(LiveTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPlaybackStartTime != oldWidget.currentPlaybackStartTime) {
      if (widget.currentPlaybackStartTime != null) {
        if (!_ticker.isTicking) {
          _ticker.start();
        }
        _elapsed = DateTime.now().difference(widget.currentPlaybackStartTime!);
      } else {
        if (_ticker.isTicking) {
          _ticker.stop();
        }
        _elapsed = Duration.zero;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalTime = widget.baseDuration + _elapsed;

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
