import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/ai_operations.dart';

/// A bounded page of scope/day observations, without summing unlike scopes.
class AiOperationChart extends StatefulWidget {
  const AiOperationChart({required this.data, super.key});
  final AiOperations data;
  @override
  State<AiOperationChart> createState() => _AiOperationChartState();
}

class _AiOperationChartState extends State<AiOperationChart> {
  static const _pageSize = 9;
  int _page = 0;
  @override
  void didUpdateWidget(covariant AiOperationChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.data, oldWidget.data)) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.data.daily;
    final maximum = days.fold<int>(
      0,
      (value, day) => day.requests > value ? day.requests : value,
    );
    final start = _page * _pageSize;
    final visible = days.skip(start).take(_pageSize).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Daily operation activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'UTC dates · recorded events by scope. One action may appear in several scopes.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (days.isEmpty)
              const Text('No daily observations returned.')
            else ...[
              Text(
                'Scale: 0–$maximum attempts per scope/day',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              for (final day in visible) ...[
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  container: true,
                  label:
                      '${day.date} UTC · ${day.scope}: ${day.requests} recorded attempts, ${day.failures} failed',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${day.date} · ${day.scope}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${day.requests} attempts · ${day.failures} failed',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.small),
                          child: LinearProgressIndicator(
                            value: maximum == 0 ? 0 : day.requests / maximum,
                            minHeight: AppSpacing.md,
                            color: Theme.of(context).colorScheme.primary,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Showing ${start + 1}–${start + visible.length} of ${days.length} scope/day entries',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: _page == 0
                        ? null
                        : () => setState(() => _page--),
                    child: const Text('Previous entries'),
                  ),
                  OutlinedButton(
                    onPressed: start + visible.length >= days.length
                        ? null
                        : () => setState(() => _page++),
                    child: const Text('Next entries'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
