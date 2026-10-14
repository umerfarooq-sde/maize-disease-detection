import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/datasources/fertilizer_datasource.dart';
import 'package:maizedoctor/data/models/fertilizer_models.dart';
import 'package:maizedoctor/data/repositories/farmer_session_repository.dart';
import 'package:maizedoctor/data/repositories/fertilizer_repository.dart';

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_FERTILIZER_CHECK');
  test(
    'real Node/PostgreSQL calculator preserves exact units, provenance and admin access',
    () async {
      final tokens = MemorySessionTokens();
      final api = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: tokens,
        timeout: const Duration(seconds: 30),
      );
      final repository = ApiFertilizerRepository(FertilizerDatasource(api));
      final session = FarmerSessionRepository(api, tokens);
      try {
        final catalogue = await repository.rules();
        expect(catalogue.status, FertilizerCatalogueStatus.ready);
        final rule = catalogue.items.single;
        expect(rule.id, Platform.environment['FERTILIZER_FIXTURE_RULE_ID']);
        expect(rule.rateKgPerHectare, '50');
        expect(rule.source.url.host, 'example.invalid');
        expect(rule.config.version, 1);
        expect(rule.version, 1);
        final result = await repository.calculate(
          FertilizerInput(
            area: '2',
            areaUnit: FertilizerAreaUnit.acre,
            outputUnit: FertilizerMassUnit.kg,
            ruleId: rule.id,
            ruleVersion: rule.version,
            configVersion: rule.config.version,
          ),
        );
        expect(api.hasAuthenticatedSession, isFalse);
        expect(result.normalizedArea.value, '0.80937128448');
        expect(result.quantity.unroundedValue, '40.468564224');
        expect(result.quantity.value, '40.469');
        expect(
          result.rule.source.citation,
          contains('not agricultural advice'),
        );
        expect(result.engineVersion, 'area-rate-v1');
        expect(result.unitReference.url.host, 'www.nist.gov');
        await session.signIn(
          Platform.environment['FERTILIZER_FIXTURE_FARMER_EMAIL']!,
          Platform.environment['FERTILIZER_FIXTURE_FARMER_PASSWORD']!,
        );
        final grams = await repository.calculate(
          FertilizerInput(
            area: '2',
            areaUnit: FertilizerAreaUnit.acre,
            outputUnit: FertilizerMassUnit.grams,
            ruleId: rule.id,
            ruleVersion: rule.version,
            configVersion: rule.config.version,
          ),
        );
        expect(grams.quantity.value, '40468.564');
        expect(grams.quantity.unroundedValue, '40468.564224');
        await expectLater(
          api.get('admin/calculators/fertilizer/rules', authenticated: true),
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
      }
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
