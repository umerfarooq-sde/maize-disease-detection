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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            kToolbarHeight * MediaQuery.textScalerOf(context).scale(1),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: const Icon(Icons.eco_outlined, color: AppColors.forest),
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
                Expanded(child: navigation),
              ],
            )
          : navigation,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: AppSizing.navigationHeight,
              selectedIndex: navigation.currentIndex,
              onDestinationSelected: _select,
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
