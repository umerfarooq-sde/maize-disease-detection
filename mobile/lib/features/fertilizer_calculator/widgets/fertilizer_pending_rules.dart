import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

class FertilizerPendingRules extends StatelessWidget {
  const FertilizerPendingRules({required this.onReload, super.key});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.wheat,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.fact_check_outlined,
            color: AppColors.amber,
            size: AppSizing.stateIcon,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Approved fertilizer rules are pending',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'No source-reviewed dosage rule is available for calculation. '
            'You can edit your field details, but no fertilizer quantity will '
            'be calculated until an administrator publishes an approved rule.',
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const Key('fertilizer-reload-rules'),
            onPressed: onReload,
            icon: const Icon(Icons.refresh),
            label: const Text('Check for approved rules'),
          ),
        ],
      ),
    ),
  );
}
