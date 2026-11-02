import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/assistant_answer.dart';
import '../theme/design_tokens.dart';

/// Plain, selectable provenance reused by reviewed answers and knowledge pages.
class SourceReferenceCard extends StatelessWidget {
  const SourceReferenceCard({
    required this.reference,
    this.citationLabel,
    this.documentVersion,
    super.key,
  });
  final AssistantSourceReference reference;
  final String? citationLabel;
  final int? documentVersion;
  String _date(DateTime value) => value.toIso8601String().split('T').first;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              citationLabel == null
                  ? reference.title
                  : '$citationLabel · ${reference.title}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(reference.publisher),
          if (documentVersion != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Document version $documentVersion'),
          ],
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
            ).textTheme.bodyMedium?.copyWith(color: colors.primary),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: reference.url.toString()),
                );
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('Source URL copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy source URL'),
            ),
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
}
