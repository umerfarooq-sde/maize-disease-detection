import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
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
        first: _CountCard(
          label: 'Saved scans',
          value: summary.totals['totalScans']!,
        ),
        second: _CountCard(
          label: 'Completed scans',
          value: summary.totals['completedScans']!,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      ResponsivePair(
        first: _CountCard(
          label: 'Healthy model labels',
          value: summary.totals['healthyPredictions']!,
        ),
        second: _CountCard(
          label: 'Disease model labels',
          value: summary.totals['diseasePredictions']!,
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

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label),
          const SizedBox(height: AppSpacing.sm),
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ),
  );
}

class PredictionUncertaintyCard extends StatelessWidget {
  const PredictionUncertaintyCard({required this.summary, super.key});
  final FarmerAnalytics summary;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.wheat,
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
