import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/datasources/assistant_datasource.dart';
import 'package:maizedoctor/data/datasources/fertilizer_datasource.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/datasources/scan_datasource.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import 'package:maizedoctor/data/models/assistant_answer.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/data/models/fertilizer_models.dart';
import 'package:maizedoctor/data/models/scan_prediction.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/data/models/session_account.dart';
import 'package:maizedoctor/data/models/yield_models.dart';
import 'package:maizedoctor/data/repositories/admin_dashboard_repository.dart';
import 'package:maizedoctor/data/repositories/admin_management_repository.dart';
import 'package:maizedoctor/data/repositories/analytics_repository.dart';
import 'package:maizedoctor/data/repositories/assistant_repository.dart';
import 'package:maizedoctor/data/repositories/farmer_session_repository.dart';
import 'package:maizedoctor/data/repositories/fertilizer_repository.dart';
import 'package:maizedoctor/data/repositories/model_health_repository.dart';
import 'package:maizedoctor/data/repositories/scan_records_repository.dart';
import 'package:maizedoctor/data/repositories/scan_repository.dart';
import 'package:maizedoctor/data/repositories/session_repository.dart';
import 'package:maizedoctor/data/repositories/yield_repository.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import 'scan_upload_test.dart' show FixtureImageSource;

void main() {
  test(
    'connected farmer/Admin API and MVVM journey with real isolated services',
    () async {
      final farmerTokens = MemorySessionTokens(),
          adminTokens = MemorySessionTokens();
      final farmerApi = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: farmerTokens,
      );
      final adminApi = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: adminTokens,
      );
      final farmer = FarmerSessionRepository(farmerApi, farmerTokens);
      final admin = SessionRepository(
        adminApi,
        adminTokens,
        requiredRole: AccountRole.admin,
      );
      final records = ApiScanRecordsRepository(ScanDatasource(farmerApi));
      final upload = ScanViewModel(
        ApiScanRepository(FixtureImageSource(), ScanDatasource(farmerApi)),
        records: records,
      );
      final credentials =
          jsonDecode(Platform.environment['E2E_FARMER']!)
              as Map<String, dynamic>;
      final adminCredentials =
          jsonDecode(Platform.environment['E2E_ADMIN']!)
              as Map<String, dynamic>;
      void mark(String step) => debugPrint('E2E verified: $step');
      try {
        await farmerApi.request(
          ApiMethod.post,
          'auth/register',
          body: credentials,
        );
        mark(
          'farmer registration via public API (registration UI is not implemented)',
        );
        await farmer.signIn(
          credentials['email'] as String,
          credentials['password'] as String,
        );
        expect((await records.history()).items, isEmpty);
        mark('login and empty private history');
        await upload.select(LeafImageSource.gallery);
        expect(upload.image, isNotNull);
        await upload.upload();
        expect(upload.error, isNull);
        final scan = upload.scan!;
        expect(scan.status, ScanStatus.completed);
        expect(
          scan.prediction!.predictionStatus,
          ScanPredictionStatus.lowConfidence,
        );
        expect(scan.prediction!.modelVersion, 'mobilenet-v3-small-v2-20261009');
        expect(upload.progress, 1);
        mark(
          'synthetic gallery fixture → real Cloudinary/ML prediction, low-confidence result',
        );
        final history = await records.history();
        expect(history.items.single.id, scan.id);
        final detail = await records.read(scan.id);
        expect(detail.prediction!.confidence, scan.prediction!.confidence);
        expect(detail.imageUrl.toString(), 'scans/${detail.id}/image');
        mark('saved owned history and result detail');
        final assistant = ApiAssistantRepository(
          AssistantDatasource(farmerApi),
        );
        final explanation = await assistant.explainScan(detail);
        expect(
          explanation.classifierPrediction!.matches(scan.prediction!),
          true,
        );
        expect(explanation.warnings, isNotEmpty);
        expect(
          explanation.status,
          isIn([
            AssistantAnswerStatus.grounded,
            AssistantAnswerStatus.insufficientInformation,
            AssistantAnswerStatus.conflictingEvidence,
          ]),
        );
        final answer = await assistant.ask(
          'What symptoms identify common rust in maize?',
        );
        expect(answer.status, AssistantAnswerStatus.grounded);
        expect(answer.sources, isNotEmpty);
        mark(
          'owned scan explanation preserves classifier; real source-grounded common-rust answer',
        );
        final knowledge =
            (await farmerApi.get('diseases')).data as Map<String, dynamic>;
        expect((knowledge['items'] as List).length, 4);
        final rust =
            (await farmerApi.get('diseases/common-rust')).data
                as Map<String, dynamic>;
        expect(rust['sections'], isNotEmpty);
        mark(
          'sourced knowledge API (farmer Knowledge screen remains a placeholder)',
        );
        final fertilizer = ApiFertilizerRepository(
          FertilizerDatasource(farmerApi),
        );
        final rule = (await fertilizer.rules()).items.single;
        final input = FertilizerInput(
          area: '2',
          areaUnit: FertilizerAreaUnit.hectare,
          outputUnit: FertilizerMassUnit.kg,
          ruleId: rule.id,
          ruleVersion: rule.version,
          configVersion: rule.config.version,
        );
        final quantity = await fertilizer.calculate(input);
        expect(double.parse(quantity.quantity.value), 20);
        expect(rule.source.url.host, 'example.invalid');
        await expectLater(
          farmerApi.request(
            ApiMethod.post,
            'calculators/fertilizer/calculate',
            body: {...input.toJson(), 'area': '-1'},
          ),
          throwsA(isA<AppException>()),
        );
        final yields = ApiYieldRepository(farmerApi);
        final config = (await yields.configurations()).items.single;
        final yieldResult = await yields.calculate(
          YieldInput(
            area: '2',
            areaUnit: CalculatorAreaUnit.hectare,
            outputUnit: YieldMassUnit.kg,
            configId: config.id,
            configVersion: config.version,
          ),
        );
        expect(double.parse(yieldResult.value), 25);
        mark(
          'synthetic-only version-pinned fertilizer/yield arithmetic and invalid input',
        );
        final range = AnalyticsDateRange.lastDays(7, now: DateTime.now());
        final stats = await ApiAnalyticsRepository(farmerApi).summary(range);
        expect(stats.totals['totalScans'], 1);
        mark('farmer statistics derived from that farmer scan');
        await expectLater(
          farmerApi.get('admin/dashboard', authenticated: true),
          throwsA(
            isA<AppException>().having(
              (error) => error.kind,
              'kind',
              AppErrorKind.authorization,
            ),
          ),
        );
        await admin.signIn(
          adminCredentials['email'] as String,
          adminCredentials['password'] as String,
        );
        expect(
          (await ApiAdminDashboardRepository(
            adminApi,
          ).load(range)).scans.totals['totalScans'],
          greaterThanOrEqualTo(1),
        );
        mark('separate Admin login/dashboard and FARMER denial');
        final management = ApiAdminManagementRepository(adminApi);
        final body =
            jsonDecode(Platform.environment['E2E_DOCUMENT']!)
                as Map<String, dynamic>;
        for (var version = 1; version <= 2; version++) {
          await management.save(
            ManagementEditor(ManagementArea.knowledge, null, {}),
            {...body, 'expectedVersion': version - 1},
          );
          var entry = (await management.list(ManagementArea.knowledge)).items
              .singleWhere(
                (row) =>
                    row.values['documentKey'] == body['documentKey'] &&
                    row.version == version,
              );
          expect(entry.status, 'DRAFT');
          await management.index(entry.id);
          entry = await management.document(entry.id);
          expect(entry.ready, true);
          await management.status(ManagementArea.knowledge, entry, 'ACTIVE');
        }
        final versions = (await management.list(ManagementArea.knowledge)).items
            .where((row) => row.values['documentKey'] == body['documentKey'])
            .toList();
        expect(
          versions.singleWhere((row) => row.version == 1).status,
          'ARCHIVED',
        );
        expect(
          versions.singleWhere((row) => row.version == 2).status,
          'ACTIVE',
        );
        mark(
          'immutable reviewed edit, real Google index, version activation/retirement',
        );
        final health = await ApiModelHealthRepository(adminApi).load();
        expect(health.status, 'READY');
        expect(health.offline!.sampleCount, 624);
        expect(health.runtime!.successes, greaterThanOrEqualTo(1));
        mark('model health separates saved evaluation from operational counts');
        farmerTokens.save(
          (await farmerTokens.readAccessToken())!,
          Duration.zero,
        );
        await farmerApi.get('auth/me', authenticated: true);
        mark('expired local access lifetime triggers real cookie refresh');
        await farmer.signOut();
        await admin.signOut();
        expect(farmerApi.hasAuthenticatedSession, false);
        expect(adminApi.hasAuthenticatedSession, false);
        await expectLater(
          records.history(),
          throwsA(
            isA<AppException>().having(
              (error) => error.kind,
              'kind',
              AppErrorKind.authentication,
            ),
          ),
        );
        mark('logout/revocation and protected-history denial');
      } finally {
        upload.dispose();
        farmerApi.close();
        adminApi.close();
        farmerTokens.dispose();
        adminTokens.dispose();
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_E2E_CHECK'),
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
