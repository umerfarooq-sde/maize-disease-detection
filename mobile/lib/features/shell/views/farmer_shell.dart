import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../auth/view_models/farmer_session_view_model.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';

class FarmerShell extends StatelessWidget {
  const FarmerShell({required this.navigation, super.key});
  final StatefulNavigationShell navigation;
  static const _areas = [
    (label: 'Home', icon: Icons.home_outlined, selected: Icons.home),
    (label: 'Learn', icon: Icons.menu_book_outlined, selected: Icons.menu_book),
    (
      label: 'Scan',
      icon: Icons.document_scanner_outlined,
      selected: Icons.document_scanner,
    ),
    (
      label: 'AI Assistant',
      icon: Icons.chat_bubble_outline,
      selected: Icons.chat_bubble,
    ),
    (label: 'Tools', icon: Icons.grid_view_outlined, selected: Icons.grid_view),
  ];

  void _select(int index) {
    // Reselecting a primary destination must not discard its stack or draft.
    if (index != navigation.currentIndex) navigation.goBranch(index);
  }

  Widget _icon(BuildContext context, int index, {bool selected = false}) {
    final area = _areas[index];
    final icon = Icon(
      selected ? area.selected : area.icon,
      // NavigationDestination's tooltip is excluded from its spoken label.
      // Keep the full destination name when the visible caption is abbreviated.
      semanticLabel: index == 3 ? area.label : null,
    );
    if (index != 2) return icon;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: AppSizing.touchTarget,
      height: AppSizing.touchTarget,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Icon(area.selected, color: colors.onPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.useRail(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final content = _BranchTransition(
      branch: navigation.currentIndex,
      child: navigation,
    );
    final session = context.watch<FarmerSessionViewModel>();
    final email = session.account?.email;
    final narrow =
        MediaQuery.sizeOf(context).width < AppSizing.twoColumnBreakpoint ||
        Responsive.compactNavigation(context);
    final stackedBrand =
        textScale > AppSizing.comfortableTextScale &&
        MediaQuery.sizeOf(context).width < AppSizing.authenticationMaxWidth;
    return PopScope(
      canPop: navigation.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigation.currentIndex != 0) _select(0);
      },
      child: Scaffold(
        appBar: keyboardOpen
            ? null
            : AppBar(
                toolbarHeight: kToolbarHeight * textScale.clamp(1, 1.5),
                actions: [
                  IconButton(
                    key: const Key('open-profile'),
                    tooltip: session.signedIn
                        ? 'Your profile'
                        : 'Guest profile and sign-in',
                    onPressed: () => context.push(AppRoutes.profile),
                    icon: email == null
                        ? const Icon(Icons.account_circle_outlined)
                        : CircleAvatar(
                            radius: AppSpacing.lg,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            child: Text(
                              String.fromCharCode(
                                email.runes.first,
                              ).toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                title: Row(
                  children: [
                    const BrandMark(size: AppSizing.stateIcon),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Semantics(
                        label: AppConstants.name,
                        excludeSemantics: true,
                        child: Text(
                          stackedBrand ? 'MAIZE\nDOCTOR' : AppConstants.name,
                          style: stackedBrand
                              ? Theme.of(context).textTheme.labelLarge
                              : null,
                        ),
                      ),
                    ),
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
                        for (var index = 0; index < _areas.length; index++)
                          NavigationRailDestination(
                            icon: Tooltip(
                              message: _areas[index].label,
                              child: _icon(context, index),
                            ),
                            selectedIcon: _icon(context, index, selected: true),
                            label: Text(_areas[index].label),
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
                height: AppSizing.navigationHeight + AppSpacing.lg,
                animationDuration: AppMotion.resolve(
                  context,
                  AppMotion.navigation,
                ),
                selectedIndex: navigation.currentIndex,
                onDestinationSelected: _select,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: states.contains(WidgetState.selected)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                destinations: [
                  for (var index = 0; index < _areas.length; index++)
                    NavigationDestination(
                      key: ValueKey('farmer-tab-$index'),
                      icon: _icon(context, index),
                      selectedIcon: _icon(context, index, selected: true),
                      label: index == 3 && narrow ? 'AI' : _areas[index].label,
                      tooltip: index == 2 ? 'Scan Leaf' : _areas[index].label,
                    ),
                ],
              ),
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
      duration: AppMotion.resolve(context, AppMotion.navigation),
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
