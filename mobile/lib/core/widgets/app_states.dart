import 'package:flutter/material.dart';
import '../exceptions/app_exception.dart';
import '../theme/design_tokens.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({this.message = 'Loading…', super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: AppSizing.stateIcon,
          height: AppSizing.stateIcon,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(message, textAlign: TextAlign.center),
      ],
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(icon, size: AppSizing.stateIcon, color: AppColors.muted),
      const SizedBox(height: AppSpacing.lg),
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
        ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
      ),
      if (action != null) ...[const SizedBox(height: AppSpacing.xl), action!],
    ],
  );
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
