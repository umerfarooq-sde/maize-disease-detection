import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_prediction.dart';
import '../utils/scan_presentation.dart';

class PredictionSummary extends StatelessWidget {
  const PredictionSummary({required this.prediction, super.key});
  final ScanPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final uncertain =
        prediction.predictionStatus == ScanPredictionStatus.lowConfidence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Predicted label', style: text.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          diseaseLabel(prediction.predictedClass),
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Model score: ${modelScore(prediction.confidence)}',
          style: text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'This score reflects the classifier output. It is not the probability that the diagnosis is correct.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          color: uncertain ? AppColors.wheat : AppColors.mist,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  uncertain ? Icons.warning_amber_outlined : Icons.info_outline,
                  color: uncertain ? AppColors.amber : AppColors.blue,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  uncertain ? 'Uncertain result' : 'Threshold met',
                  style: text.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(switch (prediction.uncertaintyReason) {
                  ScanUncertaintyReason.thresholdUnconfigured =>
                    'A confidence policy has not been approved for this model. The result remains uncertain even when the model score is high.',
                  ScanUncertaintyReason.belowValidationThreshold =>
                    'The model score is below its validation-based confidence threshold. Do not treat this label as a certain diagnosis.',
                  null =>
                    'The score meets the configured threshold. This is a model prediction, not a confirmed diagnosis.',
                }),
              ],
            ),
          ),
        ),
        if (prediction.predictedClass == 'Healthy') ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'A Healthy prediction does not rule out other leaf problems.',
          ),
        ],
      ],
    );
  }
}
