import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';
import '../view_models/admin_session_view_model.dart';
import '../view_models/admin_dashboard_view_model.dart';
import 'admin_sign_in_view.dart';
import 'admin_dashboard_view.dart';
import '../../../data/repositories/admin_management_repository.dart';
import '../view_models/admin_management_view_model.dart';
import 'admin_management_view.dart';
import '../../../data/repositories/model_health_repository.dart';
import '../view_models/model_health_view_model.dart';
import 'model_health_view.dart';

/// Outside the farmer navigation shell, with an independent volatile session.
class AdminAccessView extends StatelessWidget {
  const AdminAccessView({
    this.management = false,
    this.modelHealth = false,
    super.key,
  });
  final bool management;
  final bool modelHealth;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          modelHealth
              ? 'Admin model health'
              : management
              ? 'Admin management'
              : 'Admin overview',
        ),
        leading: IconButton(
          tooltip: management || modelHealth
              ? 'Return to Admin overview'
              : 'Return to farmer app',
          onPressed: () => context.go(
            management || modelHealth ? AppRoutes.admin : AppRoutes.home,
          ),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (session.signedIn && !modelHealth)
            IconButton(
              onPressed: () => context.push('${AppRoutes.admin}/model-health'),
              tooltip: 'Model health',
              icon: const Icon(Icons.monitor_heart_outlined),
            ),
          if (session.signedIn && !management)
            IconButton(
              onPressed: () => context.push('${AppRoutes.admin}/manage'),
              tooltip: 'Manage knowledge and configuration',
              icon: const Icon(Icons.settings_outlined),
            ),
          if (session.signedIn)
            TextButton(
              onPressed: session.busy ? null : session.signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: session.signedIn && modelHealth
          ? ChangeNotifierProvider(
              key: ValueKey('model-health-${session.revision}'),
              create: (_) =>
                  ModelHealthViewModel(context.read<ModelHealthRepository>())
                    ..load(),
              child: const ModelHealthView(),
            )
          : session.signedIn && management
          ? ChangeNotifierProvider(
              key: ValueKey('admin-management-${session.revision}'),
              create: (_) => AdminManagementViewModel(
                context.read<AdminManagementRepository>(),
              )..load(),
              child: const AdminManagementView(),
            )
          : session.signedIn
          ? ChangeNotifierProvider(
              key: ValueKey('admin-dashboard-${session.revision}'),
              create: (_) => AdminDashboardViewModel(
                context.read<AdminDashboardRepository>(),
              )..load(),
              child: const AdminDashboardView(),
            )
          : const AdminSignInView(),
    );
  }
}
