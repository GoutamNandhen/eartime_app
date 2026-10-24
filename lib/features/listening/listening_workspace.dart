import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/listening_projection.dart';
import '../../providers/listening_projection_provider.dart';
import '../../providers/listening_preferences_provider.dart';

enum ListeningView { home, timeline, analytics, devices, wellbeing }

enum ListeningRange { today, week, month, year, custom }

class ListeningWorkspace extends ConsumerStatefulWidget {
  const ListeningWorkspace({super.key, required this.view});
  final ListeningView view;
  @override
  ConsumerState<ListeningWorkspace> createState() => _ListeningWorkspaceState();
}

class _ListeningWorkspaceState extends ConsumerState<ListeningWorkspace> {
  ListeningRange _range = ListeningRange.today;
  DateTimeRange? _custom;
  int _offset = 0;

  ListeningWindow window() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final until = DateTime(day.year, day.month, day.day + 1);
    final from = switch (_range) {
      ListeningRange.today => day,
      ListeningRange.week => DateTime(
        day.year,
        day.month,
        day.day - day.weekday + 1,
      ),
      ListeningRange.month => DateTime(day.year, day.month),
      ListeningRange.year => DateTime(day.year),
      ListeningRange.custom => _custom?.start ?? day,
    };
    final end = _range == ListeningRange.custom && _custom != null
        ? DateTime(_custom!.end.year, _custom!.end.month, _custom!.end.day + 1)
        : until;
    return ListeningWindow(from, end, offset: _offset);
  }

  Future<void> selectDates() async {
    final now = DateTime.now();
    final value = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now,
      initialDateRange: _custom,
    );
    if (value == null || !mounted) return;
    final calendarDays =
        DateTime.utc(value.end.year, value.end.month, value.end.day)
            .difference(
              DateTime.utc(
                value.start.year,
                value.start.month,
                value.start.day,
              ),
            )
            .inDays;
    if (calendarDays > 365) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose up to one year.')));
      return;
    }
    setState(() {
      _custom = value;
      _range = ListeningRange.custom;
      _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = window();
    final data = ref.watch(listeningProjectionProvider(query));
    final goal =
        ref
            .watch(listeningPreferencesProvider)
            .asData
            ?.value
            .dailyGoalMinutes ??
        0;
    final title = switch (widget.view) {
      ListeningView.home => 'TOTAL LISTEN TIME',
      ListeningView.timeline => 'Timeline',
      ListeningView.analytics => 'Analytics',
      ListeningView.devices => 'Devices',
      ListeningView.wellbeing => 'Wellbeing',
    };
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(listeningProjectionProvider(query));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButton<ListeningRange>(
                  value: _range,
                  isExpanded: true,
                  items: ListeningRange.values
                      .map(
                        (range) => DropdownMenuItem(
                          value: range,
                          child: Text(switch (range) {
                            ListeningRange.today => 'Today',
                            ListeningRange.week => 'This week',
                            ListeningRange.month => 'This month',
                            ListeningRange.year => 'This year',
                            ListeningRange.custom => 'Custom dates',
                          }),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == ListeningRange.custom) {
                      selectDates();
                      return;
                    }
                    if (value != null) {
                      setState(() {
                        _range = value;
                        _offset = 0;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: selectDates,
                tooltip: 'Select dates',
                icon: const Icon(Icons.date_range_outlined),
              ),
              IconButton(
                onPressed: () =>
                    ref.invalidate(listeningProjectionProvider(query)),
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          data.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Listening history is unavailable. No listening time has been estimated.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(listeningProjectionProvider(query)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
            data: (snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.lastError != null || snapshot.failedCount > 0)
                  const _Notice(
                    'Collection has reported an error. Some activity may be missing.',
                    Icons.warning_amber,
                  ),
                if (snapshot.pendingCount > 0)
                  const _Notice(
                    'Saving recent observations',
                    Icons.save_outlined,
                  ),
                if (snapshot.gapCount > 0)
                  _Notice(
                    '${snapshot.gapCount} collection gap(s). Unknown time is excluded.',
                    Icons.history_toggle_off,
                  ),
                if (widget.view != ListeningView.devices) ...[
                  _Metric(
                    label: 'Confirmed external listening',
                    value: formatListeningDuration(snapshot.confirmed),
                    primary: true,
                  ),
                  _Metric(
                    label: 'Unverified playback activity',
                    value: formatListeningDuration(snapshot.unverified),
                  ),
                  const _Notice(
                    'The current collector cannot verify the playing output. Unverified activity is not included in listening totals.',
                    Icons.info_outline,
                  ),
                ],
                if (widget.view == ListeningView.home) ...[
                  if (goal > 0 && _range == ListeningRange.today)
                    ...goalWidgets(snapshot, goal),
                  const _Section('Current activity'),
                  Text(
                    snapshot.intervals.any((i) => i.live && i.confirmed)
                        ? 'Listening'
                        : snapshot.intervals.any((i) => i.open)
                        ? 'Last observed playback; current continuity unverified'
                        : 'No active playback observed',
                  ),
                  const _Section('Devices'),
                  ...deviceRows(snapshot),
                  const _Section('Recent intervals'),
                  ...intervalRows(snapshot, maximum: 5),
                ],
                if (widget.view == ListeningView.timeline) ...[
                  const _Section('Intervals'),
                  ...intervalRows(snapshot),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Previous intervals',
                        onPressed: _offset == 0
                            ? null
                            : () => setState(
                                () => _offset = (_offset - 100).clamp(
                                  0,
                                  snapshot.intervalCount,
                                ),
                              ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Flexible(
                        child: Text('${snapshot.intervalCount} intervals'),
                      ),
                      IconButton(
                        tooltip: 'Next intervals',
                        onPressed: !snapshot.hasMore
                            ? null
                            : () =>
                                  setState(() => _offset = snapshot.nextOffset),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
                if (widget.view == ListeningView.analytics ||
                    widget.view == ListeningView.wellbeing) ...[
                  _Metric(
                    label: 'Longest continuous listening',
                    value: formatListeningDuration(snapshot.longest),
                  ),
                  _Metric(
                    label: 'Average continuous listening',
                    value: formatListeningDuration(snapshot.average),
                  ),
                  Text('${snapshot.listeningRuns} confirmed listening runs'),
                  const _Section('Daily listening'),
                  if (snapshot.confirmed == Duration.zero)
                    const Text('No confirmed listening in this period.'),
                  ...snapshot.days.reversed
                      .where(
                        (d) =>
                            d.confirmed > Duration.zero ||
                            d.unverified > Duration.zero,
                      )
                      .map(
                        (day) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(date(day.start)),
                          subtitle: Text(
                            'Unverified ${formatListeningDuration(day.unverified)}',
                          ),
                          trailing: Text(
                            formatListeningDuration(day.confirmed),
                          ),
                        ),
                      ),
                  if (widget.view == ListeningView.analytics) ...[
                    const _Section('By hour'),
                    ...snapshot.hourly
                        .where((hour) => hour.duration > Duration.zero)
                        .map(
                          (hour) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${hour.hour.toString().padLeft(2, '0')}:00  ${formatListeningDuration(hour.duration)}',
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: snapshot.confirmed == Duration.zero
                                      ? 0
                                      : hour.duration.inMilliseconds /
                                            snapshot.confirmed.inMilliseconds,
                                  semanticsLabel:
                                      '${hour.hour}:00 confirmed listening',
                                  semanticsValue: formatListeningDuration(
                                    hour.duration,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    const _Section('By device'),
                    if (snapshot.perDevice.isEmpty)
                      const Text('No verified device totals.'),
                    ...snapshot.perDevice.map(
                      (total) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          snapshot.devices
                                  .where(
                                    (device) => device.id == total.deviceId,
                                  )
                                  .firstOrNull
                                  ?.name ??
                              'Audio device',
                        ),
                        subtitle: Text(formatListeningDuration(total.duration)),
                      ),
                    ),
                  ],
                  if (widget.view == ListeningView.wellbeing) ...[
                    if (goal > 0 && _range == ListeningRange.today)
                      ...goalWidgets(snapshot, goal),
                    const _Section('Sound exposure'),
                    const Text(
                      'Not measured. Playback duration and device volume are not sound-pressure or hearing-risk measurements.',
                    ),
                  ],
                ],
                if (widget.view == ListeningView.devices) ...[
                  ...deviceRows(snapshot, details: true),
                  if (snapshot.deviceCount > snapshot.devices.length)
                    Text(
                      'Showing the ${snapshot.devices.length} most recently seen of ${snapshot.deviceCount} devices.',
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> goalWidgets(ListeningSnapshot snapshot, int minutes) => [
    const _Section('Daily goal'),
    Text('${snapshot.confirmed.inMinutes} of $minutes minutes'),
    const SizedBox(height: 8),
    LinearProgressIndicator(
      value:
          (snapshot.confirmed.inMilliseconds /
                  Duration(minutes: minutes).inMilliseconds)
              .clamp(0, 1),
      semanticsLabel: 'Daily confirmed listening goal',
    ),
  ];

  List<Widget> deviceRows(ListeningSnapshot snapshot, {bool details = false}) {
    if (snapshot.devices.isEmpty) {
      return [const Text('No devices observed yet.')];
    }
    final devices = snapshot.devices.toList()
      ..sort(
        (a, b) => a.connected == b.connected
            ? a.name.compareTo(b.name)
            : a.connected
            ? -1
            : 1,
      );
    return devices
        .map(
          (device) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.headphones_outlined),
            title: Text(
              device.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${device.connected ? 'Connected' : 'Disconnected'}${device.identityVerified ? '' : ' - identity unverified'}',
            ),
            trailing: details
                ? IconButton(
                    tooltip: 'Device details',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                device.connected ? 'Connected' : 'Disconnected',
                              ),
                              Text(
                                device.identityVerified
                                    ? 'Verified physical identity'
                                    : 'Provisional identity; not merged across collection restarts',
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Rename'),
                                onPressed: () async {
                                  final name = await showDialog<String>(
                                    context: context,
                                    builder: (_) =>
                                        _DeviceNameDialog(device.name),
                                  );
                                  if (name == null || !mounted) return;
                                  try {
                                    await ref
                                        .read(
                                          listeningPreferencesClientProvider,
                                        )
                                        .update({
                                          'deviceNames': {device.id: name},
                                        });
                                    if (!mounted) return;
                                    ref.invalidate(
                                      listeningProjectionProvider(window()),
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Device name could not be saved.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Left battery: Unknown\nRight battery: Unknown\nCase battery: Unknown\nWearing state: Unknown',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        )
        .toList();
  }

  List<Widget> intervalRows(ListeningSnapshot snapshot, {int? maximum}) {
    if (snapshot.intervals.isEmpty) {
      return [const Text('No playback intervals in this period.')];
    }
    return snapshot.intervals
        .take(maximum ?? snapshot.intervals.length)
        .map(
          (interval) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              interval.confirmed ? Icons.headphones : Icons.help_outline,
            ),
            title: Text(
              '${clock(interval.start)} - ${interval.live ? 'Now' : clock(interval.end)}',
            ),
            subtitle: Text(
              '${date(interval.start)}\n${interval.confirmed ? 'Confirmed output' : 'Unverified output'}'
              '${interval.closeReason == 'collection_gap' || interval.closeReason == 'continuity_unproven' ? '\nContinuity unknown after last observation' : ''}',
            ),
            trailing: Text(formatListeningDuration(interval.duration)),
            isThreeLine: true,
          ),
        )
        .toList();
  }

  String date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String clock(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
}

class _DeviceNameDialog extends StatefulWidget {
  const _DeviceNameDialog(this.name);
  final String name;
  @override
  State<_DeviceNameDialog> createState() => _DeviceNameDialogState();
}

class _DeviceNameDialogState extends State<_DeviceNameDialog> {
  late final controller = TextEditingController(text: widget.name);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Device name'),
    content: TextField(
      controller: controller,
      maxLength: 80,
      decoration: const InputDecoration(labelText: 'Name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.primary = false,
  });
  final String label;
  final String value;
  final bool primary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style:
                (primary
                        ? Theme.of(context).textTheme.headlineLarge
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(
                      letterSpacing: 0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
