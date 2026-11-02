import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_cards.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/farmer_analytics.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import 'analytics_charts.dart';

class AnalyticsSummaryCards extends StatelessWidget {
  const AnalyticsSummaryCards({required this.summary, super.key});
  final FarmerAnalytics summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ResponsivePair(
        first: AppMetricCard(
          label: 'Saved scans',
          value: summary.totals['totalScans']!.toString(),
        ),
        second: AppMetricCard(
          label: 'Completed scans',
          value: summary.totals['completedScans']!.toString(),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      ResponsivePair(
        first: AppMetricCard(
          label: 'Healthy model labels',
          value: summary.totals['healthyPredictions']!.toString(),
        ),
        second: AppMetricCard(
          label: 'Disease model labels',
          value: summary.totals['diseasePredictions']!.toString(),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Waiting: ${summary.totals['pendingScans']} · Processing: ${summary.totals['processingScans']} · Failed: ${summary.totals['failedScans']}',
      ),
      if (summary.totals['completedWithoutPrediction']! > 0)
        Text(
          'Completed scans without a stored result: ${summary.totals['completedWithoutPrediction']}',
        ),
    ],
  );
}

class PredictionUncertaintyCard extends StatelessWidget {
  const PredictionUncertaintyCard({required this.summary, super.key});
  final FarmerAnalytics summary;
  @override
  Widget build(BuildContext context) => Card(
    color: context.semanticColors.warningContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Result confidence flags',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Low confidence: ${summary.uncertainty['lowConfidence']}'),
          Text('Confident flag: ${summary.uncertainty['confident']}'),
          Text(
            'Legacy / unavailable flag: ${summary.uncertainty['unavailable']}',
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'These reflect each model’s settings. They do not measure how often predictions were correct.',
          ),
        ],
      ),
    ),
  );
}

class AnalyticsActivityTile extends StatelessWidget {
  const AnalyticsActivityTile({
    required this.item,
    required this.onOpen,
    super.key,
  });
  final AnalyticsActivity item;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: ValueKey('analytics-activity-${item.id}'),
      title: Text(
        item.predictedClass == null
            ? scanStatusLabel(item.status)
            : 'Model label: ${analyticsLabel(item.predictedClass!)}',
      ),
      subtitle: Text(
        '${scanDate(item.createdAt)} (local) · ${scanStatusLabel(item.status)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpen,
    ),
  );
}
