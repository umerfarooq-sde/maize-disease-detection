import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/ai_operations.dart';

class AiOperationsPanel extends StatelessWidget {
  const AiOperationsPanel({required this.data, super.key});
  final AiOperations? data;
  @override
  Widget build(BuildContext context) {
    final value = data;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI operations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Observed operational events, not model accuracy. Node attempts and provider calls are separate; do not add them together.',
            ),
            if (value == null)
              const Text('Operational statistics have not been loaded.')
            else if (value.status == 'UNAVAILABLE')
              const Text(
                'Operational statistics are unavailable. Refresh to retry; unknown counts are not zero.',
              )
            else ...[
              if (value.pending > 0)
                Text(
                  '${value.pending} operational events are awaiting durable recording. Refresh shortly.',
                ),
              if (value.rows.isEmpty && value.pending == 0)
                const Text(
                  'No recorded operations in this period. Earlier activity was not collected.',
                ),
              for (final row in value.rows)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row.scope} · ${row.operation}'),
                      Text(
                        '${row.requests} requests · ${row.successes} successful · ${row.failures} failed · ${row.abstained} abstained',
                      ),
                      Text(
                        'Failure rate: ${row.requests == 0 ? 'unknown' : '${(100 * row.failures / row.requests).toStringAsFixed(1)}%'}',
                      ),
                      Text(
                        'Latency ms: mean ${row.averageMs.toStringAsFixed(0)} · p50 ${row.p50Ms.toStringAsFixed(0)} · p95 ${row.p95Ms.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
              if (value.daily.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('Requests over time · UTC'),
                for (final day in value.daily.take(90))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.date} · ${day.scope}: ${day.requests} requests (${day.failures} failed)',
                        ),
                        LinearProgressIndicator(
                          value:
                              day.requests /
                              value.daily
                                  .map((e) => e.requests)
                                  .reduce((a, b) => a > b ? a : b),
                        ),
                      ],
                    ),
                  ),
                if (value.daily.length > 90)
                  const Text(
                    'Showing the first 90 daily scope entries; choose a shorter period for detail.',
                  ),
              ],
              Text(
                'Current Node process dropped ${value.dropped} telemetry events. Collection is bounded best effort; abrupt process loss or provider-writer failure may omit events. No prompts or account identifiers are stored.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
