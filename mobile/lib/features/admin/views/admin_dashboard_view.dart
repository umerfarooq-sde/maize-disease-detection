import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/analytics_period.dart';
import '../../analytics/widgets/analytics_cards.dart';
import '../../analytics/widgets/analytics_charts.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../view_models/admin_dashboard_view_model.dart';
import '../widgets/admin_system_summary.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AdminDashboardViewModel>();
    final data = model.data;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'System overview',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh dashboard',
                onPressed: model.loading ? null : () => model.load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'System-wide saved activity and model predictions. These statistics do not measure prediction correctness or field disease prevalence.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final days in [7, 30, 90])
                ChoiceChip(
                  label: Text('$days days'),
                  selected: model.range.days == days,
                  onSelected: model.loading
                      ? null
                      : (_) => model.selectDays(days),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${model.range.toQuery()['from']} through ${model.range.toQuery()['to']} · UTC scan creation dates',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.loading)
            const AppLoadingState(message: 'Loading system overview…')
          else if (model.error case final error?)
            AppErrorState(error: error, onRetry: () => model.load())
          else if (data != null) ...[
            AdminSystemSummary(data: data),
            const SizedBox(height: AppSpacing.xl),
            if (data.scans.totals['totalScans'] == 0)
              const AppEmptyState(
                title: 'No scans in this period',
                message:
                    'Choose another period or return after scans are saved.',
                icon: Icons.insights_outlined,
              )
            else ...[
              AnalyticsSummaryCards(summary: data.scans),
              const SizedBox(height: AppSpacing.xl),
              ScanActivityChart(periods: analyticsPeriods(data.scans.daily)),
              const SizedBox(height: AppSpacing.xl),
              PredictionDistribution(summary: data.scans),
              const SizedBox(height: AppSpacing.xl),
              PredictionUncertaintyCard(summary: data.scans),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Recent scan activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Up to 10 scans in the selected period. No farmer identities or photos are shown.',
              ),
              for (final item in data.recent)
                Card(
                  child: ListTile(
                    title: Text(
                      item.label == null
                          ? scanStatusLabel(item.status)
                          : 'Model label: ${analyticsLabel(item.label!)}',
                    ),
                    subtitle: Text(
                      '${scanDate(item.createdAt)} (local) · ${item.anonymous ? 'Anonymous' : 'Authenticated'} · ${scanStatusLabel(item.status)}',
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
