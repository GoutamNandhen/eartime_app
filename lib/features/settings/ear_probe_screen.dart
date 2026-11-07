import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Native ear-detection probe client (B8/B9 research). Passive and in memory only.
class EarProbeClient {
  const EarProbeClient();
  static const _channel = MethodChannel('com.eartime.app/tracking');
  Future<Map<dynamic, dynamic>> start(Duration duration) async =>
      (await _channel.invokeMapMethod<dynamic, dynamic>('earProbeStart', {
        'durationMs': duration.inMilliseconds,
      }))!;
  Future<void> mark(String label) =>
      _channel.invokeMethod<void>('earProbeMark', {'label': label});
  Future<Map<dynamic, dynamic>> stop() async =>
      (await _channel.invokeMapMethod<dynamic, dynamic>('earProbeStop'))!;
}

class EarProbeScreen extends StatefulWidget {
  const EarProbeScreen({
    super.key,
    this.client = const EarProbeClient(),
    this.requestPermissions,
  });
  final EarProbeClient client;
  final Future<bool> Function()? requestPermissions;

  @override
  State<EarProbeScreen> createState() => _EarProbeScreenState();
}

class _EarProbeScreenState extends State<EarProbeScreen> {
  static const duration = Duration(minutes: 3);
  static const steps = [
    'Left out',
    'Left in',
    'Right out',
    'Right in',
    'Both out',
    'Both in',
    'Left in case',
    'Left back in ear',
  ];
  bool _running = false;
  bool _busy = false;
  String? _error;
  String? _scan;
  Map<dynamic, dynamic>? _result;
  final List<String> _marked = [];
  Timer? _ticker;
  int _elapsed = 0;

  Future<bool> _permissions() async {
    if (widget.requestPermissions != null) return widget.requestPermissions!();
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    return statuses[Permission.bluetoothConnect]?.isGranted ?? false;
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _marked.clear();
    });
    try {
      if (!await _permissions()) {
        throw PlatformException(
          code: 'PERMISSION',
          message: 'Nearby devices permission is needed.',
        );
      }
      final started = await widget.client.start(duration);
      _elapsed = 0;
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _elapsed++);
        if (_elapsed >= duration.inSeconds) _stop();
      });
      setState(() {
        _running = true;
        _scan = started['scan'] as String?;
      });
    } on PlatformException catch (error) {
      setState(() => _error = error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mark(String label) async {
    try {
      await widget.client.mark(label);
      setState(() => _marked.add(label));
    } on PlatformException catch (error) {
      setState(() => _error = error.message ?? error.code);
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    if (!_running) return;
    setState(() => _busy = true);
    try {
      final result = await widget.client.stop();
      if (mounted) setState(() => _result = result);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_running) unawaited(widget.client.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = _marked.length < steps.length ? steps[_marked.length] : null;
    final candidates = (_result?['candidates'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Ear detection probe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Checks whether your earbuds share which bud is in your ear. '
            'It only listens; it never connects to, changes or writes to your earbuds. '
            'Results stay on this phone until you copy them.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Wear both buds. Start the probe, then follow the steps. Wait about '
            '5 seconds after each change before tapping the button for it.',
          ),
          const SizedBox(height: 16),
          if (!_running)
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(_result == null ? 'Start probe' : 'Run again'),
            ),
          if (_running) ...[
            Text(
              'Recording ${_elapsed}s of ${duration.inSeconds}s'
              '${_scan == null ? '' : ' (advertisements: $_scan)'}',
            ),
            const SizedBox(height: 8),
            if (next != null) ...[
              Text(
                'Next: $next',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _mark(next),
                child: Text('Done: $next'),
              ),
            ] else
              const Text('All steps done. Tap Finish.'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _stop,
              child: const Text('Finish'),
            ),
            for (final label in _marked) Text('✓ $label'),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 16),
            Text(
              candidates.isEmpty
                  ? 'No signal matched your bud changes.'
                  : '${candidates.length} possible in-ear signal(s) found.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${result['eventCount']} changes recorded, '
              '${(result['marks'] as List).length} steps marked.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: result['report'] as String),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy report'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Device addresses are replaced with random codes in the report.',
            ),
          ],
        ],
      ),
    );
  }
}
