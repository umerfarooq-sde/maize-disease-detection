import 'package:flutter/material.dart';
import '../../data/models/assistant_answer.dart';
import '../theme/design_tokens.dart';

/// Plain, selectable provenance reused by reviewed answers and knowledge pages.
class SourceReferenceCard extends StatelessWidget {
  const SourceReferenceCard({
    required this.reference,
    this.citationLabel,
    super.key,
  });
  final AssistantSourceReference reference;
  final String? citationLabel;
  String _date(DateTime value) => value.toIso8601String().split('T').first;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.canvas,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(AppRadii.small),
    ),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          citationLabel == null
              ? reference.title
              : '$citationLabel · ${reference.title}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(reference.publisher),
        if (reference.authors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(reference.authors.join(', ')),
        ],
        if (reference.publishedAt case final published?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Published ${_date(published)}'),
        ],
        const SizedBox(height: AppSpacing.sm),
        SelectableText(
          reference.url.toString(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.blue),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Source checked ${_date(reference.retrievedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(reference.rights, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
