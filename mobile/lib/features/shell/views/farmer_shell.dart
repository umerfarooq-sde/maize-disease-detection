import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';

class FarmerShell extends StatelessWidget {
  const FarmerShell({required this.navigation, super.key});
  final StatefulNavigationShell navigation;
  static const _areas = [
    (label: 'Home', icon: Icons.home_outlined, selected: Icons.home),
    (
      label: 'Scan',
      icon: Icons.document_scanner_outlined,
      selected: Icons.document_scanner,
    ),
    (
      label: 'Knowledge',
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book,
    ),
    (label: 'Tools', icon: Icons.grid_view_outlined, selected: Icons.grid_view),
    (label: 'Profile', icon: Icons.person_outline, selected: Icons.person),
  ];

  void _select(int index) => navigation.goBranch(
    index,
    initialLocation: index == navigation.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.useRail(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final content = _BranchTransition(
      branch: navigation.currentIndex,
      child: navigation,
    );
    return Scaffold(
      appBar: keyboardOpen
          ? null
          : AppBar(
              toolbarHeight: kToolbarHeight * textScale.clamp(1, 1.5),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Icon(
                      Icons.eco_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(child: Text(AppConstants.name)),
                ],
              ),
            ),
      body: wide
          ? Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    minWidth: AppSizing.railWidth,
                    scrollable: true,
                    selectedIndex: navigation.currentIndex,
                    onDestinationSelected: _select,
                    labelType:
                        MediaQuery.textScalerOf(context).scale(1) >
                            AppSizing.comfortableTextScale
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: [
                      for (final area in _areas)
                        NavigationRailDestination(
                          icon: Tooltip(
                            message: area.label,
                            child: Icon(area.icon),
                          ),
                          selectedIcon: Icon(area.selected),
                          label: Text(area.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: AppSizing.divider),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide || keyboardOpen
          ? null
          : NavigationBar(
              // Five actions remain reachable at 320dp and at large text size.
              // Hiding unselected captions avoids forcing their text into 64dp.
              height: Responsive.compactNavigation(context)
                  ? AppSizing.navigationHeight
                  : AppSizing.navigationHeight + AppSpacing.sm,
              selectedIndex: navigation.currentIndex,
              onDestinationSelected: _select,
              labelBehavior: Responsive.compactNavigation(context)
                  ? NavigationDestinationLabelBehavior.alwaysHide
                  : NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final area in _areas)
                  NavigationDestination(
                    icon: Icon(area.icon),
                    selectedIcon: Icon(area.selected),
                    label: area.label,
                    tooltip: area.label == 'Scan' ? 'Scan Leaf' : area.label,
                  ),
              ],
            ),
    );
  }
}

class _BranchTransition extends StatelessWidget {
  const _BranchTransition({required this.branch, required this.child});

  final int branch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(branch),
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: 0.92 + (0.08 * value),
        child: Transform.translate(
          offset: Offset(8 * (1 - value), 0),
          child: child,
        ),
      ),
    );
  }
}
