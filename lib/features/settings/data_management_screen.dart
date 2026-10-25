import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/journal_transfer.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({
    super.key,
    this.client = const JournalTransferClient(),
  });
  final JournalTransferClient client;
  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _busy = false;
  String? _status;
  Map<dynamic, dynamic>? _recoveries;
  bool _recoveryError = false;
  int _offset = 0;
  int _recoveryGeneration = 0;
  @override
  void initState() {
    super.initState();
    loadRecoveries();
  }

  Future<void> loadRecoveries() async {
    final generation = ++_recoveryGeneration;
    try {
      final value = await widget.client.recoveries(_offset);
      if (mounted && generation == _recoveryGeneration) {
        setState(() {
          _recoveries = value;
          _recoveryError = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _recoveryGeneration) {
        setState(() => _recoveryError = true);
      }
    }
  }

  Future<void> transfer(String operation, {String? id}) async {
    if (_busy) return;
    final applicationExport = operation == 'exportApplicationData';
    final restore = !{
      'exportNativeJournal',
      'exportApplicationData',
    }.contains(operation);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          applicationExport
              ? 'Export private application data?'
              : restore
              ? 'Replace native history?'
              : 'Export private observations?',
        ),
        content: Text(
          applicationExport
              ? 'This unencrypted export contains native observations and device associations, settings, names, goals, notification preferences, preserved legacy history and journal recovery metadata. Choose a private local destination. Android document providers may store files remotely. The file is integrity-checked, not password protected. Whole-app restore is not yet available; native-only restore does not accept this format.'
              : restore
              ? 'The selected archive will replace native observation history. A local recovery archive is retained first. Legacy history and preferences are not changed. Corrupt or conflicting archives are rejected. Restored open intervals do not continue across the restore.'
              : 'This unencrypted file contains observation timestamps, device identifiers and payloads. Choose a private local destination. It includes native observations only, not legacy history or preferences. It is not a full-app backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(restore ? 'Replace history' : 'Choose destination'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final result = await widget.client.transfer(operation, recoveryId: id);
      if (mounted) {
        setState(
          () => _status = result['cancelled'] == true
              ? 'Transfer canceled.'
              : result['unchanged'] == true
              ? 'This history is already present. Nothing changed.'
              : applicationExport
              ? 'Application export saved: ${result['count']} observations, ${result['legacyCount']} preserved legacy rows. Whole-app restore is not yet available.'
              : restore
              ? '${result['count']} archived observations restored. A recovery archive was retained.'
              : '${result['count']} observations exported with an integrity checksum.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = error is PlatformException && error.message != null
              ? error.message
              : 'Transfer failed. No success is assumed. Retry after checking the selected file and storage. Incomplete exports cannot be restored.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await loadRecoveries();
      }
    }
  }

  @override
  void dispose() {
    if (_busy) unawaited(widget.client.cancel().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local data')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Application data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const Text(
          'Application exports include settings and preserved history. Whole-app restore and deletion are not available yet.',
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.archive_outlined),
          title: const Text('Export application data'),
          onTap: _busy ? null : () => transfer('exportApplicationData'),
        ),
        const Divider(),
        const Text(
          'Native observation archives',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Legacy history and preferences are separate and remain on this device. These controls never promote unverified playback to confirmed listening.',
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Export native history'),
          onTap: _busy ? null : () => transfer('exportNativeJournal'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore),
          title: const Text('Restore native history from file'),
          onTap: _busy ? null : () => transfer('restoreNativeJournal'),
        ),
        if (_busy) ...[
          const LinearProgressIndicator(),
          TextButton.icon(
            onPressed: () async {
              try {
                await widget.client.cancel();
              } catch (_) {
                if (mounted) {
                  setState(
                    () => _status =
                        'Cancellation could not be requested. The transfer result is still pending.',
                  );
                }
              }
            },
            icon: const Icon(Icons.close),
            label: const Text('Cancel transfer'),
          ),
        ],
        if (_status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_status!, semanticsLabel: _status),
          ),
        const Divider(),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recovery archives',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : loadRecoveries,
              tooltip: 'Refresh recovery archives',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_recoveryError)
          const Text('Recovery archives are unavailable. Refresh to retry.'),
        if (_recoveries != null && (_recoveries!['items'] as List).isEmpty)
          const Text('No recovery archives on this page.'),
        for (final raw in (_recoveries?['items'] as List? ?? []))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              DateTime.fromMillisecondsSinceEpoch(
                (raw as Map)['createdUtcMs'] as int,
              ).toLocal().toString(),
            ),
            subtitle: Text('${raw['bytes']} bytes, native observations'),
            trailing: IconButton(
              tooltip: 'Restore recovery archive',
              icon: const Icon(Icons.history),
              onPressed: _busy
                  ? null
                  : () => transfer(
                      'restoreJournalRecovery',
                      id: raw['id'] as String,
                    ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Previous recovery archives',
              icon: const Icon(Icons.chevron_left),
              onPressed: _busy || _offset == 0
                  ? null
                  : () {
                      setState(
                        () => _offset = (_offset - 20).clamp(0, _offset),
                      );
                      loadRecoveries();
                    },
            ),
            IconButton(
              tooltip: 'Next recovery archives',
              icon: const Icon(Icons.chevron_right),
              onPressed: _busy || _recoveries?['hasMore'] != true
                  ? null
                  : () {
                      setState(
                        () => _offset = _recoveries!['nextOffset'] as int,
                      );
                      loadRecoveries();
                    },
            ),
          ],
        ),
      ],
    ),
  );
}
