import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/knowledge.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../data/models/scan_record.dart';
import '../view_models/scan_result_view_model.dart';
import '../widgets/scan_result_card.dart';

class ScanResultView extends StatelessWidget {
  const ScanResultView({this.onNewScan, this.onExplainScan, super.key});
  final VoidCallback? onNewScan;
  final ValueChanged<ScanRecord>? onExplainScan;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ScanResultViewModel>();
    return AppPage(
      maxWidth: AppSizing.readingMaxWidth,
      storageKey: 'scan-result-${model.scanId}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (model.busy) ...[
            AppLoadingState(
              message: model.uploading && model.progress < 1
                  ? 'Uploading photo… ${(model.progress * 100).round()}%'
                  : 'Waiting for analysis…',
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (model.scan case final scan?)
            _ResultAppearance(
              status: scan.status,
              child: ScanResultCard(
                scan: scan,
                selectedImage: model.selectedImage,
                anonymousKey: model.imageCapability,
                busy: model.busy,
                onRetry: model.canRetryAnalysis ? model.retryAnalysis : null,
                onRefresh: model.refresh,
                actions: _ResultActions(
                  scan: scan,
                  busy: model.busy,
                  onExplainScan: onExplainScan,
                  onNewScan: onNewScan,
                ),
              ),
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
          if (model.scan == null) ...[
            const SizedBox(height: AppSpacing.xl),
            _ResultActions(busy: model.busy, onNewScan: onNewScan),
          ],
        ],
      ),
    );
  }
}

class _ResultAppearance extends StatelessWidget {
  const _ResultAppearance({required this.status, required this.child});

  final ScanStatus status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(status),
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: AppMotion.resolve(context, AppMotion.reveal),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: 0.9 + (0.1 * value),
        child: Transform.translate(
          offset: Offset(0, AppSpacing.sm * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.busy,
    this.scan,
    this.onNewScan,
    this.onExplainScan,
  });
  final ScanRecord? scan;
  final bool busy;
  final VoidCallback? onNewScan;
  final ValueChanged<ScanRecord>? onExplainScan;
  @override
  Widget build(BuildContext context) {
    final current = scan;
    final prediction = current?.prediction;
    final slug = prediction == null
        ? null
        : knowledgeSlugForClass(prediction.predictedClass);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slug != null) ...[
          FilledButton.icon(
            key: const Key('read-disease-information'),
            onPressed: busy
                ? null
                : () => context.go('${AppRoutes.knowledge}/$slug'),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              prediction!.predictedClass == 'Healthy'
                  ? 'Read healthy leaf information'
                  : 'Read disease information',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (current?.status == ScanStatus.completed &&
            prediction != null &&
            onExplainScan != null) ...[
          OutlinedButton.icon(
            key: const Key('explain-scan-action'),
            onPressed: busy ? null : () => onExplainScan!(current!),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Explain this scan'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        OutlinedButton.icon(
          key: const Key('new-scan-action'),
          onPressed: busy ? null : onNewScan,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Scan another leaf'),
        ),
      ],
    );
  }
}
