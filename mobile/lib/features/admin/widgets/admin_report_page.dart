import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/admin_dashboard_view_model.dart';

/// Shares the existing report's date window, loading and retry semantics.
class AdminReportPage extends StatefulWidget {
  const AdminReportPage({
    required this.title,
    required this.description,
    required this.storageKey,
    required this.builder,
    super.key,
  });
  final String title, description, storageKey;
  final Widget Function(BuildContext, AdminDashboardViewModel) builder;
  @override
  State<AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  bool _requested = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final model = context.read<AdminDashboardViewModel>();
      if (!model.loading && model.data == null && model.error == null) {
        model.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AdminDashboardViewModel>();
    return AppPage(
      storageKey: widget.storageKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FIELD INTELLIGENCE / ADMIN',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: widget.storageKey == 'admin-overview'
                    ? 'Refresh dashboard'
                    : 'Refresh AI Operations',
                onPressed: model.loading ? null : () => model.load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
            '${model.range.toQuery()['from']} through ${model.range.toQuery()['to']} · UTC',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (model.loading)
            AppLoadingState(
              message: widget.storageKey == 'admin-overview'
                  ? 'Loading system overview…'
                  : 'Loading AI Operations…',
            )
          else if (model.error case final error?)
            AppErrorState(error: error, onRetry: () => model.load())
          else if (model.data == null)
            const AppEmptyState(
              title: 'Reporting data unavailable',
              message:
                  'No report was returned. Unknown measurements are not zero.',
            )
          else
            widget.builder(context, model),
        ],
      ),
    );
  }
}
