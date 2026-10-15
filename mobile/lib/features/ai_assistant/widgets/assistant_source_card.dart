import 'package:flutter/material.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../data/models/assistant_answer.dart';

class AssistantSourceCard extends StatelessWidget {
  const AssistantSourceCard({required this.source, super.key});
  final AssistantCitation source;

  @override
  Widget build(BuildContext context) => SourceReferenceCard(
    key: ValueKey('assistant-source-${source.id}'),
    reference: source.reference,
    citationLabel: source.id,
  );
}
