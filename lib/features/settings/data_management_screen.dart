import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/journal_transfer.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({
    super.key,
    this.client = const JournalTransferClient(),
    this.runApplicationRestore,
  });
  final JournalTransferClient client;
  final Future<Map<dynamic, dynamic>> Function(
    Future<Map<dynamic, dynamic>> Function() operation,
  )?
  runApplicationRestore;
  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _busy = false;
  bool _deleting = false;
  bool _deletionAccepted = false;
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
    final applicationRestore = operation.startsWith('restoreApplication');
    final restore = !{
      'exportNativeJournal',
      'exportApplicationData',
    }.contains(operation);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          applicationRestore
              ? 'Replace application data?'
              : applicationExport
              ? 'Export private application data?'
              : restore
              ? 'Replace native history?'
              : 'Export private observations?',
        ),
        content: Text(
          applicationRestore
              ? 'This replaces native history, device associations, settings, names, goals, notification preferences and preserved legacy records with the selected application archive. Matching newer native observations are retained. A verified private recovery archive is saved first. Export a backup before continuing. Listening never continues across restore. Summary delivery attempts already made on this device are not repeated. Damaged or conflicting input is rejected. Recovery may require free storage and reopening the app.'
              : applicationExport
              ? 'This unencrypted export contains native observations and device associations, settings, names, goals, notification preferences, preserved legacy history and journal recovery metadata. Choose a private local destination. Android document providers may store files remotely. The file is integrity-checked, not password protected. Native-only restore does not accept this format.'
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
            child: Text(
              applicationRestore
                  ? 'Replace application data'
                  : restore
                  ? 'Replace history'
                  : 'Choose destination',
            ),
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
      Future<Map<dynamic, dynamic>> perform() =>
          widget.client.transfer(operation, recoveryId: id);
      final result = applicationRestore && widget.runApplicationRestore != null
          ? await widget.runApplicationRestore!(perform)
          : await perform();
      if (mounted) {
        setState(
          () => _status = result['cancelled'] == true
              ? 'Transfer canceled.'
              : result['unchanged'] == true
              ? 'This history is already present. Nothing changed.'
              : applicationRestore
              ? 'Application data restored: ${result['count']} observations, ${result['legacyCount']} preserved legacy rows. A private recovery archive was retained.'
              : applicationExport
              ? 'Application export saved: ${result['count']} observations, ${result['legacyCount']} preserved legacy rows.'
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
    if (_busy && !_deleting) {
      unawaited(widget.client.cancel().catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> requestDeletion() async {
    if (_busy) return;
    var acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const Text('Delete all local data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Android will erase all EarTime private data: native and legacy history, device names and associations, settings, goals, notification preferences, diagnostics and private recovery archives. Collection and transfers will stop, permissions will be revoked and the app may close. The installed app and exported documents outside its private storage remain. This cannot be undone or canceled after the request is sent.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acknowledged,
                onChanged: (value) =>
                    update(() => acknowledged = value == true),
                title: const Text(
                  'I understand that all local EarTime data will be permanently erased.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: acknowledged
                  ? () => Navigator.pop(context, true)
                  : null,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete permanently'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _deleting = true;
      _deletionAccepted = false;
      _status = 'Requesting Android data deletion. No completion is assumed.';
    });
    try {
      final requested = await widget.client.requestDeletion(confirmed: true);
      if (!mounted) return;
      setState(() {
        _status = requested
            ? 'Android accepted the deletion request. The app may close; this acknowledgment is not proof that deletion has completed.'
            : 'Android did not accept the deletion request. No completion is assumed.';
        _deletionAccepted = requested;
        if (!requested) {
          _busy = false;
          _deleting = false;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _deleting = false;
          _status =
              'Deletion could not be confirmed. No completion is assumed. You can retry or use Android app settings.';
        });
      }
    }
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
          'Application archives contain private settings and preserved history. Keep backups in a private location.',
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.archive_outlined),
          title: const Text('Export application data'),
          onTap: _busy ? null : () => transfer('exportApplicationData'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.settings_backup_restore),
          title: const Text('Restore application data'),
          onTap: _busy ? null : () => transfer('restoreApplicationData'),
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_forever_outlined),
          title: const Text('Delete all local data'),
          onTap: _busy ? null : requestDeletion,
        ),
        if (_busy) ...[
          if (!_deletionAccepted) const LinearProgressIndicator(),
          if (!_deleting)
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
            subtitle: Text(
              '${raw['bytes']} bytes, ${raw['scope'] == 'application_data' ? 'application data' : 'native observations'}',
            ),
            trailing: IconButton(
              tooltip: 'Restore recovery archive',
              icon: const Icon(Icons.history),
              onPressed: _busy
                  ? null
                  : () => transfer(
                      raw['scope'] == 'application_data'
                          ? 'restoreApplicationRecovery'
                          : 'restoreJournalRecovery',
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
