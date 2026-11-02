import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/feature_card.dart';

class ToolsView extends StatelessWidget {
  const ToolsView({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    storageKey: 'tools',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PLAN WITH CONTEXT',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: Text(
            'Tools for your field',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Explore fertilizer and yield planning with reviewed rules.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ResponsivePair(
          first: FeatureCard(
            title: 'Fertilizer planning',
            description:
                'Scale a reviewed product rate to your cultivated area. Review rule availability inside.',
            icon: Icons.grass_outlined,
            onTap: () => context.push(AppRoutes.fertilizer),
          ),
          second: FeatureCard(
            title: 'Yield planning',
            description:
                'Explore a conditional area-based planning estimate. Review scenario availability inside.',
            icon: Icons.bar_chart_outlined,
            onTap: () => context.push(AppRoutes.yieldCalculator),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text(
                    'Calculations need active reviewed configurations. These tools do not infer soil nutrient needs or guarantee a harvest.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
