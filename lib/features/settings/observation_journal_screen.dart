import 'package:flutter/material.dart';

import '../../data/observation_journal.dart';

class ObservationJournalScreen extends StatefulWidget {
  const ObservationJournalScreen({
    super.key,
    this.client = const ObservationJournalClient(),
  });

  final ObservationJournalClient client;

  @override
  State<ObservationJournalScreen> createState() =>
      _ObservationJournalScreenState();
}

class _ObservationJournalScreenState extends State<ObservationJournalScreen> {
  final _cursors = <int>[0];
  late Future<JournalPage> _page;

  @override
  void initState() {
    super.initState();
    _page = widget.client.read();
  }

  void _load({bool reset = false, int? next, bool previous = false}) {
    setState(() {
      if (reset) {
        _cursors
          ..clear()
          ..add(0);
      }
      if (previous && _cursors.length > 1) _cursors.removeLast();
      if (next != null) _cursors.add(next);
      _page = widget.client.read(after: _cursors.last);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Observation Journal'),
      actions: [
        IconButton(
          tooltip: 'Refresh journal',
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<JournalPage>(
        future: _page,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(height: 12),
                    const Text('Native journal unavailable'),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _load(reset: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final page = snapshot.requireData;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text('Observations: ${page.observationCount}'),
                        Text('Gaps: ${page.gapCount}'),
                        Text('Conflicts: ${page.conflictCount}'),
                        Text('Pending: ${page.pendingCount}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Collector output attribution: unverified'),
                    if (page.lastError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        page.lastError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: page.observations.isEmpty
                    ? const Center(child: Text('No committed observations'))
                    : ListView.separated(
                        itemCount: page.observations.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final observation = page.observations[index];
                          final time = DateTime.fromMillisecondsSinceEpoch(
                            observation.wallUtcMs,
                          ).toLocal();
                          return ListTile(
                            leading: Icon(
                              observation.isGap
                                  ? Icons.warning_amber
                                  : Icons.receipt_long_outlined,
                            ),
                            title: Text(observation.kind),
                            subtitle: Text(
                              '#${observation.identity.sequence}  $time\n'
                              '${observation.confidence}  ${observation.provenance}',
                              overflow: TextOverflow.visible,
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: _cursors.length > 1
                        ? () => _load(previous: true)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page ${_cursors.length}'),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: page.hasMore
                        ? () => _load(next: page.nextCursor)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
