import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/yield_models.dart';

class YieldConfigurationDetails extends StatelessWidget {
  const YieldConfigurationDetails({
    required this.configuration,
    this.showAssumptions = true,
    super.key,
  });
  final YieldConfiguration configuration;
  final bool showAssumptions;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            configuration.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reviewed scenario: ${configuration.expectedYieldKgPerHectare} kg per hectare',
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Applies when', style: Theme.of(context).textTheme.titleMedium),
          Text(configuration.applicability),
          if (showAssumptions) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Scenario assumptions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final assumption in configuration.assumptions)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('• $assumption'),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Source', style: Theme.of(context).textTheme.titleMedium),
          Text(configuration.source.title),
          Text(configuration.source.publisher),
          SelectableText(configuration.source.url.toString()),
          Text(configuration.source.citation),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Configuration ${configuration.configKey} · version ${configuration.version}',
          ),
          Text('Formula: $yieldFormulaVersion'),
        ],
      ),
    ),
  );
}

class YieldResultCard extends StatelessWidget {
  const YieldResultCard({required this.result, super.key});
  final YieldResult result;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: AppColors.mist,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Expected yield · planning estimate',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${result.value} ${result.input.outputUnit.label}',
                  key: const Key('yield-result-quantity'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'For ${result.input.area} ${result.input.areaUnit.label.toLowerCase()}',
                ),
                Text('Area in hectares: ${result.normalizedArea}'),
                const SizedBox(height: AppSpacing.md),
                Text(result.explanation),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Before rounding: ${result.unroundedValue} ${result.input.outputUnit.label}',
                ),
                Text(
                  'Rounded to ${result.configuration.decimalPlaces} decimal places (half up).',
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
                Text('Calculation engine: $yieldEngineVersion'),
                Text(result.unitReferenceTitle),
                SelectableText(result.unitReferenceUrl.toString()),
              ],
            ),
          ),
        ),
        YieldConfigurationDetails(
          configuration: result.configuration,
          showAssumptions: false,
        ),
      ],
    ),
  );
}
