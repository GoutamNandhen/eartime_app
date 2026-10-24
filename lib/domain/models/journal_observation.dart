class JournalIdentity {
  const JournalIdentity({
    required this.observationId,
    required this.sourceId,
    required this.sequence,
    required this.collectionEpoch,
  });

  final String observationId;
  final String sourceId;
  final int sequence;
  final String collectionEpoch;

  factory JournalIdentity.fromMap(Map<dynamic, dynamic> map) {
    final value = JournalIdentity(
      observationId: map['observationId'] as String,
      sourceId: map['sourceId'] as String,
      sequence: map['sequence'] as int,
      collectionEpoch: map['collectionEpoch'] as String,
    );
    if (value.sequence <= 0 ||
        value.observationId.isEmpty ||
        value.sourceId.isEmpty ||
        value.collectionEpoch.isEmpty) {
      throw const FormatException('Invalid native journal identity');
    }
    return value;
  }
}

class DurableObservation {
  DurableObservation._({
    required this.identity,
    required this.kind,
    required this.wallUtcMs,
    required this.elapsedMs,
    required this.bootId,
    required this.confidence,
    required this.provenance,
    required this.payload,
  });

  final JournalIdentity identity;
  final String kind;
  final int wallUtcMs;
  final int? elapsedMs;
  final String? bootId;
  final String confidence;
  final String provenance;
  final Map<String, dynamic> payload;

  bool get isGap => kind == 'COLLECTION_GAP';

  factory DurableObservation.fromMap(Map<dynamic, dynamic> map) {
    if (map['payloadVersion'] != 1) {
      throw const FormatException('Unsupported native observation version');
    }
    return DurableObservation._(
      identity: JournalIdentity.fromMap(map),
      kind: map['kind'] as String,
      wallUtcMs: map['wallUtcMs'] as int,
      elapsedMs: map['elapsedMs'] as int?,
      bootId: map['bootId'] as String?,
      confidence: map['confidence'] as String,
      provenance: map['provenance'] as String,
      payload: Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(map['payload'] as Map),
      ),
    );
  }
}

class JournalPage {
  JournalPage._({
    required this.sourceId,
    required this.observationCount,
    required this.lastSequence,
    required this.gapCount,
    required this.conflictCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.failedCount,
    required this.lastError,
    required this.nextCursor,
    required this.hasMore,
    required this.observations,
  });

  final String sourceId;
  final int observationCount;
  final int lastSequence;
  final int gapCount;
  final int conflictCount;
  final int pendingCount;
  final int rejectedCount;
  final int failedCount;
  final String? lastError;
  final int nextCursor;
  final bool hasMore;
  final List<DurableObservation> observations;

  factory JournalPage.fromMap(Map<dynamic, dynamic> map) {
    if (![1, 2, 3].contains(map['schemaVersion'])) {
      throw const FormatException('Unsupported native journal schema');
    }
    final sourceId = map['sourceId'] as String;
    final observations = (map['observations'] as List)
        .map((item) => DurableObservation.fromMap(item as Map))
        .toList();
    var previous = 0;
    for (final observation in observations) {
      if (observation.identity.sourceId != sourceId ||
          observation.identity.sequence <= previous) {
        throw const FormatException(
          'Journal source or sequence is inconsistent',
        );
      }
      previous = observation.identity.sequence;
    }
    final next = map['nextCursor'] as int;
    final last = map['lastSequence'] as int;
    if (next < 0 ||
        next > last ||
        (observations.isNotEmpty && previous != next)) {
      throw const FormatException('Journal replay cursor is inconsistent');
    }
    return JournalPage._(
      sourceId: sourceId,
      observationCount: map['observationCount'] as int,
      lastSequence: last,
      gapCount: map['gapCount'] as int,
      conflictCount: map['conflictCount'] as int,
      pendingCount: map['pendingCount'] as int,
      rejectedCount: map['rejectedCount'] as int,
      failedCount: map['failedCount'] as int,
      lastError: map['lastError'] as String?,
      nextCursor: next,
      hasMore: map['hasMore'] as bool,
      observations: List.unmodifiable(observations),
    );
  }
}
