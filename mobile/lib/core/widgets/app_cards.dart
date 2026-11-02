import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum AppStatusTone { neutral, information, warning, error, success }

/// Intrinsic rows adapt to local width and text size without fixed card heights.
class AppMetricGrid extends StatelessWidget {
  const AppMetricGrid({
    required this.children,
    this.minimumColumnWidth = AppSizing.emblem * 2,
    super.key,
  });
  final List<Widget> children;
  final double minimumColumnWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimum =
          minimumColumnWidth * MediaQuery.textScalerOf(context).scale(1);
      final columns =
          ((constraints.maxWidth + AppSpacing.md) / (minimum + AppSpacing.md))
              .floor()
              .clamp(1, 4);
      return Column(
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start != 0) const SizedBox(height: AppSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column != 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: start + column < children.length
                          ? children[start + column]
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

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
    this.icon,
    super.key,
  });
  final String label;
  final String? value;
  final String? unit;
  final String? note;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
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
