import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_cards.dart';
import '../../../data/models/ai_operations.dart';
import 'ai_operation_chart.dart';

String operationLabel(String operation) => switch (operation) {
  'INFERENCE' => 'Inference',
  'RETRIEVAL' => 'Knowledge retrieval',
  'GENERATION' => 'Grounded generation',
  'EXPLANATION' => 'Scan explanation',
  'GEMINI' => 'Gemini provider call',
  'EMBEDDING' => 'Embedding',
  _ => operation,
};

class AiOperationsPanel extends StatelessWidget {
  const AiOperationsPanel({
    required this.data,
    this.compact = false,
    super.key,
  });
  final AiOperations? data;
  final bool compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = _content(context);
      return constraints.hasBoundedHeight
          ? SingleChildScrollView(child: content)
          : content;
    },
  );
  Widget _content(BuildContext context) {
    final value = data;
    final ready = value != null && value.status == 'COLLECTED';
    final preview = ready
        ? value.rows.where((row) => row.scope == 'NODE').toList()
        : <AiOperationSummary>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'AI operations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  compact
                      ? 'Recorded attempts by scope. Several events may belong to one action.'
                      : 'Recorded operational events, not unique Farmer requests or model accuracy. Node attempts and provider calls are separate; do not add them together.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (value == null)
                  const Text('Operational statistics have not been loaded.')
                else if (!ready)
                  const Text(
                    'Operational statistics are unavailable. Refresh to retry; unknown counts are not zero.',
                  )
                else ...[
                  if (value.rows.isEmpty && value.pending == 0)
                    const Text(
                      'No recorded operations in this period. Earlier activity was not collected.',
                    ),
                  if (!compact && value.pending > 0)
                    Text(
                      '${value.pending} current Node events are queued for recording; they are not persisted counts.',
                    ),
                  if (compact)
                    for (final row
                        in (preview.isEmpty ? value.rows : preview).take(
                          3,
                        )) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${row.scope} · ${operationLabel(row.operation)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        '${row.requests} recorded attempts · ${row.failures} failed',
                      ),
                    ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    compact
                        ? 'Node queue: ${value.pending} awaiting recording · Dropped: ${value.dropped ?? 'unknown'} · Best effort'
                        : 'Current Node process dropped ${value.dropped ?? 'an unknown number of'} telemetry events. Collection is bounded best effort.',
                  ),
                  if (!compact) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Abrupt process loss and provider-writer failures may omit events. The local Node drop counter does not measure all collection loss. No prompts or account identifiers are stored in this operational report.',
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (ready && !compact) ...[
          const SizedBox(height: AppSpacing.lg),
          for (final scope in const ['NODE', 'AI_SERVICE', 'PROVIDER'])
            if (value.rows.any((row) => row.scope == scope)) ...[
              Card(
                child: ExpansionTile(
                  key: PageStorageKey('ai-operation-scope-$scope'),
                  initiallyExpanded: scope == 'NODE',
                  expansionAnimationStyle: AnimationStyle(
                    duration: AppMotion.resolve(context, AppMotion.reveal),
                  ),
                  title: Text(switch (scope) {
                    'NODE' => 'Node orchestration',
                    'AI_SERVICE' => 'AI service operations',
                    _ => 'Provider calls',
                  }),
                  subtitle: Text(scope),
                  childrenPadding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final row in value.rows.where(
                      (row) => row.scope == scope,
                    ))
                      _OperationRow(row: row),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          AiOperationChart(data: value),
          const SizedBox(height: AppSpacing.lg),
          const AppStatusPanel(
            tone: AppStatusTone.information,
            child: Text(
              'Reporting coverage is best effort, not a complete accounting ledger. Latency describes recorded operations in milliseconds. Runtime event volume and prediction distribution do not establish accuracy or drift.',
            ),
          ),
        ],
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.row});
  final AiOperationSummary row;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          operationLabel(row.operation),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${row.scope} · ${row.operation}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${row.requests} attempts · ${row.successes} successful · ${row.failures} failed · ${row.abstained} abstained',
        ),
        Text(
          'Failure rate: ${row.requests == 0 ? 'unavailable (no attempts)' : '${(100 * row.failures / row.requests).toStringAsFixed(1)}%'}',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (row.requests == 0)
          const Text('Latency unavailable: no recorded samples.')
        else ...[
          Text('Mean ${row.averageMs.toStringAsFixed(1)} ms'),
          Text(
            'p50 ${row.p50Ms.toStringAsFixed(1)} ms · p95 ${row.p95Ms.toStringAsFixed(1)} ms',
          ),
        ],
      ],
    ),
  );
}
