import 'package:flutter/services.dart';

class DeviceIdentityClient {
  const DeviceIdentityClient({
    MethodChannel channel = const MethodChannel('com.eartime.app/tracking'),
  }) : _channel = channel;
  final MethodChannel _channel;
  static final _id = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static bool validId(Object? value) => value is String && _id.hasMatch(value);
  Future<Map<dynamic, dynamic>> read(
    String deviceId, {
    int aliasOffset = 0,
    int candidateOffset = 0,
  }) async {
    final page = await _channel
        .invokeMapMethod<dynamic, dynamic>('readDeviceIdentity', {
          'deviceId': deviceId,
          'aliasOffset': aliasOffset,
          'candidateOffset': candidateOffset,
        });
    if (page == null ||
        page['version'] != 1 ||
        !validId(page['sourceId']) ||
        page['deviceId'] != deviceId ||
        page['aliasOffset'] != aliasOffset ||
        page['candidateOffset'] != candidateOffset ||
        page['aliases'] is! List ||
        page['candidates'] is! List ||
        (page['aliases'] as List).length > 100 ||
        (page['candidates'] as List).length > 100) {
      throw const FormatException('Invalid identity page');
    }
    for (final row in page['aliases'] as List) {
      if (row is! Map ||
          !validId(row['id']) ||
          !validId(row['deviceId']) ||
          !validId(row['originDeviceId']) ||
          row['revision'] is! int ||
          (row['revision'] as int) < 1 ||
          row['endpointSuffix'] is! String ||
          (row['endpointSuffix'] as String).length > 5 ||
          ![
            'SAME_OBSERVED_ENDPOINT',
            'USER_CONFIRMED',
          ].contains(row['evidence'])) {
        throw const FormatException('Invalid endpoint association');
      }
    }
    for (final row in page['candidates'] as List) {
      if (row is! Map ||
          !validId(row['id']) ||
          row['name'] is! String ||
          (row['name'] as String).length > 80) {
        throw const FormatException('Invalid device candidate');
      }
    }
    for (final values in [
      (aliasOffset, 'nextAliasOffset', 'hasMoreAliases'),
      (candidateOffset, 'nextCandidateOffset', 'hasMoreCandidates'),
    ]) {
      if (page[values.$2] is! int ||
          page[values.$3] is! bool ||
          (page[values.$2] as int) < 0 ||
          (page[values.$3] == true && (page[values.$2] as int) <= values.$1)) {
        throw const FormatException('Invalid identity cursor');
      }
    }
    return page;
  }

  Future<void> change({
    required String sourceId,
    required Map alias,
    String? targetDeviceId,
  }) async {
    final result = await _channel
        .invokeMapMethod<dynamic, dynamic>('changeDeviceIdentity', {
          'sourceId': sourceId,
          'aliasId': alias['id'],
          'expectedRevision': alias['revision'],
          'targetDeviceId': targetDeviceId,
          'confirmed': true,
        });
    if (result?['unchanged'] is! bool) {
      throw const FormatException('Invalid identity update result');
    }
  }

  Future<void> inspect({required String sourceId, required Map alias}) async {
    final result = await _channel
        .invokeMapMethod<dynamic, dynamic>('inspectDeviceEndpoint', {
          'sourceId': sourceId,
          'aliasId': alias['id'],
          'expectedRevision': alias['revision'],
          'confirmed': true,
        });
    if (result?['queued'] != true) {
      throw const FormatException('Endpoint inspection was not queued');
    }
  }
}
