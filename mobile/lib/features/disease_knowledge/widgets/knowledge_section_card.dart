import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../data/models/knowledge.dart';

class KnowledgeSectionCard extends StatelessWidget {
  const KnowledgeSectionCard({required this.section, super.key});
  final KnowledgeSection section;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            SelectableText(section.content),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Source · document v${section.version}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            SourceReferenceCard(reference: section.source),
          ],
        ),
      ),
    );
  }
}
