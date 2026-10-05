import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/feature_card.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    storageKey: 'profile',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your field, your space',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'You are exploring as a guest.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: AppSizing.emblem,
                  color: AppColors.blue,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Make room for your progress',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Secure sign-in and a farmer profile will be available in a later update.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.auth),
                  child: const Text('About sign-in'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FeatureCard(
          title: 'Scan history',
          description: 'Your past leaf scans, once scanning is available.',
          icon: Icons.history,
          onTap: () => context.push(AppRoutes.history),
        ),
        const SizedBox(height: AppSpacing.lg),
        FeatureCard(
          title: 'Field insights',
          description: 'A future view of your crop activity.',
          icon: Icons.insights_outlined,
          tone: AppColors.amber,
          tint: AppColors.wheat,
          onTap: () => context.push(AppRoutes.analytics),
        ),
      ],
    ),
  );
}
