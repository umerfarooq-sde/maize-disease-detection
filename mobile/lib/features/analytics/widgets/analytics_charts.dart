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
                    value: item.count / total,
                    backgroundColor: AppColors.mist,
                    color: item.label == 'Healthy'
                        ? AppColors.blue
                        : AppColors.amber,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Scans over time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'UTC dates grouped into up to six periods. All saved scans are counted.',
            ),
            const SizedBox(height: AppSpacing.lg),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in periods)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Tooltip(
                        message:
                            '${analyticsDateText(item.from)} through ${analyticsDateText(item.to)} UTC: ${item.count} scans',
                        child: Semantics(
                          label:
                              '${analyticsDateText(item.from)} through ${analyticsDateText(item.to)} UTC: ${item.count} scans',
                          child: ExcludeSemantics(
                            child: SizedBox(
                              width: AppSizing.touchTarget,
                              child: Column(
                                children: [
                                  Text(
                                    '${item.count}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  SizedBox(
                                    height: AppSizing.emblem * 2,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: AppSpacing.xl,
                                        height: maximum == 0
                                            ? 0
                                            : AppSizing.emblem *
                                                  2 *
                                                  item.count /
                                                  maximum,
                                        decoration: BoxDecoration(
                                          color: AppColors.forest,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.small,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    '${item.from.month}/${item.from.day}\n–${item.to.month}/${item.to.day}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
