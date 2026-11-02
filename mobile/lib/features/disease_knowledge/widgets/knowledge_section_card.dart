import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../data/models/knowledge.dart';
import '../utils/knowledge_presentation.dart';

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
            Text(
              knowledgeTypeLabel(section.knowledgeType),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              header: true,
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              section.content,
              key: PageStorageKey('section-text-${section.documentId}'),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Source attribution · document version ${section.version}',
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
