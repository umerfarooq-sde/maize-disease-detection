import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

class PlanningHeader extends StatelessWidget {
  const PlanningHeader({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });
  final String title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'FARM PLANNING',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(description, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}
