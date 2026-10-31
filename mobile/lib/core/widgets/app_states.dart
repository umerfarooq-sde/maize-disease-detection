import 'package:flutter/material.dart';
import '../exceptions/app_exception.dart';
import '../theme/design_tokens.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({this.message = 'Loading…', super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: _StateLayout(
      icon: const SizedBox.square(
        dimension: AppSizing.stateIcon,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _StateLayout(
      icon: Icon(
        icon,
        size: AppSizing.stateIcon,
        color: colors.onSurfaceVariant,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Center(child: action!),
          ],
        ],
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({required this.error, required this.onRetry, super.key});
  final AppException error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AppEmptyState(
      title: 'Something needs attention',
      message: error.message,
      icon: Icons.cloud_off_outlined,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Try again'),
      ),
    ),
  );
}

class AppSuccessState extends StatelessWidget {
  const AppSuccessState({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return Semantics(
      liveRegion: true,
      child: _StateLayout(
        icon: Icon(
          Icons.check_circle_outline,
          size: AppSizing.stateIcon,
          color: semantic.success,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({required this.icon, required this.child});

  final Widget icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}
