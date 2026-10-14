import 'package:flutter/material.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_states.dart';

class FertilizerCalculationError extends StatelessWidget {
  const FertilizerCalculationError({
    required this.error,
    this.onRetry,
    super.key,
  });

  final AppException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final staleRule =
        error.kind == AppErrorKind.conflict ||
        error.kind == AppErrorKind.notFound;
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppEmptyState(
            title: staleRule
                ? 'Review the approved rule'
                : 'The calculation could not be completed',
            message: staleRule
                ? 'The selected rule is no longer current. Refresh the rules '
                      'and review their assumptions before calculating again.'
                : error.message,
            icon: Icons.info_outline,
            action: onRetry == null
                ? null
                : OutlinedButton.icon(
                    key: const Key('fertilizer-calculation-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      staleRule ? 'Refresh approved rules' : 'Try again',
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
