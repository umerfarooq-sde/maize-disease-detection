import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/fertilizer_models.dart';
import 'fertilizer_source.dart';

class FertilizerResultCard extends StatelessWidget {
  const FertilizerResultCard({required this.result, super.key});

  final FertilizerResult result;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: AppColors.sage,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Calculated fertilizer amount',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(result.rule.fertilizer.name),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${result.quantity.value} ${result.quantity.unit.label}',
              key: const Key('fertilizer-result-quantity'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'For ${result.input.area} ${result.input.areaUnit.label.toLowerCase()}',
            ),
            Text('Area in hectares: ${result.normalizedArea.value}'),
            const SizedBox(height: AppSpacing.lg),
            Text(result.explanation),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Rounded to ${result.rounding.decimalPlaces} decimal places '
              '(half up). A displayed zero can result from rounding a positive quantity.',
            ),
            Text(
              'Before rounding: ${result.quantity.unroundedValue} ${result.quantity.unit.label}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Calculation assumptions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final assumption in result.assumptions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('• $assumption'),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Rule ${result.rule.ruleKey} · version ${result.rule.version}',
            ),
            Text(
              'Calculator ${result.rule.config.key} · version ${result.rule.config.version}',
            ),
            Text('Calculation engine: ${result.engineVersion}'),
            const SizedBox(height: AppSpacing.lg),
            FertilizerSource(
              title: result.rule.source.title,
              publisher: result.rule.source.publisher,
              url: result.rule.source.url.toString(),
              citation: result.rule.source.citation,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Unit conversion reference',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(result.unitReference.title),
            SelectableText(result.unitReference.url.toString()),
          ],
        ),
      ),
    ),
  );
}
