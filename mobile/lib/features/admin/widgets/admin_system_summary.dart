import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/admin_dashboard.dart';
import '../../disease_detection/utils/scan_presentation.dart';

class AdminSystemSummary extends StatelessWidget {
  const AdminSystemSummary({required this.data, super.key});
  final AdminDashboard data;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Updated ${scanDate(data.scans.asOf)} (local time)'),
      const SizedBox(height: AppSpacing.md),
      ResponsivePair(
        first: _card(
          context,
          'Registered farmers',
          '${data.farmers['total']}',
          'All-time accounts · Active ${data.farmers['active']} · Suspended ${data.farmers['suspended']} · Deactivated ${data.farmers['deactivated']}',
        ),
        second: _card(
          context,
          'Scan ownership',
          '${data.authenticatedScans} authenticated',
          '${data.anonymousScans} anonymous · selected period',
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'System summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(switch (data.registry) {
                'SINGLE_PRODUCTION' =>
                  'Production registry: ${data.productionVersion}',
                'MULTIPLE_PRODUCTION' =>
                  'Production registry conflict: multiple versions are marked production.',
                _ => 'Production registry: no model has been promoted.',
              }),
              const SizedBox(height: AppSpacing.sm),
              Text(
                data.inferenceConfigured
                    ? 'Configured inference version: ${data.configuredVersion}'
                    : 'Inference is not configured.',
              ),
              const Text(
                'Live model readiness has not been checked. Registry status and configuration do not prove availability.',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'AI operational statistics are shown separately below. Offline model evaluation remains separate from runtime requests.',
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _card(BuildContext context, String title, String value, String note) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title),
              const SizedBox(height: AppSpacing.sm),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(note),
            ],
          ),
        ),
      );
}
