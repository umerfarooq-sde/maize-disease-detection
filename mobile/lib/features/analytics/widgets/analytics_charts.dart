import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/farmer_analytics.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../../../data/models/analytics_period.dart';

String analyticsLabel(String label) =>
    label == 'OTHER' ? 'Other / legacy label' : diseaseLabel(label);

class PredictionDistribution extends StatelessWidget {
  const PredictionDistribution({required this.summary, super.key});
  final FarmerAnalytics summary;
  @override
  Widget build(BuildContext context) {
    final total = summary.totals['withPrediction']!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Model label distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'One latest result per completed scan. Correctness has not been measured.',
            ),
            if (total == 0) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Labels appear when saved scans have completed results.',
              ),
            ] else
              for (final item in summary.distribution.where(
                (item) => item.label != 'OTHER' || item.count > 0,
              )) ...[
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  label:
                      '${analyticsLabel(item.label)}: ${item.count} model predictions',
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(analyticsLabel(item.label))),
                        const SizedBox(width: AppSpacing.sm),
                        Text('${item.count}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    minHeight: AppSpacing.sm,
                    value: item.count / total,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class ScanActivityChart extends StatelessWidget {
  const ScanActivityChart({required this.periods, super.key});
  final List<AnalyticsPeriod> periods;
  @override
  Widget build(BuildContext context) {
    final maximum = periods.fold<int>(
      0,
      (value, item) => item.count > value ? item.count : value,
    );
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Scans over time',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'UTC dates grouped into up to six periods. All saved scans are counted.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Scale: 0–$maximum scans per period',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            for (final item in periods) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                container: true,
                label:
                    '${analyticsDateText(item.from)} through ${analyticsDateText(item.to)} UTC: ${item.count} scans',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${analyticsDateText(item.from)} – ${analyticsDateText(item.to)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${item.count} scans',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.small),
                        child: LinearProgressIndicator(
                          value: maximum == 0 ? 0 : item.count / maximum,
                          minHeight: AppSpacing.md,
                          color: colors.primary,
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (periods.isEmpty) const Text('No activity series returned.'),
          ],
        ),
      ),
    );
  }
}
