import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Keeps precise server values and evidence available below the main result.
class PlanningDisclosure extends StatelessWidget {
  const PlanningDisclosure({
    required this.title,
    required this.child,
    super.key,
  });
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: PageStorageKey('planning-$title'),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      tilePadding: const EdgeInsets.all(AppSpacing.lg),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      expansionAnimationStyle: AnimationStyle(
        duration: AppMotion.resolve(context, AppMotion.reveal),
      ),
      children: [
        KeyedSubtree(
          key: PageStorageKey('planning-content-$title'),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ],
    ),
  );
}
