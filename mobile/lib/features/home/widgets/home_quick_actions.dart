import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({this.vertical = false, super.key});
  final bool vertical;

  static const _actions = [
    (
      key: 'home-learn',
      label: 'Disease library',
      icon: Icons.menu_book_outlined,
      route: AppRoutes.knowledge,
    ),
    (
      key: 'home-assistant',
      label: 'AI Assistant',
      icon: Icons.chat_bubble_outline,
      route: AppRoutes.assistant,
    ),
    (
      key: 'home-tools',
      label: 'Farm tools',
      icon: Icons.grid_view_outlined,
      route: AppRoutes.tools,
    ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          vertical ||
          MediaQuery.textScalerOf(context).scale(1) >
              AppSizing.comfortableTextScale;
      final colors = Theme.of(context).colorScheme;
      final tiles = [
        for (final action in _actions)
          Semantics(
            button: true,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key(action.key),
                onTap: () => context.go(action.route),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: stacked
                      ? Row(
                          children: [
                            Icon(action.icon, color: colors.primary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                action.label,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        )
                      : Column(
                          children: [
                            Icon(action.icon, color: colors.primary),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              action.label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
      ];
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < tiles.length; index++) ...[
              tiles[index],
              if (index < tiles.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < tiles.length; index++) ...[
              Expanded(child: tiles[index]),
              if (index < tiles.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      );
    },
  );
}
