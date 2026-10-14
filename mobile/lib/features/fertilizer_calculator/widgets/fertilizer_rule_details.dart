import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/fertilizer_models.dart';
import 'fertilizer_source.dart';

class FertilizerRuleDetails extends StatelessWidget {
  const FertilizerRuleDetails({required this.rule, super.key});

  final FertilizerRule rule;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Selected rule', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(rule.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Product: ${rule.fertilizer.name}'),
          Text(
            'Approved product rate: ${rule.rateKgPerHectare} kg per hectare',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'When this rule applies',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(rule.applicability),
          const SizedBox(height: AppSpacing.lg),
          Text('Assumptions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final assumption in rule.assumptions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('• $assumption'),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text('Rule ${rule.ruleKey} · version ${rule.version}'),
          Text(
            'Calculator ${rule.config.key} · version ${rule.config.version}',
          ),
          const SizedBox(height: AppSpacing.lg),
          FertilizerSource(
            title: rule.source.title,
            publisher: rule.source.publisher,
            url: rule.source.url.toString(),
            citation: rule.source.citation,
          ),
        ],
      ),
    ),
  );
}
