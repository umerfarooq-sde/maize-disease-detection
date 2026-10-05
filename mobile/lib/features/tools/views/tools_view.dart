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
          'Tools for your field',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Planning tools are coming soon. Explore what is being prepared.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ResponsivePair(
          first: FeatureCard(
            title: 'Fertilizer planning',
            description: 'A place for reliable nutrient calculations.',
            icon: Icons.grass_outlined,
            tone: AppColors.amber,
            tint: AppColors.wheat,
            onTap: () => context.push(AppRoutes.fertilizer),
          ),
          second: FeatureCard(
            title: 'Yield planning',
            description: 'A place for clear, consistent estimates.',
            icon: Icons.bar_chart_outlined,
            onTap: () => context.push(AppRoutes.yieldCalculator),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FeatureCard(
          title: 'Ask your assistant',
          description:
              'Grounded guidance, when trusted knowledge is available.',
          icon: Icons.chat_bubble_outline,
          onTap: () => context.push(AppRoutes.assistant),
        ),
      ],
    ),
  );
}
