import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';
import '../utils/scan_presentation.dart';
import 'prediction_summary.dart';
import 'scan_result_image.dart';

/// Shared public scan presentation for fresh results and owned history details.
class ScanResultCard extends StatelessWidget {
  const ScanResultCard({
    required this.scan,
    this.selectedImage,
    this.onRetry,
    this.onRefresh,
    this.busy = false,
    this.showImage = true,
    super.key,
  });
  final ScanRecord scan;
  final SelectedLeafImage? selectedImage;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;
  final bool busy;
  final bool showImage;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showImage) ...[
        ScanResultImage(scan: scan, selectedImage: selectedImage),
        const SizedBox(height: AppSpacing.lg),
      ],
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                scanStatusLabel(scan.status),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Scan time: ${scanDate(scan.createdAt)}'),
              const SizedBox(height: AppSpacing.lg),
              if (scan.prediction case final prediction?) ...[
                PredictionSummary(prediction: prediction),
                const SizedBox(height: AppSpacing.lg),
                Text('Model: ${prediction.modelVersion}'),
                const SizedBox(height: AppSpacing.xs),
                Text('Preprocessing: ${prediction.preprocessingVersion}'),
                const SizedBox(height: AppSpacing.xs),
                Text('Analyzed: ${scanDate(prediction.inferredAt)}'),
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
            ],
          ),
        ),
      ),
    ],
  );
}
