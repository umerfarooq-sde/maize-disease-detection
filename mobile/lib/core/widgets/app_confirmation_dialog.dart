import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Consistent confirmation surface for sensitive and destructive actions.
Future<bool> showAppConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool useRootNavigator = true,
}) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (_) => LayoutBuilder(
        builder: (dialogContext, constraints) {
          final colors = Theme.of(dialogContext).colorScheme;
          final icon = Icon(
            destructive ? Icons.warning_amber_rounded : Icons.help_outline,
            color: destructive ? colors.error : colors.primary,
          );
          final actions = [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ];
          final media = MediaQuery.of(dialogContext);
          if (constraints.maxHeight -
                  media.viewInsets.vertical -
                  media.padding.vertical <
              AppSizing.navigationHeight * 4) {
            // On short windows/visible keyboards, title and actions must scroll too.
            return Dialog(
              insetPadding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    icon,
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(message),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.end,
                      children: actions,
                    ),
                  ],
                ),
              ),
            );
          }
          return AlertDialog(
            icon: icon,
            title: Text(title),
            content: SingleChildScrollView(child: Text(message)),
            actions: actions,
          );
        },
      ),
    ) ??
    false;
