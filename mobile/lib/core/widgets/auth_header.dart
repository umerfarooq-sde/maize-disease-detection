import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'brand_mark.dart';

/// Shared presentation only; Farmer and Admin retain separate session owners.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    required this.description,
    this.admin = false,
    super.key,
  });
  final String title, description;
  final bool admin;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const BrandMark(size: AppSizing.emblem),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAIZEDOCTOR',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  admin ? 'PRIVATE WORKSPACE' : 'FIELD INTELLIGENCE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xxl),
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        description,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
