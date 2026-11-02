import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_prediction.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../utils/scan_presentation.dart';
import 'prediction_summary.dart';
import 'scan_result_image.dart';
import 'result_disclosure.dart';

/// Shared public scan presentation for fresh results and owned history details.
class ScanResultCard extends StatelessWidget {
  const ScanResultCard({
    required this.scan,
    this.selectedImage,
    this.anonymousKey,
    this.onRetry,
    this.onRefresh,
    this.busy = false,
    this.showImage = true,
    this.actions,
    super.key,
  });
  final ScanRecord scan;
  final SelectedLeafImage? selectedImage;
  final String? anonymousKey;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;
  final bool busy;
  final bool showImage;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showImage) ...[
        ScanResultImage(
          scan: scan,
          selectedImage: selectedImage,
          anonymousKey: anonymousKey,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScanStatusBanner(status: scan.status),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Scanned ${scanDate(scan.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (scan.prediction case final prediction?) ...[
                PredictionSummary(prediction: prediction, actions: actions),
                const SizedBox(height: AppSpacing.lg),
                ResultDisclosure(
                  key: const Key('analysis-details'),
                  title: 'Analysis details',
                  subtitle: 'Model and confidence policy',
                  child: _AnalysisMetadata(prediction: prediction),
                ),
              ] else if (scan.status == ScanStatus.failed) ...[
                Text(scanFailureMessage(scan.analysisErrorCode)),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    key: const Key('analysis-retry-action'),
                    onPressed: busy ? null : onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry analysis'),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Start a new scan to submit another photo.'),
                ],
              ] else ...[
                const Text(
                  'Your photo is saved. The service is still analyzing it.',
                ),
                if (onRefresh != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    key: const Key('refresh-analysis-action'),
                    onPressed: busy ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check analysis status'),
                  ),
                ],
              ],
              if (scan.prediction == null && actions != null) ...[
                const SizedBox(height: AppSpacing.xl),
                actions!,
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _ScanStatusBanner extends StatelessWidget {
  const _ScanStatusBanner({required this.status});

  final ScanStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final (background, foreground, icon) = switch (status) {
      ScanStatus.completed => (
        semantic.successContainer,
        semantic.onSuccessContainer,
        Icons.check_circle_outline,
      ),
      ScanStatus.failed => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
      ScanStatus.processing => (
        semantic.infoContainer,
        semantic.onInfoContainer,
        Icons.manage_search_outlined,
      ),
      ScanStatus.pending => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        Icons.schedule_outlined,
      ),
    };
    final label = scanStatusLabel(status);
    return Semantics(
      container: true,
      label: 'Scan status: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisMetadata extends StatelessWidget {
  const _AnalysisMetadata({required this.prediction});

  final ScanPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            'Model version: ${prediction.modelVersion}',
            key: const PageStorageKey('result-model-version'),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            'Preprocessing version: ${prediction.preprocessingVersion}',
            key: const PageStorageKey('result-preprocessing-version'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Analyzed ${scanDate(prediction.inferredAt)}'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Prediction status: ${prediction.predictionStatus == ScanPredictionStatus.lowConfidence ? 'LOW_CONFIDENCE' : 'CONFIDENT'}',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Confidence policy: ${switch (prediction.uncertaintyReason) {
              ScanUncertaintyReason.thresholdUnconfigured => 'THRESHOLD_UNCONFIGURED',
              ScanUncertaintyReason.belowValidationThreshold => 'BELOW_VALIDATION_THRESHOLD',
              null => 'Configured threshold met',
            }}',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Confidence threshold: ${prediction.confidenceThreshold?.toString() ?? 'null (not configured)'}',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Model inference: ${prediction.inferenceDurationMs.toString()} ms',
          ),
        ],
      ),
    );
  }
}
