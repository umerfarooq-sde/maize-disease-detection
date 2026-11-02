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
    final healthy = disease.slug == 'healthy';
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: healthy
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Icon(
                      healthy ? Icons.spa_outlined : Icons.eco_outlined,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      healthy ? 'Healthy / scouting' : 'Knowledge entry',
                      style: text.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(disease.name, style: text.titleLarge),
              ),
              if (disease.scientificName case final name?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
                  style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
              if (disease.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  disease.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
