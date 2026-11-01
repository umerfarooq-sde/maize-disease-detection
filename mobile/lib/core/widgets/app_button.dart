import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum AppButtonVariant { primary, secondary, tonal, destructive }

/// Material controls retain their keyboard, focus and disabled semantics.
/// Loading is explicit caller-owned presentation state, never a timed effect.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final action = loading ? null : onPressed;
    final destructive = variant == AppButtonVariant.destructive;
    final content = Text(loading ? loadingLabel ?? label : label);
    final leading = loading
        ? ExcludeSemantics(
            child: SizedBox.square(
              dimension: AppSizing.icon,
              child: MediaQuery.disableAnimationsOf(context)
                  ? const Icon(Icons.hourglass_top)
                  : CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSurfaceVariant,
                    ),
            ),
          )
        : icon == null
        ? null
        : Icon(icon);
    final style = destructive
        ? FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          )
        : null;
    final button = switch (variant) {
      AppButtonVariant.secondary =>
        leading == null
            ? OutlinedButton(onPressed: action, child: content)
            : OutlinedButton.icon(
                onPressed: action,
                icon: leading,
                label: content,
              ),
      AppButtonVariant.tonal => FilledButton.tonalIcon(
        onPressed: action,
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizing.touchTarget, AppSizing.touchTarget),
        ),
        icon: leading,
        label: content,
      ),
      _ =>
        leading == null
            ? FilledButton(onPressed: action, style: style, child: content)
            : FilledButton.icon(
                onPressed: action,
                style: style,
                icon: leading,
                label: content,
              ),
    };
    return Semantics(liveRegion: loading, child: button);
  }
}
