import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/fertilizer_models.dart';
import '../../tools/widgets/planning_disclosure.dart';
import '../../tools/widgets/planning_result_summary.dart';
import 'fertilizer_source.dart';

class FertilizerResultCard extends StatelessWidget {
  const FertilizerResultCard({required this.result, super.key});
  final FertilizerResult result;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PlanningResultSummary(
        title: 'Calculated fertilizer amount',
        quantity: '${result.quantity.value} ${result.quantity.unit.label}',
        product: result.rule.fertilizer.name,
        area:
            'For ${result.input.area} ${result.input.areaUnit.label.toLowerCase()}',
        quantityKey: const Key('fertilizer-result-quantity'),
      ),
      const SizedBox(height: AppSpacing.md),
      PlanningDisclosure(
        title: 'Fertilizer calculation details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Area in hectares: ${result.normalizedArea.value}'),
            const SizedBox(height: AppSpacing.md),
            SelectableText(result.explanation),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Rounded to ${result.rounding.decimalPlaces} decimal places (half up). A displayed zero can result from rounding a positive quantity.',
            ),
            Text(
              'Before rounding: ${result.quantity.unroundedValue} ${result.quantity.unit.label}',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Calculation assumptions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final assumption in result.assumptions)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('• $assumption'),
              ),
            const SizedBox(height: AppSpacing.lg),
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
            Text(result.unitReference.title),
            SelectableText(result.unitReference.url.toString()),
          ],
        ),
      ),
    ],
  );
}
