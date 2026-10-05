import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/datasources/backend_datasource.dart';
import 'package:maizedoctor/data/repositories/backend_repository.dart';
import 'package:maizedoctor/features/home/view_models/home_view_model.dart';

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_API_CHECK');
  test(
    'live Flutter MVVM chain reaches the configured Node health API',
    () async {
      final api = ApiClient(config: AppConfig.fromEnvironment());
      final model = HomeViewModel(ApiBackendRepository(BackendDatasource(api)));
      try {
        await model.checkConnection();
        expect(model.error, isNull);
        expect(model.health?.isAvailable, true);
        expect(model.isLoading, false);
      } finally {
        model.dispose();
        api.close();
      }
    },
    skip: live
        ? false
        : 'Opt in with RUN_LIVE_API_CHECK and a running development backend.',
  );
}
