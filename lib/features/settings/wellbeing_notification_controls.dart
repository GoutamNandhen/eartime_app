import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/wellbeing_notifications.dart';

class WellbeingNotificationControls extends StatefulWidget {
  const WellbeingNotificationControls({
    super.key,
    required this.value,
    required this.onSave,
    this.saving = false,
    this.client = const WellbeingNotificationClient(),
    this.requestPermission,
  });
  final WellbeingNotificationPreferences value;
  final Future<void> Function(WellbeingNotificationPreferences) onSave;
  final bool saving;
  final WellbeingNotificationClient client;
  final Future<void> Function()? requestPermission;
  @override
  State<WellbeingNotificationControls> createState() =>
      _WellbeingNotificationControlsState();
}

class _WellbeingNotificationControlsState
    extends State<WellbeingNotificationControls> {
  WellbeingNotificationStatus? _status;
  bool _failed = false;
  int _generation = 0;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: refresh);
    refresh();
  }

  @override
  void didUpdateWidget(WellbeingNotificationControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.saving && !widget.saving) {
      refresh();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    try {
      final status = await widget.client.status();
      if (mounted && generation == _generation) {
        setState(() {
          _status = status;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _status = null;
        });
      }
    }
  }

  Future<void> permission() async {
    try {
      if (widget.requestPermission != null) {
        await widget.requestPermission!();
      } else {
        if (await Permission.notification.isGranted) {
          await openAppSettings();
        } else {
          final status = await Permission.notification.request();
          if (status.isPermanentlyDenied) await openAppSettings();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) await refresh();
  }

  Future<void> time(int minute, void Function(int) selected) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _SummaryTimeDialog(minute),
    );
    if (value != null && mounted) selected(value);
  }

  String label(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
  String scheduled(int value) {
    final time = DateTime.fromMillisecondsSinceEpoch(value);
    return '${MaterialLocalizations.of(context).formatFullDate(time)} ${TimeOfDay.fromDateTime(time).format(context)}';
  }

  Widget timeRow(
    String title,
    int minute,
    void Function(int) selected, {
    bool enabled = true,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(label(minute)),
    trailing: IconButton(
      tooltip: 'Edit $title',
      icon: const Icon(Icons.schedule),
      onPressed: widget.saving || !enabled
          ? null
          : () => time(minute, selected),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Text(
        'Recorded listening summaries',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Daily summary'),
        value: widget.value.daily,
        onChanged: widget.saving
            ? null
            : (value) => widget.onSave(widget.value.copyWith(daily: value)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Weekly summary'),
        subtitle: const Text('Previous calendar week, Monday delivery'),
        value: widget.value.weekly,
        onChanged: widget.saving
            ? null
            : (value) => widget.onSave(widget.value.copyWith(weekly: value)),
      ),
      timeRow(
        'Summary time',
        widget.value.deliveryMinute,
        (value) => widget.onSave(widget.value.copyWith(deliveryMinute: value)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Quiet hours'),
        value: widget.value.quiet,
        onChanged: widget.saving
            ? null
            : (value) => widget.onSave(widget.value.copyWith(quiet: value)),
      ),
      timeRow(
        'Quiet hours start',
        widget.value.quietStart,
        (value) => widget.onSave(widget.value.copyWith(quietStart: value)),
        enabled: widget.value.quiet,
      ),
      timeRow(
        'Quiet hours end',
        widget.value.quietEnd,
        (value) => widget.onSave(widget.value.copyWith(quietEnd: value)),
        enabled: widget.value.quiet,
      ),
      if (widget.value.quiet &&
          widget.value.quietStart == widget.value.quietEnd)
        const Text('All-day quiet hours: summaries paused.'),
      const Text(
        'Recorded totals exclude unknown listening. Android may delay delivery. Quiet hours apply to wellbeing notifications, not the required collection-service notification.',
      ),
      if (_failed) const Text('Notification status unavailable.'),
      if (_status case final status?) ...[
      if (status.permissionGranted == null) const Text('Notification permission state is unavailable.'),
      if (status.permissionGranted == false) ...[
          const Text(
            'Wellbeing notifications are blocked in Android settings.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.saving ? null : permission,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Enable notifications'),
            ),
          ),
        ],
        if (!status.schedulingAvailable)
          const Text('Scheduling unavailable. Refresh to retry.'),
        if ([
          'HISTORY_UNAVAILABLE',
          'DELIVERY_UNAVAILABLE',
          'JOB_SCHEDULING_FAILED',
          'SCHEDULING_UNAVAILABLE',
          'RECEIPT_WRITE_FAILED',
        ].contains(status.delivery))
          const Text(
            'The last summary could not be delivered. Recorded history is unchanged.',
          ),
        if (status.daily != null)
          Text('Next daily summary: ${scheduled(status.daily!)}'),
        if (status.weekly != null)
          Text('Next weekly summary: ${scheduled(status.weekly!)}'),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: widget.saving ? null : refresh,
          tooltip: 'Refresh notification status',
          icon: const Icon(Icons.refresh),
        ),
      ),
    ],
  );
}

class _SummaryTimeDialog extends StatefulWidget {
  const _SummaryTimeDialog(this.minute);
  final int minute;
  @override
  State<_SummaryTimeDialog> createState() => _SummaryTimeDialogState();
}

class _SummaryTimeDialogState extends State<_SummaryTimeDialog> {
  late final _hour = TextEditingController(text: '${widget.minute ~/ 60}');
  late final _minute = TextEditingController(text: '${widget.minute % 60}');
  bool _invalid = false;
  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Time'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _hour,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Hour (0-23)'),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _minute,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minute (0-59)'),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
        ),
        if (_invalid) const Text('Enter 0-23 hours and 0-59 minutes.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final hour = int.tryParse(_hour.text);
          final minute = int.tryParse(_minute.text);
          if (hour == null ||
              minute == null ||
              hour < 0 ||
              hour > 23 ||
              minute < 0 ||
              minute > 59) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(context, hour * 60 + minute);
        },
        child: const Text('Save time'),
      ),
    ],
  );
}
