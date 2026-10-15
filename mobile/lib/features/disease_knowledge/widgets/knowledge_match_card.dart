import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/knowledge.dart';

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
          Text(
            match.section.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(match.section.content),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${match.section.source.publisher} · document v${match.section.version}',
          ),
          SelectableText(match.section.source.url.toString()),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onOpen,
            child: const Text('Open catalogue details'),
          ),
        ],
      ),
    ),
  );
}
