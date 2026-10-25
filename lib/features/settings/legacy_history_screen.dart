import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import '../../providers/data_providers.dart';
import '../../data/database/database.dart';
import '../../data/application_data_access.dart';

final legacyHistoryPageProvider = FutureProvider.autoDispose
    .family<List<EarTimeEventEntity>, int>((ref, offset) {
      final db = ref.watch(databaseProvider);
      return applicationDataAccess.run(
        () =>
            (db.select(db.earTimeEvents)
                  ..orderBy([
                    (row) => OrderingTerm(
                      expression: row.timestamp,
                      mode: OrderingMode.desc,
                    ),
                    (row) => OrderingTerm(expression: row.id),
                  ])
                  ..limit(100, offset: offset))
                .get(),
      );
    });

class LegacyHistoryScreen extends ConsumerStatefulWidget {
  const LegacyHistoryScreen({super.key});
  @override
  ConsumerState<LegacyHistoryScreen> createState() =>
      _LegacyHistoryScreenState();
}

class _LegacyHistoryScreenState extends ConsumerState<LegacyHistoryScreen> {
  int offset = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Legacy history')),
    body: ref
        .watch(legacyHistoryPageProvider(offset))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(legacyHistoryPageProvider(offset)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Preserved pre-projection observations. Output attribution and continuity were not verified; these records are not added to confirmed listening totals.',
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No legacy records.'),
                ),
              ...rows.map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.deviceName),
                  subtitle: Text(
                    '${row.eventType}\n${DateTime.fromMillisecondsSinceEpoch(row.timestamp)}',
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous records',
                    onPressed: offset == 0
                        ? null
                        : () => setState(() => offset -= 100),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next records',
                    onPressed: rows.length < 100
                        ? null
                        : () => setState(() => offset += 100),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
  );
}
