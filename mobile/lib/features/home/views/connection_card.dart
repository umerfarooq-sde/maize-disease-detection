import 'package:flutter/material.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../view_models/home_view_model.dart';

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({required this.model, super.key});
  final HomeViewModel model;
  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (model.isLoading) {
      content = const AppLoadingState(
        message: 'Checking connection…',
        inline: true,
      );
    } else if (model.error case final error?) {
      content = AppErrorState(error: error, onRetry: model.checkConnection);
    } else if (model.health?.isAvailable == false) {
      content = AppErrorState(
        error: const AppException(AppErrorKind.server),
        onRetry: model.checkConnection,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                model.health == null
                    ? Icons.cloud_outlined
                    : Icons.cloud_done_outlined,
                color: context.semanticColors.info,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  model.health == null
                      ? 'Service connection'
                      : 'Service connected',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            model.health == null
                ? 'Not checked yet.'
                : 'Reachable at the last check.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: model.checkConnection,
              icon: const Icon(Icons.refresh),
              label: Text(
                model.health == null ? 'Check connection' : 'Check again',
              ),
            ),
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      ),
    );
  }
}
