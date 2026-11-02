import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/analytics_period.dart';
import '../../analytics/widgets/analytics_cards.dart';
import '../../analytics/widgets/analytics_charts.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../widgets/admin_report_page.dart';
import '../widgets/admin_metric_grid.dart';
import '../widgets/admin_navigation.dart';
import '../widgets/admin_system_summary.dart';
import '../widgets/ai_operations_panel.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});
  @override
  Widget build(BuildContext context) => AdminReportPage(
    title: 'System overview',
    description:
        'System-wide saved activity and model predictions. These statistics do not measure prediction correctness or field disease prevalence.',
    storageKey: 'admin-overview',
    builder: (context, model) {
      final data = model.data!;
      final scans = data.scans;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Updated ${scanDate(scans.asOf)} (local time)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminMetricGrid(
            children: [
              AdminMetricCard(
                label: 'Registered farmers',
                value: data.farmers['total']?.toString(),
                icon: Icons.people_outline,
                note: 'All-time accounts',
              ),
              AdminMetricCard(
                label: 'Saved scans',
                value: scans.totals['totalScans']?.toString(),
                icon: Icons.document_scanner_outlined,
                note: 'Selected period',
              ),
              AdminMetricCard(
                label: 'Healthy model labels',
                value: scans.totals['healthyPredictions']?.toString(),
                icon: Icons.eco_outlined,
                note: 'Recorded predictions',
              ),
              AdminMetricCard(
                label: 'Disease model labels',
                value: scans.totals['diseasePredictions']?.toString(),
                icon: Icons.biotech_outlined,
                note: 'Recorded predictions',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Active farmers: ${data.farmers['active']} · Suspended: ${data.farmers['suspended']} · Deactivated: ${data.farmers['deactivated']}',
          ),
          Text(
            'Scan ownership · ${data.authenticatedScans} authenticated · ${data.anonymousScans} anonymous',
          ),
          Text(
            'Completed: ${scans.totals['completedScans']} · Waiting: ${scans.totals['pendingScans']} · Processing: ${scans.totals['processingScans']} · Failed: ${scans.totals['failedScans']}',
          ),
          const SizedBox(height: AppSpacing.xl),
          AiOperationsPanel(data: data.operations, compact: true),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('view-ai-operations'),
            onPressed: () => context.go(AppRoutes.adminAiOperations),
            icon: const Icon(Icons.hub_outlined),
            label: const Text('View AI Operations'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              'Manage workspace',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reviewed content, configuration and access',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AdminMetricGrid(
            children: [
              for (final destination in [
                AdminDestination.knowledge,
                AdminDestination.diseases,
                AdminDestination.references,
                AdminDestination.fertilizer,
                AdminDestination.farmers,
                AdminDestination.health,
                AdminDestination.audit,
              ])
                Card(
                  child: AdminNavigationLink(
                    destination: destination,
                    onTap: () => context.go(destination.location),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AdminSystemSummary(data: data),
          const SizedBox(height: AppSpacing.lg),
          if (scans.totals['totalScans'] == 0)
            const AppEmptyState(
              title: 'No scans in this period',
              message: 'Choose another period or return after scans are saved.',
              icon: Icons.insights_outlined,
            )
          else ...[
            Card(
              child: ExpansionTile(
                key: const PageStorageKey('admin-scan-trends'),
                title: const Text('Scan trends and model labels'),
                childrenPadding: const EdgeInsets.all(AppSpacing.md),
                expansionAnimationStyle: AnimationStyle(
                  duration: AppMotion.resolve(context, AppMotion.reveal),
                ),
                children: [
                  ScanActivityChart(periods: analyticsPeriods(scans.daily)),
                  const SizedBox(height: AppSpacing.lg),
                  PredictionDistribution(summary: scans),
                  const SizedBox(height: AppSpacing.lg),
                  PredictionUncertaintyCard(summary: scans),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: ExpansionTile(
                key: const PageStorageKey('admin-recent-scans'),
                title: const Text('Recent scan activity'),
                subtitle: const Text(
                  'Up to 10 scans · no Farmer identities or photos',
                ),
                expansionAnimationStyle: AnimationStyle(
                  duration: AppMotion.resolve(context, AppMotion.reveal),
                ),
                childrenPadding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  for (final item in data.recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.label == null
                                ? scanStatusLabel(item.status)
                                : 'Model label: ${analyticsLabel(item.label!)}',
                          ),
                          Text(
                            '${scanDate(item.createdAt)} (local) · ${item.anonymous ? 'Anonymous' : 'Authenticated'} · ${scanStatusLabel(item.status)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
