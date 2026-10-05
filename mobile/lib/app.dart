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
import 'data/datasources/backend_datasource.dart';
import 'data/repositories/backend_repository.dart';

class MainApp extends StatefulWidget {
  const MainApp({
    this.config,
    this.httpClient,
    this.repository,
    this.initialLocation = AppRoutes.home,
    super.key,
  });
  final AppConfig? config;
  final http.Client? httpClient;
  final BackendRepository? repository;
  final String initialLocation;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final GoRouter _router;
  late final AppConfig _config;
  @override
  void initState() {
    super.initState();
    _config = widget.config ?? AppConfig.fromEnvironment();
    _router = createAppRouter(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: _config),
      Provider<ApiClient>(
        create: (_) => ApiClient(config: _config, client: widget.httpClient),
        dispose: (_, api) => api.close(),
      ),
      Provider<BackendDatasource>(
        create: (context) => BackendDatasource(context.read<ApiClient>()),
      ),
      Provider<BackendRepository>(
        create: (context) =>
            widget.repository ??
            ApiBackendRepository(context.read<BackendDatasource>()),
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
