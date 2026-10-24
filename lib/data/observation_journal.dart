import 'package:flutter/services.dart';

import '../domain/models/journal_observation.dart';
export '../domain/models/journal_observation.dart';

class ObservationJournalClient {
  const ObservationJournalClient({
    MethodChannel channel = const MethodChannel('com.eartime.app/tracking'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<JournalPage> read({int after = 0, int limit = 32}) async {
    if (after < 0 || limit < 1 || limit > 128) {
      throw ArgumentError('Invalid journal page bounds');
    }
    final reply = await _channel
        .invokeMapMethod<dynamic, dynamic>('readObservationJournal', {
          'after': after,
          'limit': limit,
        })
        .timeout(const Duration(seconds: 5));
    if (reply == null) {
      throw const FormatException('Native journal response absent');
    }
    final page = JournalPage.fromMap(reply);
    if (page.observations.any((item) => item.identity.sequence <= after) ||
        page.observations.length > limit) {
      throw const FormatException('Native journal returned an invalid page');
    }
    return page;
  }

  /// Call only after a consumer has durably committed its own read model.
  Future<int> acknowledge(JournalIdentity applied, String consumer) async {
    final result = await _channel
        .invokeMethod<int>('acknowledgeObservations', {
          'sourceId': applied.sourceId,
          'consumer': consumer,
          'sequence': applied.sequence,
        })
        .timeout(const Duration(seconds: 5));
    if (result == null || result < applied.sequence) {
      throw const FormatException('Native acknowledgement did not advance');
    }
    return result;
  }
}
