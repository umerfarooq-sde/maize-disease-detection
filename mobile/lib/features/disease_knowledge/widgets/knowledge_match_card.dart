import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/source_reference_card.dart';
import '../../../data/models/knowledge.dart';
import '../utils/knowledge_presentation.dart';

class KnowledgeMatchCard extends StatelessWidget {
  const KnowledgeMatchCard({
    required this.match,
    required this.onOpen,
    super.key,
  });
  final KnowledgeMatch match;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetadataBadge(
                label: knowledgeTypeLabel(match.section.knowledgeType),
              ),
              _MetadataBadge(label: 'Document v${match.section.version}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            match.section.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(match.section.content),
          const SizedBox(height: AppSpacing.xl),
          SourceReferenceCard(reference: match.section.source),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Open catalogue details'),
          ),
        ],
      ),
    ),
  );
}

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    ),
  );
}
