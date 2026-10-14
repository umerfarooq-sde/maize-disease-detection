import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/assistant_answer.dart';
import '../../../data/models/scan_prediction.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import 'assistant_source_card.dart';

class AssistantAnswerCard extends StatelessWidget {
  const AssistantAnswerCard({required this.answer, super.key});
  final AssistantAnswer answer;

  @override
  Widget build(BuildContext context) {
    final grounded = answer.status == AssistantAnswerStatus.grounded;
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (answer.status) {
                AssistantAnswerStatus.grounded => 'From reviewed knowledge',
                AssistantAnswerStatus.insufficientInformation =>
                  'More evidence is needed',
                AssistantAnswerStatus.outOfScope => 'Outside supported topics',
                AssistantAnswerStatus.conflictingEvidence =>
                  'The sources need review',
              }, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(answer.message),
              if (answer.classifierPrediction case final prediction?) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Model prediction: ${diseaseLabel(prediction.predictedClass)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Model score: ${modelScore(prediction.confidence)}'),
                if (prediction.predictionStatus ==
                    ScanPredictionStatus.lowConfidence) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Low-confidence model result',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.amber),
                  ),
                ],
              ],
              for (final warning in answer.warnings) ...[
                const SizedBox(height: AppSpacing.md),
                _Warning(message: warning),
              ],
              for (final section in answer.sections) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  section.heading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final item in section.items) ...[
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(item.text),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sources: ${item.sourceIds.join(', ')}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ],
              if (grounded && answer.sources.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'References',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final source in answer.sources) ...[
                  const SizedBox(height: AppSpacing.md),
                  AssistantSourceCard(source: source),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.wheat,
      borderRadius: BorderRadius.circular(AppRadii.small),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.amber),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
