import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum AppStatusTone { neutral, information, warning, error, success }

/// Tone is supplied by the caller; this widget never infers business status.
class AppStatusPanel extends StatelessWidget {
  const AppStatusPanel({
    required this.child,
    this.tone = AppStatusTone.neutral,
    super.key,
  });
  final Widget child;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic =
        theme.extension<AppSemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.darkSemantics
            : AppColors.lightSemantics);
    final (background, foreground) = switch (tone) {
      AppStatusTone.neutral => (colors.surfaceContainerLow, colors.onSurface),
      AppStatusTone.information => (
        semantic.infoContainer,
        semantic.onInfoContainer,
      ),
      AppStatusTone.warning => (
        semantic.warningContainer,
        semantic.onWarningContainer,
      ),
      AppStatusTone.error => (colors.errorContainer, colors.onErrorContainer),
      AppStatusTone.success => (
        semantic.successContainer,
        semantic.onSuccessContainer,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: child,
        ),
      ),
    );
  }
}

/// Display-only metric. Null means unavailable; only an actual supplied zero is zero.
class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    required this.label,
    required this.value,
    this.unit,
    this.note,
    super.key,
  });
  final String label;
  final String? value;
  final String? unit;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value == null
                  ? 'Unavailable'
                  : '$value${unit == null ? '' : ' $unit'}',
              style: AppTypography.metric.copyWith(
                fontFamily: AppTypography.family,
                fontFamilyFallback: AppTypography.fallback,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(note!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
