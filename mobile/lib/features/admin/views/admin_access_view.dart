import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';

/// A reserved admin boundary. No dashboard or privileged data is exposed.
class AdminAccessView extends StatelessWidget {
  const AdminAccessView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administrator access')),
    body: AppPage(
      child: AppEmptyState(
        title: 'Admin workspace is not available',
        icon: Icons.admin_panel_settings_outlined,
        message:
            'This area requires secure administrator sign-in when the admin workspace becomes available.',
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Return home'),
        ),
      ),
    ),
  );
}
