import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'app_page.dart';
import 'app_states.dart';

/// Honest unavailable states for routed feature areas whose workflows come later.
class FeatureIntro extends StatelessWidget {
  const FeatureIntro({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.message,
    this.tone,
    this.tint,
    super.key,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String message;
  final Color? tone;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: tint ?? semantic.infoContainer,
              borderRadius: BorderRadius.circular(AppRadii.hero),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: AppSizing.emblem,
                  color: tone ?? semantic.info,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Coming soon',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppEmptyState(
            title: 'This area is getting ready',
            message: message,
            icon: icon,
          ),
        ],
      ),
    );
  }
}
