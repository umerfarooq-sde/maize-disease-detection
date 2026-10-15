import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/models/session_account.dart';
import 'package:maizedoctor/data/repositories/session_repository.dart';
import 'package:maizedoctor/data/repositories/model_health_repository.dart';
import 'package:maizedoctor/features/admin/view_models/model_health_view_model.dart';

void main() {
  test(
    'real Flutter reads protected Node/pinned FastAPI evidence and separate runtime counts',
    () async {
      final tokens = MemorySessionTokens();
      final api = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: tokens,
      );
      final session = SessionRepository(
        api,
        tokens,
        requiredRole: AccountRole.admin,
      );
      final model = ModelHealthViewModel(ApiModelHealthRepository(api));
      try {
        await session.signIn(
          Platform.environment['MODEL_HEALTH_ADMIN_EMAIL']!,
          Platform.environment['MODEL_HEALTH_ADMIN_PASSWORD']!,
        );
        // Exercise the typed repository directly as well as its ViewModel.
        expect((await ApiModelHealthRepository(api).load()).status, 'READY');
        await model.load();
        expect(model.error, isNull);
        final data = model.data!;
        expect(data.status, 'READY');
        expect(data.offline!.sampleCount, 624);
        expect(data.offline!.accuracy, 0.9583333333333334);
        expect(data.runtime!.successes, 1);
        expect(data.runtime!.failures, 1);
        expect(data.runtime!.requests, 2);
        expect(
          data.matchesProduction,
          data.productionVersion != null &&
              data.productionVersion == data.modelVersion,
        );
        await session.signOut();
        expect(model.data, isNull);
      } finally {
        model.dispose();
        api.close();
        tokens.dispose();
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_MODEL_HEALTH_CHECK'),
  );
}
