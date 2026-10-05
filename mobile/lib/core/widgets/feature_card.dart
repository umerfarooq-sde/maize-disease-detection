import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.tone = AppColors.blue,
    this.tint = AppColors.mist,
    super.key,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Color tone;
  final Color tint;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizing.iconTile,
              height: AppSizing.iconTile,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Icon(icon, color: tone),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.arrow_forward, size: AppSizing.icon),
          ],
        ),
      ),
    ),
  );
}
