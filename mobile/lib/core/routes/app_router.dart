import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/backend_repository.dart';
import '../../data/repositories/registration_repository.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../features/auth/view_models/registration_view_model.dart';
import '../../features/auth/views/registration_view.dart';
import '../../features/disease_knowledge/view_models/knowledge_view_model.dart';
import '../../features/disease_knowledge/view_models/knowledge_detail_view_model.dart';
import '../../features/disease_knowledge/views/knowledge_detail_view.dart';
import '../../data/repositories/scan_repository.dart';
import '../../data/repositories/scan_records_repository.dart';
import '../../data/models/scan_record.dart';
import '../../data/repositories/assistant_repository.dart';
import '../../data/repositories/fertilizer_repository.dart';
import '../../data/repositories/yield_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../features/analytics/view_models/analytics_view_model.dart';
import '../../features/yield_calculator/view_models/yield_view_model.dart';
import '../../features/auth/view_models/farmer_session_view_model.dart';
import '../../features/scan_history/view_models/scan_history_view_model.dart';
import '../../features/disease_detection/view_models/scan_result_arguments.dart';
import '../../features/disease_detection/view_models/scan_result_view_model.dart';
import '../../features/disease_detection/views/result_view.dart';
import '../../features/disease_detection/view_models/scan_view_model.dart';
import '../../features/admin/views/admin_access_view.dart';
import '../../features/ai_assistant/views/assistant_view.dart';
import '../../features/ai_assistant/views/assistant_scan_picker.dart';
import '../../features/ai_assistant/view_models/assistant_view_model.dart';
import '../../features/analytics/views/analytics_view.dart';
import '../../features/auth/views/auth_intro_view.dart';
import '../../features/disease_detection/views/scan_view.dart';
import '../../features/disease_knowledge/views/knowledge_view.dart';
import '../../features/fertilizer_calculator/views/fertilizer_view.dart';
import '../../features/fertilizer_calculator/view_models/fertilizer_view_model.dart';
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
            GoRoute(
              path: AppRoutes.scan,
              builder: (context, state) => ChangeNotifierProvider(
                key: ValueKey(
                  'scan-${context.watch<FarmerSessionViewModel>().revision}-${state.uri.queryParameters['new']}',
                ),
                create: (_) => ScanViewModel(
                  context.read<ScanRepository>(),
                  records: context.read<ScanRecordsRepository>(),
                )..recoverSelection(),
                child: ScanView(
                  onResult: (arguments) => context.push(
                    '${AppRoutes.scan}/result/${arguments.scan.id}',
                    extra: _ResultNavigation(
                      arguments,
                      context.read<FarmerSessionViewModel>().revision,
                    ),
                  ),
                ),
              ),
              routes: [GoRoute(path: 'result/:scanId', builder: _resultPage)],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.knowledge,
              builder: (context, _) => ChangeNotifierProvider(
                create: (_) =>
                    KnowledgeViewModel(context.read<KnowledgeRepository>())
                      ..load(),
                child: const KnowledgeView(),
              ),
              routes: [
                GoRoute(
                  path: ':slug',
                  builder: (context, state) => _DetailPage(
                    title: 'Reviewed knowledge',
                    child: ChangeNotifierProvider(
                      key: ValueKey(state.pathParameters['slug']),
                      create: (_) => KnowledgeDetailViewModel(
                        context.read<KnowledgeRepository>(),
                        state.pathParameters['slug'] ?? '',
                      )..load(),
                      child: const KnowledgeDetailView(),
                    ),
                  ),
                ),
              ],
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
                  builder: (context, _) => _DetailPage(
                    title: 'Fertilizer planning',
                    child: ChangeNotifierProvider(
                      create: (_) => FertilizerViewModel(
                        context.read<FertilizerRepository>(),
                      )..load(),
                      child: const FertilizerView(),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'yield',
                  builder: (context, _) => _DetailPage(
                    title: 'Yield planning',
                    child: ChangeNotifierProvider(
                      create: (_) =>
                          YieldViewModel(context.read<YieldRepository>())
                            ..load(),
                      child: const YieldView(),
                    ),
                  ),
                ),
                GoRoute(path: 'assistant', builder: _assistantPage),
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
                  path: 'register',
                  builder: (context, _) => _DetailPage(
                    title: 'Create farmer account',
                    child: ChangeNotifierProvider(
                      create: (_) => RegistrationViewModel(
                        context.read<RegistrationRepository>(),
                      ),
                      child: const RegistrationView(),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'history',
                  builder: (context, _) => _DetailPage(
                    title: 'Scan history',
                    child: ChangeNotifierProvider(
                      key: ValueKey(
                        'history-${context.watch<FarmerSessionViewModel>().revision}',
                      ),
                      create: (_) => ScanHistoryViewModel(
                        context.read<ScanRecordsRepository>(),
                      )..load(),
                      child: HistoryView(
                        onOpenScan: (scan) => context.push(
                          '${AppRoutes.history}/scans/${scan.id}',
                          extra: _ResultNavigation(
                            ScanResultArguments(scan: scan),
                            context.read<FarmerSessionViewModel>().revision,
                          ),
                        ),
                      ),
                    ),
                  ),
                  routes: [
                    GoRoute(path: 'scans/:scanId', builder: _resultPage),
                  ],
                ),
                GoRoute(
                  path: 'analytics',
                  builder: (context, _) => _DetailPage(
                    title: 'Field insights',
                    child: ChangeNotifierProvider(
                      key: ValueKey(
                        'analytics-${context.watch<FarmerSessionViewModel>().revision}',
                      ),
                      create: (_) => AnalyticsViewModel(
                        context.read<AnalyticsRepository>(),
                      )..load(),
                      child: const AnalyticsView(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.admin,
      builder: (_, _) => const AdminAccessView(),
      routes: [
        GoRoute(
          path: 'manage',
          builder: (_, _) => const AdminAccessView(management: true),
        ),
        GoRoute(
          path: 'model-health',
          builder: (_, _) => const AdminAccessView(modelHealth: true),
        ),
      ],
    ),
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

class _ResultNavigation {
  const _ResultNavigation(this.arguments, this.revision);
  final ScanResultArguments arguments;
  final int revision;
}

Widget _resultPage(BuildContext context, GoRouterState state) {
  final revision = context.watch<FarmerSessionViewModel>().revision;
  final extra = state.extra;
  // Old session results and guest capabilities are never reused after sign-in/out.
  final initial = extra is _ResultNavigation && extra.revision == revision
      ? extra.arguments
      : null;
  final id = state.pathParameters['scanId'] ?? '';
  return _DetailPage(
    title: 'Model prediction',
    child: ChangeNotifierProvider(
      key: ValueKey('result-$revision-$id'),
      create: (_) => ScanResultViewModel(
        context.read<ScanRecordsRepository>(),
        scanId: id,
        initial: initial,
        uploads: context.read<ScanRepository>(),
      )..load(),
      child: ScanResultView(
        onExplainScan: context.watch<FarmerSessionViewModel>().signedIn
            ? (scan) => context.push(
                AppRoutes.assistant,
                extra: _AssistantNavigation(
                  scan,
                  context.read<FarmerSessionViewModel>().revision,
                ),
              )
            : null,
        onNewScan: () => context.go(
          '${AppRoutes.scan}?new=${DateTime.now().microsecondsSinceEpoch}',
        ),
      ),
    ),
  );
}

class _AssistantNavigation {
  const _AssistantNavigation(this.scan, this.revision);
  final ScanRecord scan;
  final int revision;
}

Widget _assistantPage(BuildContext context, GoRouterState state) {
  final session = context.watch<FarmerSessionViewModel>();
  final extra = state.extra;
  final scan =
      session.signedIn &&
          extra is _AssistantNavigation &&
          extra.revision == session.revision
      ? extra.scan
      : null;
  return _DetailPage(
    title: 'Field assistant',
    child: ChangeNotifierProvider(
      key: ValueKey('assistant-${session.revision}'),
      create: (_) {
        final model = AssistantViewModel(context.read<AssistantRepository>());
        if (scan != null) model.explainScan(scan);
        return model;
      },
      child: Builder(
        builder: (context) =>
            AssistantView(onChooseScan: () => _chooseAssistantScan(context)),
      ),
    ),
  );
}

Future<void> _chooseAssistantScan(BuildContext context) async {
  final session = context.read<FarmerSessionViewModel>();
  if (!session.signedIn) return;
  final revision = session.revision;
  final scan = await showModalBottomSheet<ScanRecord>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const AssistantScanPicker(),
  );
  if (!context.mounted || session.revision != revision || scan == null) return;
  await context.read<AssistantViewModel>().explainScan(scan);
}

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
