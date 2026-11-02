import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/private_image.dart';
import '../../../data/models/scan_prediction.dart';
import '../../../data/models/scan_record.dart';
import '../../disease_detection/utils/scan_presentation.dart';

class HistoryScanTile extends StatelessWidget {
  const HistoryScanTile({
    required this.scan,
    this.onOpen,
    this.compact = false,
    super.key,
  });
  final ScanRecord scan;
  final VoidCallback? onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final prediction = scan.prediction;
    final uncertain =
        prediction?.predictionStatus == ScanPredictionStatus.lowConfidence;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: PrivateImage(
                  path: scan.imageUrl.toString(),
                  width: AppSizing.emblem,
                  height: AppSizing.emblem,
                  fit: BoxFit.cover,
                  semanticLabel: 'Saved scan thumbnail',
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scanDate(scan.createdAt), style: text.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      prediction == null
                          ? scanStatusLabel(scan.status)
                          : 'Model suggestion: ${diseaseLabel(prediction.predictedClass)}',
                      style: compact ? text.titleSmall : text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (prediction != null) ...[
                      if (!compact)
                        Text(
                          scanStatusLabel(scan.status),
                          style: text.labelLarge,
                        ),
                      Text('Model score: ${modelScore(prediction.confidence)}'),
                      if (!compact)
                        Text(
                          'Model: ${prediction.modelVersion}',
                          style: text.bodySmall,
                        ),
                      if (uncertain)
                        Text(
                          'Uncertain result',
                          style: text.labelLarge?.copyWith(
                            color: context.semanticColors.warning,
                          ),
                        ),
                    ],
                    if (scan.status == ScanStatus.failed)
                      const Text(
                        'Your photo is saved. Open the scan for details.',
                      ),
                    if (onOpen != null && !compact) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'View result',
                        style: text.labelLarge?.copyWith(color: colors.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
