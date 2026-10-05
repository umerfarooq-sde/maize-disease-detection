import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/backend_repository.dart';
import '../../features/admin/views/admin_access_view.dart';
import '../../features/ai_assistant/views/assistant_view.dart';
import '../../features/analytics/views/analytics_view.dart';
import '../../features/auth/views/auth_intro_view.dart';
import '../../features/disease_detection/views/scan_view.dart';
import '../../features/disease_knowledge/views/knowledge_view.dart';
import '../../features/fertilizer_calculator/views/fertilizer_view.dart';
import '../../features/home/view_models/home_view_model.dart';
import '../../features/home/views/home_view.dart';
import '../../features/profile/views/profile_view.dart';
import '../../features/scan_history/views/history_view.dart';
import '../../features/shell/views/farmer_shell.dart';
import '../../features/tools/views/tools_view.dart';
import '../../features/yield_calculator/views/yield_view.dart';
import '../widgets/app_page.dart';
import '../widgets/app_states.dart';
import 'app_routes.dart';

GoRouter createAppRouter({String initialLocation = AppRoutes.home}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => FarmerShell(navigation: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, _) => ChangeNotifierProvider(
                create: (_) => HomeViewModel(context.read<BackendRepository>()),
                child: const HomeView(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.scan, builder: (_, _) => const ScanView()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.knowledge,
              builder: (_, _) => const KnowledgeView(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.tools,
              builder: (_, _) => const ToolsView(),
              routes: [
                GoRoute(
                  path: 'fertilizer',
                  builder: (_, _) => const _DetailPage(
                    title: 'Fertilizer planning',
                    child: FertilizerView(),
                  ),
                ),
                GoRoute(
                  path: 'yield',
                  builder: (_, _) => const _DetailPage(
                    title: 'Yield planning',
                    child: YieldView(),
                  ),
                ),
                GoRoute(
                  path: 'assistant',
                  builder: (_, _) => const _DetailPage(
                    title: 'Field assistant',
                    child: AssistantView(),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, _) => const ProfileView(),
              routes: [
                GoRoute(
                  path: 'sign-in',
                  builder: (_, _) => const _DetailPage(
                    title: 'Sign-in',
                    child: AuthIntroView(),
                  ),
                ),
                GoRoute(
                  path: 'history',
                  builder: (_, _) => const _DetailPage(
                    title: 'Scan history',
                    child: HistoryView(),
                  ),
                ),
                GoRoute(
                  path: 'analytics',
                  builder: (_, _) => const _DetailPage(
                    title: 'Field insights',
                    child: AnalyticsView(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: AppRoutes.admin, builder: (_, _) => const AdminAccessView()),
  ],
  errorBuilder: (context, _) => Scaffold(
    body: AppPage(
      child: AppEmptyState(
        title: 'This page is not available',
        message: 'Return to your field companion to continue.',
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Return home'),
        ),
      ),
    ),
  ),
);

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      toolbarHeight: kToolbarHeight * MediaQuery.textScalerOf(context).scale(1),
    ),
    body: child,
  );
}
