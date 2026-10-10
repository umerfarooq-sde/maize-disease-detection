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
    _router = createAppRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    _tokens.dispose();
    _api.close();
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
