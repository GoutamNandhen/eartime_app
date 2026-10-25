import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/listening_projection.dart';
import '../../providers/listening_projection_provider.dart';

String sessionTimestamp(BuildContext context, DateTime value) {
  final local = MaterialLocalizations.of(context);
  final minutes = value.timeZoneOffset.inMinutes;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.formatShortDate(value)} ${two(value.hour)}:${two(value.minute)}:${two(value.second)} UTC${minutes < 0 ? '-' : '+'}${two(minutes.abs() ~/ 60)}:${two(minutes.abs() % 60)}';
}

class ListeningSessionTile extends StatelessWidget {
  const ListeningSessionTile({super.key, required this.session, this.onTap});
  final ProjectedSession session;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
    title: Text(
      '${sessionTimestamp(context, session.start)}\n${sessionTimestamp(context, session.end)}',
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.confirmed ? 'Confirmed listening' : 'Unverified playback'),
        Text(
          'Recorded duration: ${session.duration == Duration.zero ? 'None recorded' : formatListeningDuration(session.duration)}',
        ),
        Text(
          '${session.segmentCount} segment(s), ${session.deviceCount} recorded device(s)',
        ),
        if (session.incomplete)
          const Text('Incomplete; continuity unknown after last evidence'),
        if (session.clipped) const Text('Duration within selected dates'),
      ],
    ),
  );
}

class ListeningSessionScreen extends ConsumerStatefulWidget {
  const ListeningSessionScreen({
    super.key,
    required this.window,
    required this.sessionId,
  });
  final ListeningWindow window;
  final String sessionId;
  @override
  ConsumerState<ListeningSessionScreen> createState() =>
      _ListeningSessionScreenState();
}

class _ListeningSessionScreenState
    extends ConsumerState<ListeningSessionScreen> {
  int _offset = 0;
  @override
  Widget build(BuildContext context) {
    final query = ListeningWindow(
      widget.window.from,
      widget.window.until,
      deviceId: widget.window.deviceId,
      sessionId: widget.sessionId,
      offset: _offset,
    );
    final data = ref.watch(listeningProjectionProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Session details')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Session unavailable or changed. No listening time has been estimated.',
            ),
            FilledButton.icon(
              onPressed: () {
                setState(() => _offset = 0);
                ref.invalidate(listeningProjectionProvider(query));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
        data: (snapshot) {
          final detail = snapshot.sessionDetail;
          if (detail == null) {
            return const Center(child: Text('Session details unavailable'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListeningSessionTile(session: detail),
              const Text(
                'Recorded durations are lower bounds. Unknown time is excluded. Overlapping sessions are unioned in period totals.',
              ),
              const SizedBox(height: 16),
              for (final part in detail.intervals)
                ListTile(
                  key: ValueKey('session-part-${part.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${sessionTimestamp(context, part.start)}\n${sessionTimestamp(context, part.end)}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.confirmed
                            ? 'Confirmed output'
                            : 'Unverified output',
                      ),
                      Text(
                        part.deviceId == null
                            ? 'Device unattributed'
                            : snapshot.devices
                                      .where((d) => d.id == part.deviceId)
                                      .firstOrNull
                                      ?.name ??
                                  'Recorded device',
                      ),
                      Text(
                        'Recorded duration: ${part.duration == Duration.zero ? 'None recorded' : formatListeningDuration(part.duration)}',
                      ),
                      Text(switch (part.transition) {
                        'PAUSED' => 'Pause observed',
                        'DISCONNECTED' => 'Disconnection observed',
                        'OUTPUT_CHANGED' => 'Output no longer external',
                        'LAST_OBSERVED' =>
                          'Last observed playback; current continuity unknown',
                        'CONTINUITY_LOST' =>
                          'Continuity lost; ended at last evidence',
                        _ => 'Playback stop observed',
                      }),
                      if (part.closeReason != null &&
                          part.closeReason != 'stopped')
                        Text(part.closeReason!),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous segments',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _offset == 0
                        ? null
                        : () => setState(
                            () => _offset = (_offset - 100).clamp(
                              0,
                              detail.segmentCount,
                            ),
                          ),
                  ),
                  Flexible(child: Text('${detail.segmentCount} segments')),
                  IconButton(
                    tooltip: 'Next segments',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: !detail.hasMore
                        ? null
                        : () => setState(() => _offset = detail.nextOffset),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
