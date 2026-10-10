import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/scan_result_view_model.dart';
import '../widgets/scan_result_card.dart';

class ScanResultView extends StatelessWidget {
  const ScanResultView({this.onNewScan, super.key});
  final VoidCallback? onNewScan;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScanResultViewModel>();
    return AppPage(
      storageKey: 'scan-result-${model.scanId}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Leaf analysis',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (model.busy) ...[
            AppLoadingState(
              message: model.uploading && model.progress < 1
                  ? 'Uploading photo… ${(model.progress * 100).round()}%'
                  : 'Waiting for analysis…',
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (model.scan case final scan?)
            ScanResultCard(
              scan: scan,
              selectedImage: model.selectedImage,
              busy: model.busy,
              onRetry: model.canRetryAnalysis ? model.retryAnalysis : null,
              onRefresh: model.refresh,
            ),
          if (model.error case final error?) ...[
            const SizedBox(height: AppSpacing.lg),
            AppErrorState(
              error: error,
              onRetry: model.canRetryAnalysis
                  ? model.retryAnalysis
                  : model.refresh,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            key: const Key('new-scan-action'),
            onPressed: model.busy ? null : onNewScan,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Scan another leaf'),
          ),
        ],
      ),
    );
  }
}
