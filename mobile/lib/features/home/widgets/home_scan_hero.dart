import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';

class HomeScanHero extends StatelessWidget {
  const HomeScanHero({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final semantic = context.semanticColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: semantic.hero,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Check your maize health',
                    style: text.headlineSmall?.copyWith(color: semantic.onHero),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ExcludeSemantics(
                child: Icon(
                  Icons.grass,
                  size: AppSizing.stateIcon,
                  color: AppColors.highlight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose one clear leaf photo for a model prediction.',
            style: text.bodyMedium?.copyWith(color: semantic.onHero),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('scan-leaf-action'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.highlight,
              foregroundColor: AppColors.forest,
            ),
            onPressed: () => context.go(AppRoutes.scan),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan a maize leaf'),
          ),
        ],
      ),
    );
  }
}
