import 'package:flutter/material.dart';
import '../../data/device_identity.dart';

class DeviceIdentityScreen extends StatefulWidget {
  const DeviceIdentityScreen({
    super.key,
    required this.deviceId,
    required this.name,
    this.client = const DeviceIdentityClient(),
  });
  final String deviceId;
  final String name;
  final DeviceIdentityClient client;
  @override
  State<DeviceIdentityScreen> createState() => _DeviceIdentityScreenState();
}

class _DeviceIdentityScreenState extends State<DeviceIdentityScreen> {
  Map<dynamic, dynamic>? _page;
  String? _error;
  int _offset = 0;
  int _generation = 0;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final page = await widget.client.read(
        widget.deviceId,
        aliasOffset: _offset,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _page = page;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Device associations unavailable. Refresh to retry.',
        );
      }
    }
  }

  Future<void> change(Map alias, {bool reset = false}) async {
    if (_busy || _page == null) return;
    final target = reset
        ? null
        : await showDialog<Map>(
            context: context,
            builder: (_) =>
                _TargetDialog(deviceId: widget.deviceId, client: widget.client),
          );
    if ((!reset && target == null) || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          reset ? 'Reset endpoint association?' : 'Associate this endpoint?',
        ),
        content: Text(
          reset
              ? 'This endpoint will return to its original device identity. Earlier observations are retained.'
              : 'You confirm that this endpoint belongs to ${target!['name']}. Earlier observations keep their recorded identity. Names and timing are not proof of a physical match. Playback and telemetry are not verified by this association.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm association'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.change(
        sourceId: _page!['sourceId'] as String,
        alias: alias,
        targetDeviceId: target?['id'] as String?,
      );
      _offset = 0;
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Association could not be updated. Refresh before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Endpoint associations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : load,
              tooltip: 'Refresh associations',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Physical identity is not hardware-verified. Associations are local, reversible and separate from display names.',
        ),
        if (_busy || (_page == null && _error == null))
          const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!),
          ),
        if (_page != null && (_page!['aliases'] as List).isEmpty)
          const Text('No endpoint associations in this identity page.'),
        for (final raw in (_page?['aliases'] as List? ?? []))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bluetooth Classic / A2DP - ${raw['endpointSuffix']}'),
              Text(
                raw['evidence'] == 'USER_CONFIRMED'
                    ? 'User-associated device identity'
                    : 'Same observed endpoint',
              ),
              Wrap(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => change(raw as Map),
                    tooltip: 'Change association',
                    icon: const Icon(Icons.link),
                  ),
                  IconButton(
                    onPressed: _busy || raw['deviceId'] == raw['originDeviceId']
                        ? null
                        : () => change(raw as Map, reset: true),
                    tooltip: 'Reset association',
                    icon: const Icon(Icons.undo),
                  ),
                ],
              ),
              const Divider(),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _busy || _offset == 0
                  ? null
                  : () {
                      setState(
                        () => _offset = (_offset - 100).clamp(0, _offset),
                      );
                      load();
                    },
              tooltip: 'Previous endpoints',
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: _busy || _page?['hasMoreAliases'] != true
                  ? null
                  : () {
                      setState(
                        () => _offset = _page!['nextAliasOffset'] as int,
                      );
                      load();
                    },
              tooltip: 'Next endpoints',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.deviceId, required this.client});
  final String deviceId;
  final DeviceIdentityClient client;
  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  Map<dynamic, dynamic>? _page;
  bool _error = false;
  int _offset = 0;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final value = await widget.client.read(
        widget.deviceId,
        candidateOffset: _offset,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _page = value;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Choose device identity'),
    content: SizedBox(
      width: double.maxFinite,
      height: 320,
      child: Column(
        children: [
          if (_error)
            TextButton(
              onPressed: load,
              child: const Text('Retry device identities'),
            ),
          if (_page == null && !_error) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                for (final raw in (_page?['candidates'] as List? ?? []))
                  ListTile(
                    title: Text(raw['name'] as String),
                    subtitle: Text(
                      'Identity ${(raw['id'] as String).substring(0, 8)}',
                    ),
                    onTap: () => Navigator.pop(context, raw as Map),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Previous identities',
                icon: const Icon(Icons.chevron_left),
                onPressed: _offset == 0
                    ? null
                    : () {
                        setState(
                          () => _offset = (_offset - 100).clamp(0, _offset),
                        );
                        load();
                      },
              ),
              IconButton(
                tooltip: 'Next identities',
                icon: const Icon(Icons.chevron_right),
                onPressed: _page?['hasMoreCandidates'] != true
                    ? null
                    : () {
                        setState(
                          () => _offset = _page!['nextCandidateOffset'] as int,
                        );
                        load();
                      },
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
