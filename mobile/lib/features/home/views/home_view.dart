import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/feature_card.dart';
import 'connection_card.dart';
import '../view_models/home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppPage(
      storageKey: 'home',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR FIELD COMPANION',
            style: text.labelMedium?.copyWith(
              color: AppColors.muted,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Better care.\nOne leaf at a time.',
            style:
                MediaQuery.sizeOf(context).width < AppSizing.compactBreakpoint
                ? text.headlineMedium
                : text.displaySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A clearer path to understanding your maize.',
            style: text.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _ScanHero(),
          const SizedBox(height: AppSpacing.xxl),
          Text('Explore your companion', style: text.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          ResponsivePair(
            first: FeatureCard(
              title: 'Maize knowledge',
              description: 'A home for trusted disease information.',
              icon: Icons.menu_book_outlined,
              onTap: () => context.go(AppRoutes.knowledge),
            ),
            second: FeatureCard(
              title: 'Field tools',
              description: 'Fertilizer and yield planning, in one place.',
              icon: Icons.grid_view_outlined,
              tone: AppColors.amber,
              tint: AppColors.wheat,
              onTap: () => context.go(AppRoutes.tools),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Consumer<HomeViewModel>(
            builder: (context, model, _) => ConnectionCard(model: model),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero();
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.forestDark,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined, color: AppColors.wheat),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Scan your maize',
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Leaf scanning is coming soon. Explore your starting point.',
            style: text.bodyMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('scan-leaf-action'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.wheat,
              foregroundColor: AppColors.forestDark,
            ),
            onPressed: () => context.go(AppRoutes.scan),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan Leaf'),
          ),
        ],
      ),
    );
  }
}
