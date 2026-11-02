import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/assistant_answer.dart';
import '../../../data/models/scan_prediction.dart';
import '../../disease_detection/utils/scan_presentation.dart';
import 'assistant_source_card.dart';

class AssistantAnswerCard extends StatefulWidget {
  const AssistantAnswerCard({required this.answer, super.key});
  final AssistantAnswer answer;

  @override
  State<AssistantAnswerCard> createState() => _AssistantAnswerCardState();
}

class _AssistantAnswerCardState extends State<AssistantAnswerCard> {
  final _sources = <String, GlobalKey>{};
  AssistantAnswer get answer => widget.answer;

  void _showSource(String id) {
    final target = _sources[id]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: AppMotion.resolve(context, AppMotion.navigation),
        alignment: 0.05,
      );
    }
  }

  Future<void> _copy() async {
    final text = [
      answer.message,
      for (final warning in answer.warnings) warning,
      for (final section in answer.sections) ...[
        section.heading,
        for (final item in section.items)
          '${item.text}\nSources: ${item.sourceIds.join(', ')}',
      ],
      for (final source in answer.sources)
        '${source.id} · ${source.reference.title} · document v${source.documentVersion}\n${source.reference.url}',
    ].join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Answer and source references copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grounded = answer.status == AssistantAnswerStatus.grounded;
    return Semantics(
      label: 'AI Assistant response',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(switch (answer.status) {
                  AssistantAnswerStatus.grounded => 'From reviewed knowledge',
                  AssistantAnswerStatus.insufficientInformation =>
                    'More evidence is needed',
                  AssistantAnswerStatus.outOfScope =>
                    'Outside supported topics',
                  AssistantAnswerStatus.conflictingEvidence =>
                    'The sources need review',
                }, style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(answer.message),
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.semanticColors.warning,
                    ),
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
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final id in item.sourceIds)
                        TextButton.icon(
                          onPressed: () => _showSource(id),
                          icon: const Icon(Icons.format_quote),
                          label: Text('Sources: $id'),
                        ),
                    ],
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
                  AssistantSourceCard(
                    key: _sources.putIfAbsent(source.id, GlobalKey.new),
                    source: source,
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('assistant-copy-answer'),
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy answer with sources'),
                ),
              ),
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
      color: context.semanticColors.warningContainer,
      borderRadius: BorderRadius.circular(AppRadii.small),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: context.semanticColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: context.semanticColors.onWarningContainer),
          ),
        ),
      ],
    ),
  );
}
