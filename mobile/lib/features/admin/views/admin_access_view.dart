import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';
import '../view_models/admin_session_view_model.dart';
import '../view_models/admin_dashboard_view_model.dart';
import 'admin_sign_in_view.dart';
import 'admin_dashboard_view.dart';

/// Outside the farmer navigation shell, with an independent volatile session.
class AdminAccessView extends StatelessWidget {
  const AdminAccessView({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin overview'),
        leading: IconButton(
          tooltip: 'Return to farmer app',
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (session.signedIn)
            TextButton(
              onPressed: session.busy ? null : session.signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: session.signedIn
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
