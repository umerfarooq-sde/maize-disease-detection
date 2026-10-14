import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/repositories/scan_records_repository.dart';
import '../../auth/view_models/farmer_session_view_model.dart';
import '../../scan_history/view_models/scan_history_view_model.dart';
import '../../scan_history/widgets/history_scan_tile.dart';

/// Reuses the private paginated history. No scan identifier is entered manually.
class AssistantScanPicker extends StatelessWidget {
  const AssistantScanPicker({super.key});
  static const _heightFraction = 0.85;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FarmerSessionViewModel>();
    return FractionallySizedBox(
      heightFactor: _heightFraction,
      child: SafeArea(
        child: ChangeNotifierProvider(
          key: ValueKey('assistant-scans-${session.revision}'),
          create: (_) =>
              ScanHistoryViewModel(context.read<ScanRecordsRepository>())
                ..load(),
          child: const _ScanChoices(),
        ),
      ),
    );
  }
}

class _ScanChoices extends StatelessWidget {
  const _ScanChoices();
  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScanHistoryViewModel>();
    final scans = model.items
        .where(
          (scan) =>
              scan.status == ScanStatus.completed && scan.prediction != null,
        )
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizing.contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Choose a scan to explain',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Select a completed model prediction from your private history.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!model.hasAuthenticatedSession)
              const AppEmptyState(
                title: 'Sign in to choose a scan',
                message: 'Only your account’s scans can be selected.',
              ),
            if (model.hasAuthenticatedSession) ...[
              if (model.isLoading)
                const AppLoadingState(message: 'Loading your scans…'),
              if (model.error case final error?)
                AppErrorState(error: error, onRetry: model.refresh),
              if (!model.isLoading && model.error == null && scans.isEmpty)
                AppEmptyState(
                  title: 'No completed scans here',
                  message: model.hasMore
                      ? 'You can load another page of your history.'
                      : 'Complete a leaf scan to ask for a sourced explanation.',
                ),
              for (final scan in scans)
                HistoryScanTile(
                  key: ValueKey('assistant-scan-${scan.id}'),
                  scan: scan,
                  onOpen: () => Navigator.of(context).pop(scan),
                ),
              if (model.loadMoreError case final error?)
                AppErrorState(error: error, onRetry: model.loadMore),
              if (model.isLoadingMore)
                const AppLoadingState(message: 'Loading more scans…'),
              if (model.hasMore && !model.isLoading && !model.isLoadingMore)
                OutlinedButton.icon(
                  key: const Key('assistant-scans-load-more'),
                  onPressed: model.loadMore,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more scans'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
