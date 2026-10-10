import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_prediction.dart';
import '../../../data/models/scan_record.dart';
import '../../disease_detection/utils/scan_presentation.dart';

class HistoryScanTile extends StatelessWidget {
  const HistoryScanTile({required this.scan, this.onOpen, super.key});
  final ScanRecord scan;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                child: Image.network(
                  scan.imageUrl.toString(),
                  width: AppSizing.emblem,
                  height: AppSizing.emblem,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => Container(
                    width: AppSizing.emblem,
                    height: AppSizing.emblem,
                    color: AppColors.sage,
                    child: const Icon(
                      Icons.eco_outlined,
                      color: AppColors.forest,
                    ),
                  ),
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
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (prediction != null) ...[
                      Text('Model score: ${modelScore(prediction.confidence)}'),
                      Text(
                        'Model: ${prediction.modelVersion}',
                        style: text.bodySmall,
                      ),
                      if (uncertain)
                        Text(
                          'Uncertain result',
                          style: text.labelLarge?.copyWith(
                            color: AppColors.amber,
                          ),
                        ),
                    ],
                    if (scan.status == ScanStatus.failed)
                      const Text(
                        'Your photo is saved. Open the scan for details.',
                      ),
                    if (onOpen != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'View scan',
                        style: text.labelLarge?.copyWith(
                          color: AppColors.forest,
                        ),
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
