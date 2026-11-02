import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Formats no arithmetic: every value is supplied by the typed server result.
class PlanningResultSummary extends StatelessWidget {
  const PlanningResultSummary({
    required this.title,
    required this.quantity,
    required this.area,
    required this.quantityKey,
    this.product,
    super.key,
  });
  final String title, quantity, area;
  final String? product;
  final Key quantityKey;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (product != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(product!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            child: SelectableText(
              quantity,
              key: quantityKey,
              style: AppTypography.metric.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontFamily: AppTypography.family,
                fontFamilyFallback: AppTypography.fallback,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(area),
        ],
      ),
    ),
  );
}
