import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';
import '../../../data/repositories/admin_management_repository.dart';
import '../../../data/repositories/admin_accounts_repository.dart';
import '../../../data/repositories/model_health_repository.dart';
import '../view_models/admin_session_view_model.dart';
import '../view_models/admin_dashboard_view_model.dart';
import '../view_models/admin_management_view_model.dart';
import '../view_models/audit_log_view_model.dart';
import '../view_models/farmer_management_view_model.dart';
import '../view_models/model_health_view_model.dart';
import '../widgets/admin_navigation.dart';
import '../widgets/admin_draft_guard.dart';
import '../widgets/admin_workspace_shell.dart';
import 'admin_sign_in_view.dart';
import 'admin_dashboard_view.dart';
import 'admin_management_view.dart';
import 'audit_log_view.dart';
import 'farmer_management_view.dart';
import 'model_health_view.dart';
import 'reference_management_view.dart';
import 'ai_operations_view.dart';

/// Gating stays on the independent, role-checked Admin session. The router's
/// child Navigator is not mounted until that session is authorized.
class AdminAccessView extends StatelessWidget {
  const AdminAccessView({
    required this.child,
    required this.location,
    super.key,
  });
  final Widget child;
  final Uri location;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionViewModel>();
    final destination = AdminDestination.fromUri(location);
    final shell = AdminWorkspaceShell(
      destination: destination,
      signedIn: session.signedIn,
      email: session.account?.email,
      onSignOut: session.busy ? null : session.signOut,
      child: session.signedIn ? child : const AdminSignInView(),
    );
    return session.signedIn
        ? ChangeNotifierProvider(
            key: ValueKey('admin-report-${session.revision}'),
            create: (_) => AdminDashboardViewModel(
              context.read<AdminDashboardRepository>(),
            ),
            child: ChangeNotifierProvider(
              create: (_) => AdminDraftGuard(),
              child: shell,
            ),
          )
        : shell;
  }
}

/// Creates only the selected feature's existing model, after the access gate.
class AdminSectionView extends StatelessWidget {
  const AdminSectionView({required this.destination, super.key});
  final AdminDestination destination;
  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AdminSessionViewModel>().revision;
    if (destination.area case final area?) {
      return ChangeNotifierProvider(
        key: ValueKey('admin-management-$revision-${area.name}'),
        create: (_) =>
            AdminManagementViewModel(context.read<AdminManagementRepository>())
              ..select(area),
        child: AdminManagementView(
          onAreaChanged: (area) =>
              context.go(AdminDestination.forArea(area).location),
        ),
      );
    }
    return switch (destination) {
      AdminDestination.overview => const AdminDashboardView(),
      AdminDestination.operations => const AiOperationsView(),
      AdminDestination.references => ReferenceManagementView(
        key: ValueKey('reference-$revision'),
      ),
      AdminDestination.health => ChangeNotifierProvider(
        key: ValueKey('model-health-$revision'),
        create: (_) =>
            ModelHealthViewModel(context.read<ModelHealthRepository>())..load(),
        child: const ModelHealthView(),
      ),
      AdminDestination.farmers => ChangeNotifierProvider(
        key: ValueKey('farmers-$revision'),
        create: (_) =>
            FarmerManagementViewModel(context.read<AdminAccountsRepository>())
              ..load(),
        child: const FarmerManagementView(),
      ),
      AdminDestination.audit => ChangeNotifierProvider(
        key: ValueKey('audits-$revision'),
        create: (_) =>
            AuditLogViewModel(context.read<AdminAccountsRepository>())..load(),
        child: const AuditLogView(),
      ),
      _ => throw StateError('Management destinations must supply an area.'),
    };
  }
}
