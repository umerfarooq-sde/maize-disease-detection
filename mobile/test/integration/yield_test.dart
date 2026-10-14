import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/models/yield_models.dart';
import 'package:maizedoctor/data/repositories/farmer_session_repository.dart';
import 'package:maizedoctor/data/repositories/yield_repository.dart';

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_YIELD_CHECK');
  test(
    'real Node/PostgreSQL yield projection keeps exact units/source and FARMER admin denial',
    () async {
      final tokens = MemorySessionTokens();
      final api = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: tokens,
        timeout: const Duration(seconds: 30),
      );
      final repository = ApiYieldRepository(api);
      final session = FarmerSessionRepository(api, tokens);
      try {
        final catalogue = await repository.configurations();
        expect(catalogue.status, YieldCatalogueStatus.ready);
        final configuration = catalogue.items.single;
        expect(
          configuration.id,
          Platform.environment['YIELD_FIXTURE_CONFIG_ID'],
        );
        expect(configuration.source.url.host, 'example.invalid');
        final kilograms = await repository.calculate(
          YieldInput(
            area: '2',
            areaUnit: CalculatorAreaUnit.acre,
            outputUnit: YieldMassUnit.kg,
            configId: configuration.id,
            configVersion: 1,
          ),
        );
        expect(api.hasAuthenticatedSession, false);
        expect(kilograms.value, '40.469');
        expect(kilograms.unroundedValue, '40.468564224');
        expect(kilograms.normalizedArea, '0.80937128448');
        expect(kilograms.configuration.version, 1);
        expect(
          kilograms.configuration.source.citation,
          contains('not agricultural advice'),
        );
        await session.signIn(
          Platform.environment['YIELD_FIXTURE_EMAIL']!,
          Platform.environment['YIELD_FIXTURE_PASSWORD']!,
        );
        final tonnes = await repository.calculate(
          YieldInput(
            area: '2',
            areaUnit: CalculatorAreaUnit.acre,
            outputUnit: YieldMassUnit.tonnes,
            configId: configuration.id,
            configVersion: 1,
          ),
        );
        expect(tonnes.value, '0.040');
        expect(tonnes.unroundedValue, '0.040468564224');
        await expectLater(
          api.get(
            'admin/calculators/yield/configurations',
            authenticated: true,
          ),
          throwsA(
            isA<AppException>().having(
              (error) => error.kind,
              'kind',
              AppErrorKind.authorization,
            ),
          ),
        );
      } finally {
        api.close();
        tokens.dispose();
      }
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
