import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/farmer_analytics.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import '../view_models/analytics_view_model.dart';
import '../widgets/analytics_cards.dart';
import '../widgets/analytics_charts.dart';

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({this.onOpenScan, super.key});
  final ValueChanged<String>? onOpenScan;
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AnalyticsViewModel>();
    if (!model.signedIn) {
      return AppPage(
        child: AppEmptyState(
          title: 'Sign in to see your field insights',
          message:
              'Statistics are private to your farmer account. Guest scans stay anonymous.',
          icon: Icons.lock_outline,
          action: FilledButton(
            onPressed: () => context.push(AppRoutes.auth),
            child: const Text('Sign in'),
          ),
        ),
      );
    }
    final summary = model.summary;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your scan activity',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh field insights',
                onPressed: model.loading ? null : () => model.load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Saved activity and model suggestions from your own account. Correctness has not been measured.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final days in [7, 30, 90])
                ChoiceChip(
                  label: Text('$days days'),
                  selected: model.selectedDays == days,
                  onSelected: model.loading
                      ? null
                      : (_) => model.selectDays(days),
                ),
              OutlinedButton.icon(
                onPressed: model.loading
                    ? null
                    : () => _chooseDates(context, model),
                icon: const Icon(Icons.date_range),
                label: const Text('Custom dates'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${analyticsDateText(model.range.from)} through ${analyticsDateText(model.range.to)} · UTC',
          ),
          if (model.filterError case final message?)
            Text(message, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: AppSpacing.xl),
          if (model.loading)
            const AppLoadingState(message: 'Loading your field insights…')
          else if (model.error case final error?)
            AppErrorState(error: error, onRetry: () => model.load())
          else if (summary != null && summary.totals['totalScans'] == 0)
            AppEmptyState(
              title: 'No saved scans in this period',
              message: 'Try another date range or start your first saved scan.',
              icon: Icons.insights_outlined,
              action: FilledButton.icon(
                onPressed: () => context.go(AppRoutes.scan),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan a leaf'),
              ),
            )
          else if (summary != null) ...[
            Text('Updated ${scanDate(summary.asOf)} (local time)'),
            const SizedBox(height: AppSpacing.md),
            AnalyticsSummaryCards(summary: summary),
            const SizedBox(height: AppSpacing.xl),
            ScanActivityChart(periods: model.periods),
            const SizedBox(height: AppSpacing.xl),
            PredictionDistribution(summary: summary),
            const SizedBox(height: AppSpacing.xl),
            PredictionUncertaintyCard(summary: summary),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in model.activity)
              AnalyticsActivityTile(
                item: item,
                onOpen: () => onOpenScan != null
                    ? onOpenScan!(item.id)
                    : context.push('${AppRoutes.history}/scans/${item.id}'),
              ),
            if (model.moreError case final error?)
              AppErrorState(error: error, onRetry: model.loadMore),
            if (model.loadingMore)
              const AppLoadingState(message: 'Loading more activity…'),
            if (model.hasMore && !model.loadingMore && model.moreError == null)
              OutlinedButton(
                onPressed: model.loadMore,
                child: const Text('Load more activity'),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _chooseDates(
    BuildContext context,
    AnalyticsViewModel model,
  ) async {
    final today = AnalyticsDateRange.lastDays(1).to;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: today,
      currentDate: today,
      initialDateRange: DateTimeRange(
        start: model.range.from,
        end: model.range.to,
      ),
      helpText: 'Select UTC dates (up to 366 days)',
    );
    if (picked != null && context.mounted) {
      await model.selectCalendarRange(picked.start, picked.end);
    }
  }
}
