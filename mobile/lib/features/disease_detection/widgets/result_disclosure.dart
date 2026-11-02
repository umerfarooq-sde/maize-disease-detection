import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

class ResultDisclosure extends StatelessWidget {
  const ResultDisclosure({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    );
    return ExpansionTile(
      key: PageStorageKey('result-disclosure-$title'),
      shape: shape,
      collapsedShape: shape,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      collapsedBackgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerLow,
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      expansionAnimationStyle: AnimationStyle(
        duration: AppMotion.resolve(context, AppMotion.reveal),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      children: [SizedBox(width: double.infinity, child: child)],
    );
  }
}
