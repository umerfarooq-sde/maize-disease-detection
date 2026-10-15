import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/network/app_config.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/memory_session_tokens.dart';
import 'data/repositories/farmer_session_repository.dart';
import 'data/repositories/scan_records_repository.dart';
import 'data/repositories/assistant_repository.dart';
import 'data/datasources/assistant_datasource.dart';
import 'data/datasources/fertilizer_datasource.dart';
import 'data/repositories/fertilizer_repository.dart';
import 'data/repositories/yield_repository.dart';
import 'data/repositories/analytics_repository.dart';
import 'data/models/session_account.dart';
import 'data/repositories/session_repository.dart';
import 'data/repositories/admin_dashboard_repository.dart';
import 'data/repositories/admin_management_repository.dart';
import 'data/repositories/model_health_repository.dart';
import 'features/admin/view_models/admin_session_view_model.dart';
import 'features/auth/view_models/farmer_session_view_model.dart';
import 'data/datasources/leaf_image_datasource.dart';
import 'data/datasources/scan_datasource.dart';
import 'data/repositories/scan_repository.dart';
import 'data/datasources/backend_datasource.dart';
import 'data/repositories/backend_repository.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    this.config,
    this.httpClient,
    this.repository,
    this.scanRepository,
    this.initialLocation = AppRoutes.home,
    super.key,
  });
  final AppConfig? config;
  final http.Client? httpClient;
  final BackendRepository? repository;
  final ScanRepository? scanRepository;
  final String initialLocation;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final GoRouter _router;
  late final AppConfig _config;
  late final ApiClient _api;
  late final MemorySessionTokens _tokens;
  late final FarmerSessionViewModel _session;
  late final MemorySessionTokens _adminTokens;
  late final ApiClient _adminApi;
  late final AdminSessionViewModel _adminSession;
  @override
  void initState() {
    super.initState();
    _config = widget.config ?? AppConfig.fromEnvironment();
    _tokens = MemorySessionTokens();
    _api = ApiClient(
      config: _config,
      client: widget.httpClient,
      tokenSource: _tokens,
    );
    _session = FarmerSessionViewModel(FarmerSessionRepository(_api, _tokens));
    _adminTokens = MemorySessionTokens();
    _adminApi = ApiClient(
      config: _config,
      client: widget.httpClient,
      tokenSource: _adminTokens,
    );
    _adminSession = AdminSessionViewModel(
      SessionRepository(
        _adminApi,
        _adminTokens,
        requiredRole: AccountRole.admin,
      ),
    );
    _router = createAppRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    _tokens.dispose();
    _api.close();
    _adminSession.dispose();
    _adminTokens.dispose();
    _adminApi.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: _config),
      Provider<ApiClient>.value(value: _api),
      ChangeNotifierProvider<FarmerSessionViewModel>.value(value: _session),
      Provider<ScanRecordsRepository>(
        create: (_) => ApiScanRecordsRepository(ScanDatasource(_api)),
      ),
      Provider<AssistantRepository>(
        create: (_) => ApiAssistantRepository(AssistantDatasource(_api)),
      ),
      Provider<FertilizerRepository>(
        create: (_) => ApiFertilizerRepository(FertilizerDatasource(_api)),
      ),
      Provider<YieldRepository>(create: (_) => ApiYieldRepository(_api)),
      ChangeNotifierProvider<AdminSessionViewModel>.value(value: _adminSession),
      Provider<AdminDashboardRepository>(
        create: (_) => ApiAdminDashboardRepository(_adminApi),
      ),
      Provider<AdminManagementRepository>(
        create: (_) => ApiAdminManagementRepository(_adminApi),
      ),
      Provider<ModelHealthRepository>(
        create: (_) => ApiModelHealthRepository(_adminApi),
      ),
      Provider<AnalyticsRepository>(
        create: (_) => ApiAnalyticsRepository(_api),
      ),
      Provider<BackendDatasource>(
        create: (context) => BackendDatasource(context.read<ApiClient>()),
      ),
      Provider<BackendRepository>(
        create: (context) =>
            widget.repository ??
            ApiBackendRepository(context.read<BackendDatasource>()),
      ),
      Provider<ScanRepository>(
        create: (context) =>
            widget.scanRepository ??
            ApiScanRepository(
              PickerLeafImageDatasource(),
              ScanDatasource(context.read<ApiClient>()),
            ),
      ),
    ],
    child: MaterialApp.router(
      title: AppConstants.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    ),
  );
}
