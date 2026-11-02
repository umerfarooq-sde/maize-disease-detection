import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/admin_management.dart';

/// Presentation destinations. Management query values never reach the API.
enum AdminDestination {
  overview(
    'System Overview',
    'Overview',
    Icons.space_dashboard_outlined,
    '/admin',
  ),
  diseases(
    'Diseases',
    'Content Management',
    Icons.eco_outlined,
    '/admin/manage?area=diseases',
    ManagementArea.diseases,
  ),
  knowledge(
    'Knowledge Documents',
    'Content Management',
    Icons.menu_book_outlined,
    '/admin/manage?area=knowledge',
    ManagementArea.knowledge,
  ),
  references(
    'Reference Images',
    'Content Management',
    Icons.photo_library_outlined,
    '/admin/reference-images',
  ),
  products(
    'Fertilizer Catalogue',
    'Calculator Management',
    Icons.inventory_2_outlined,
    '/admin/manage?area=fertilizers',
    ManagementArea.fertilizers,
  ),
  fertilizer(
    'Fertilizer Rules',
    'Calculator Management',
    Icons.grass_outlined,
    '/admin/manage?area=fertilizer',
    ManagementArea.fertilizer,
  ),
  yieldRules(
    'Yield Rules',
    'Calculator Management',
    Icons.bar_chart_outlined,
    '/admin/manage?area=yieldRules',
    ManagementArea.yieldRules,
  ),
  modelReview(
    'Agronomic Model Review',
    'Calculator Management',
    Icons.fact_check_outlined,
    '/admin/manage?area=modelSpecifications',
    ManagementArea.modelSpecifications,
  ),
  farmers('Farmer Accounts', 'People', Icons.people_outline, '/admin/farmers'),
  operations(
    'AI Operations',
    'Operations',
    Icons.hub_outlined,
    '/admin/ai-operations',
  ),
  health(
    'Model Health',
    'Operations',
    Icons.monitor_heart_outlined,
    '/admin/model-health',
  ),
  audit(
    'Audit History',
    'Operations',
    Icons.receipt_long_outlined,
    '/admin/audit',
  );

  const AdminDestination(
    this.label,
    this.group,
    this.icon,
    this.location, [
    this.area,
  ]);
  final String label, group, location;
  final IconData icon;
  final ManagementArea? area;

  static AdminDestination fromUri(Uri uri) {
    if (uri.path == '${AppRoutes.admin}/manage') {
      return values.firstWhere(
        (entry) =>
            entry.area?.name ==
            (uri.queryParameters['area'] ?? ManagementArea.knowledge.name),
        orElse: () => knowledge,
      );
    }
    return values.firstWhere(
      (entry) => entry.location == uri.path,
      orElse: () => overview,
    );
  }

  static AdminDestination forArea(ManagementArea area) =>
      values.firstWhere((entry) => entry.area == area);
}

class AdminNavigationLink extends StatelessWidget {
  const AdminNavigationLink({
    required this.destination,
    required this.onTap,
    this.selected = false,
    super.key,
  });
  final AdminDestination destination;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      key: ValueKey('admin-semantic-${destination.name}'),
      label: destination.label,
      selected: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('admin-nav-${destination.name}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizing.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminNavigation extends StatelessWidget {
  const AdminNavigation({
    required this.selected,
    required this.email,
    required this.onSelect,
    required this.onFarmer,
    required this.onSignOut,
    super.key,
  });
  final AdminDestination selected;
  final String? email;
  final ValueChanged<AdminDestination> onSelect;
  final VoidCallback onFarmer;
  final VoidCallback? onSignOut;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      key: const PageStorageKey('admin-navigation'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Admin workspace',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (email != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(email!, style: Theme.of(context).textTheme.bodySmall),
        ],
        for (final group
            in AdminDestination.values.map((entry) => entry.group).toSet()) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                group,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (final destination in AdminDestination.values.where(
            (entry) => entry.group == group,
          ))
            AdminNavigationLink(
              destination: destination,
              selected: selected == destination,
              onTap: () => onSelect(destination),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onFarmer,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Return to Farmer App'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Admin Sign Out'),
        ),
      ],
    ),
  );
}
