import 'package:flutter/services.dart';

class JournalTransferClient {
  const JournalTransferClient({
    MethodChannel channel = const MethodChannel('com.eartime.app/tracking'),
  }) : _channel = channel;
  final MethodChannel _channel;
  Future<Map<dynamic, dynamic>> transfer(
    String operation, {
    String? recoveryId,
  }) async {
    if (!{
      'exportNativeJournal',
      'exportApplicationData',
      'restoreNativeJournal',
      'restoreJournalRecovery',
    }.contains(operation)) {
      throw ArgumentError.value(operation);
    }
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(operation, {
      if (operation != 'exportNativeJournal') 'confirmed': true,
      'id': ?recoveryId,
    });
    if (result?['cancelled'] == true) return result!;
    if (result == null ||
        result['version'] != 1 ||
        result['scope'] !=
            (operation == 'exportApplicationData'
                ? 'application_data'
                : 'native_observations_only') ||
        result['count'] is! int ||
        (result['count'] as int) < 0 ||
        result['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(result['sha256'] as String)) {
      throw const FormatException('Invalid journal transfer result');
    }
    if (operation == 'exportApplicationData' &&
        (result['componentCount'] != 5 ||
            result['legacyCount'] is! int ||
            (result['legacyCount'] as int) < 0 ||
            (result['legacyCount'] as int) > 200000 ||
            (result['count'] as int) > 200000)) {
      throw const FormatException('Invalid application export result');
    }
    return result;
  }

  Future<Map<dynamic, dynamic>> recoveries(int offset) async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'listJournalRecoveries',
      {'offset': offset},
    );
    if (result == null ||
        result['items'] is! List ||
        (result['items'] as List).length > 20 ||
        result['hasMore'] is! bool ||
        result['nextOffset'] is! int ||
        (result['nextOffset'] as int) < 0 ||
        (result['hasMore'] == true &&
            (result['nextOffset'] as int) <= offset)) {
      throw const FormatException('Invalid recovery page');
    }
    for (final item in result['items'] as List) {
      if (item is! Map ||
          item['id'] is! String ||
          !RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ).hasMatch(item['id'] as String) ||
          item['createdUtcMs'] is! int ||
          (item['createdUtcMs'] as int).abs() > 8640000000000000 ||
          item['bytes'] is! int ||
          (item['bytes'] as int) < 0) {
        throw const FormatException('Invalid recovery archive metadata');
      }
    }
    return result;
  }

  Future<void> cancel() async {
    await _channel.invokeMethod<void>('cancelJournalTransfer');
  }

  Future<bool> requestDeletion({required bool confirmed}) async {
    if (!confirmed) {
      throw ArgumentError('Explicit deletion confirmation required');
    }
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'deleteApplicationData',
      {'confirmed': true, 'scope': 'all_app_private_data'},
    );
    if (result == null ||
        result['version'] != 1 ||
        result['scope'] != 'all_app_private_data' ||
        result['requested'] is! bool ||
        result['completed'] != false) {
      throw const FormatException('Invalid deletion request acknowledgment');
    }
    return result['requested'] as bool;
  }
}
