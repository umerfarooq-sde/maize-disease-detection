import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_cards.dart';
import '../../../data/models/admin_dashboard.dart';
import 'package:go_router/go_router.dart';

class AdminSystemSummary extends StatelessWidget {
  const AdminSystemSummary({required this.data, super.key});
  final AdminDashboard data;
  @override
  Widget build(BuildContext context) => AppStatusPanel(
    tone: data.registry == 'MULTIPLE_PRODUCTION'
        ? AppStatusTone.warning
        : AppStatusTone.information,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'System summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(switch (data.registry) {
          'SINGLE_PRODUCTION' =>
            'Production registry: ${data.productionVersion}',
          'MULTIPLE_PRODUCTION' =>
            'Production registry conflict: multiple versions are marked production.',
          _ => 'Production registry: no model has been promoted.',
        }),
        const SizedBox(height: AppSpacing.sm),
        Text(
          data.inferenceConfigured
              ? 'Configured inference version: ${data.configuredVersion}'
              : 'Inference is not configured.',
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Live model readiness has not been checked. Registry status and configuration do not prove availability.',
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Offline model evaluation remains separate from runtime requests.',
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.go('${AppRoutes.admin}/model-health'),
          icon: const Icon(Icons.monitor_heart_outlined),
          label: const Text('Open Model Health'),
        ),
      ],
    ),
  );
}
