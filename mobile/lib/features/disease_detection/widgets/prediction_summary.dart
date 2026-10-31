import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/scan_prediction.dart';
import '../utils/scan_presentation.dart';

class PredictionSummary extends StatelessWidget {
  const PredictionSummary({
    required this.prediction,
    this.compact = false,
    super.key,
  });

  final ScanPrediction prediction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final uncertain =
        prediction.predictionStatus == ScanPredictionStatus.lowConfidence;
    final semantic = context.semanticColors;
    final entries = prediction.probabilities.entries.toList()
      ..sort((left, right) {
        final score = right.value.compareTo(left.value);
        if (score != 0) return score;
        return ScanPrediction.classLabels
            .indexOf(left.key)
            .compareTo(ScanPrediction.classLabels.indexOf(right.key));
      });
    final statusBackground = uncertain
        ? semantic.warningContainer
        : semantic.successContainer;
    final statusForeground = uncertain
        ? semantic.onWarningContainer
        : semantic.onSuccessContainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: uncertain
              ? 'Uncertain model result'
              : 'Configured confidence policy threshold met',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    uncertain
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: statusForeground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      uncertain ? 'Uncertain result' : 'Threshold met',
                      style: text.titleSmall?.copyWith(color: statusForeground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          uncertain ? 'Leading model output' : 'Model suggestion',
          style: text.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          diseaseLabel(prediction.predictedClass),
          key: const Key('prediction-leading-label'),
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Classifier score', style: text.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          modelScore(prediction.confidence),
          key: const Key('classifier-score'),
          style: text.headlineMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This is a raw softmax classifier output. It is not diagnostic accuracy and not the probability that this label is correct.',
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ConfidenceExplanation(prediction: prediction),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('All model scores', style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Four-class breakdown', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Relative model outputs across all supported classes, sorted highest first.',
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (index, entry) in entries.indexed) ...[
            _ProbabilityRow(
              key: ValueKey('probability-${entry.key}'),
              label: entry.key,
              probability: entry.value,
              leading: index == 0,
            ),
            if (index != entries.length - 1)
              const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.xl),
          _NextStep(prediction: prediction),
        ],
      ],
    );
  }
}

class _ConfidenceExplanation extends StatelessWidget {
  const _ConfidenceExplanation({required this.prediction});

  final ScanPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final uncertain =
        prediction.predictionStatus == ScanPredictionStatus.lowConfidence;
    final background = uncertain
        ? semantic.warningContainer
        : semantic.infoContainer;
    final foreground = uncertain
        ? semantic.onWarningContainer
        : semantic.onInfoContainer;
    final message = switch (prediction.uncertaintyReason) {
      ScanUncertaintyReason.thresholdUnconfigured =>
        'No validation-approved confidence threshold is configured for this model. The result must remain uncertain, even when its score is high.',
      ScanUncertaintyReason.belowValidationThreshold =>
        'The score is below the configured validation-based threshold. Do not treat this output as a certain diagnosis.',
      null =>
        'The score meets the configured validation-based threshold. This remains a model suggestion, not a confirmed diagnosis.',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (prediction.uncertaintyReason) {
              ScanUncertaintyReason.thresholdUnconfigured =>
                'Confidence threshold unavailable',
              ScanUncertaintyReason.belowValidationThreshold =>
                'Below confidence threshold',
              null => 'Configured policy applied',
            },
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: foreground),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: TextStyle(color: foreground)),
          if (prediction.confidenceThreshold case final threshold?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Policy threshold: ${modelScore(threshold)}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProbabilityRow extends StatelessWidget {
  const _ProbabilityRow({
    required this.label,
    required this.probability,
    required this.leading,
    super.key,
  });

  final String label;
  final double probability;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final readableLabel = diseaseLabel(label);
    final score = modelScore(probability);
    return Semantics(
      container: true,
      label:
          '$readableLabel, classifier output $score${leading ? ', highest output' : ''}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    readableLabel,
                    softWrap: true,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(score, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                key: ValueKey('prediction-score-$label'),
                value: probability,
                minHeight: AppSpacing.md,
                color: leading ? colors.primary : colors.secondary,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.prediction});

  final ScanPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final healthy = prediction.predictedClass == 'Healthy';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'What to do next',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Compare visible symptoms with reviewed maize knowledge or consult a qualified local adviser before making field decisions.',
          ),
          if (healthy) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'A Healthy model output does not rule out other leaf problems.',
            ),
          ],
        ],
      ),
    );
  }
}
