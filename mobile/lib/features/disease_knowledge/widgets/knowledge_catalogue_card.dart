import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/knowledge.dart';

class KnowledgeCatalogueCard extends StatelessWidget {
  const KnowledgeCatalogueCard({
    required this.disease,
    required this.onOpen,
    super.key,
  });

  final DiseaseSummary disease;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final healthy = disease.slug == 'healthy';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSizing.iconTile,
                height: AppSizing.iconTile,
                decoration: BoxDecoration(
                  color: healthy
                      ? context.semanticColors.successContainer
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(
                  healthy ? Icons.spa_outlined : Icons.menu_book_outlined,
                  color: healthy
                      ? context.semanticColors.onSuccessContainer
                      : colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (disease.scientificName case final name?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (disease.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        disease.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Read reviewed information',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: colors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
