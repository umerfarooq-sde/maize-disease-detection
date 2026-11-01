import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.tone,
    this.tint,
    this.descriptionMaxLines,
    super.key,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tone;
  final Color? tint;
  final int? descriptionMaxLines;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final resolvedTone = tone ?? semantic.info;
    final resolvedTint = tint ?? semantic.infoContainer;
    return Semantics(
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(16) > 24;
                final symbol = Container(
                  width: AppSizing.iconTile,
                  height: AppSizing.iconTile,
                  decoration: BoxDecoration(
                    color: resolvedTint,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Icon(icon, color: resolvedTone),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      maxLines: descriptionMaxLines,
                      overflow: descriptionMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          symbol,
                          const Spacer(),
                          const Icon(Icons.arrow_forward, size: AppSizing.icon),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      copy,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    symbol,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: copy),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.arrow_forward, size: AppSizing.icon),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
