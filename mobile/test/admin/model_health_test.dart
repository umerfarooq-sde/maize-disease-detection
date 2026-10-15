import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/model_health.dart';
import 'package:maizedoctor/data/repositories/model_health_repository.dart';
import 'package:maizedoctor/features/admin/view_models/model_health_view_model.dart';
import 'package:maizedoctor/features/admin/views/model_health_view.dart';
import '../auth/session_test.dart' show response;

Map<String, dynamic> healthFixture() => {
  'asOf': '2026-10-15T00:00:00Z',
  'registry': {
    'status': 'NOT_PROMOTED',
    'productionVersion': null,
    'models': [
      {
        'version': 'synthetic-v1',
        'architecture': 'mobilenet_v3_small',
        'datasetVersion': 'synthetic-index',
        'preprocessingVersion': '1.0.0',
        'status': 'VALIDATED',
        'registeredAt': '2026-10-15T00:00:00Z',
      },
    ],
  },
  'service': {
    'status': 'READY',
    'configuredVersion': 'synthetic-v1',
    'registered': true,
    'matchesProduction': false,
    'data': {
      'ready': true,
      'modelVersion': 'synthetic-v1',
      'preprocessingVersion': '1.0.0',
      'confidencePolicy': 'UNCONFIGURED',
      'development': {
        'architecture': 'mobilenet_v3_small',
        'datasetVersion': 'synthetic-index',
        'indexFingerprint': 'a' * 64,
        'experimentId': 'synthetic-test',
        'trainedAt': null,
        'evaluation': {
          'class_names': modelLabels,
          'sample_count': 4,
          'accuracy': 1,
          'macro_precision': 1,
          'macro_recall': 1,
          'macro_f1': 1,
          'per_class': [
            for (final label in modelLabels)
              {
                'label': label,
                'support': 1,
                'precision': 1,
                'recall': 1,
                'f1': 1,
                'specificity': 1,
              },
          ],
          'confusion_matrix': [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
          ],
        },
      },
      'runtime': {
        'scope': 'PROCESS_SINCE_START',
        'since': '2026-10-15T00:00:00Z',
        'requests': 3,
        'inFlight': 1,
        'successes': 1,
        'failures': 1,
        'lowConfidence': 1,
        'lowConfidenceRate': 1,
        'meanLatencyMs': 12,
        'predictionDistribution': {
          for (final label in modelLabels) label: label == 'Healthy' ? 1 : 0,
        },
      },
    },
  },
  'drift': 'NOT_AVAILABLE_NO_GROUND_TRUTH',
};

class FakeModelHealthRepository implements ModelHealthRepository {
  @override
  bool hasSession = true;
  @override
  int? revision = 1;
  int calls = 0;
  Future<AdminModelHealth> Function() respond = () async =>
      AdminModelHealth.fromJson(healthFixture());
  @override
  Future<AdminModelHealth> load() {
    calls++;
    return respond();
  }
}

void main() {
  test(
    'typed model health preserves separate offline and process evidence; rejects impossible counts and matrices',
    () {
      final model = AdminModelHealth.fromJson(healthFixture());
      expect(model.offline!.sampleCount, 4);
      expect(model.runtime!.requests, 3);
      expect(model.productionVersion, isNull);
      expect(model.matchesProduction, false);
      expect(
        () => model.offline!.confusionMatrix.first.clear(),
        throwsUnsupportedError,
      );
      for (final field in ['runtime', 'evaluation']) {
        final fixture = healthFixture();
        final live = (fixture['service'] as Map)['data'] as Map;
        if (field == 'runtime') {
          (live['runtime'] as Map)['requests'] = 100;
        } else {
          ((live['development'] as Map)['evaluation'] as Map)['sample_count'] =
              8;
        }
        expect(
          () => AdminModelHealth.fromJson(fixture),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
  test(
    'repository authenticates only to Node and validates malformed replies',
    () async {
      final tokens = MemorySessionTokens()
        ..save('admin.access.token', const Duration(minutes: 10));
      var broken = false;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: tokens,
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/admin/model-health');
          expect(request.method, 'GET');
          expect(request.headers['authorization'], 'Bearer admin.access.token');
          return response(broken ? {'broken': true} : healthFixture());
        }),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      final repository = ApiModelHealthRepository(api);
      expect((await repository.load()).offline!.accuracy, 1);
      broken = true;
      await expectLater(repository.load(), throwsA(isA<AppException>()));
    },
  );
  test(
    'ViewModel handles network retry, no session and late identity/disposal results',
    () async {
      final repository = FakeModelHealthRepository()..hasSession = false;
      final model = ModelHealthViewModel(repository);
      await model.load();
      expect(repository.calls, 0);
      repository.hasSession = true;
      repository.respond = () async =>
          throw const AppException(AppErrorKind.network);
      await model.load();
      expect(model.error!.kind, AppErrorKind.network);
      repository.respond = () async =>
          AdminModelHealth.fromJson(healthFixture());
      await model.load();
      expect(model.error, isNull);
      expect(model.data, isNotNull);
      final pending = Completer<AdminModelHealth>();
      repository.respond = () => pending.future;
      final load = model.load();
      repository.revision = 2;
      pending.complete(AdminModelHealth.fromJson(healthFixture()));
      await load;
      expect(model.data, isNull);
      model.dispose();
      final second = ModelHealthViewModel(repository);
      final gate = Completer<AdminModelHealth>();
      repository.respond = () => gate.future;
      final late = second.load();
      second.dispose();
      gate.complete(AdminModelHealth.fromJson(healthFixture()));
      await late;
      expect(second.data, isNull);
    },
  );
  testWidgets(
    'health UI distinguishes evaluation/runtime/uncertainty and scrolls at narrow size and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final model = ModelHealthViewModel(FakeModelHealthRepository());
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: ChangeNotifierProvider.value(
                value: model,
                child: const ModelHealthView(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Offline evaluation'), findsOneWidget);
      expect(find.textContaining('No model has been promoted'), findsOneWidget);
      await tester.ensureVisible(find.text('Runtime operational statistics'));
      await tester.pump();
      expect(find.textContaining('no verified ground truth'), findsOneWidget);
      expect(
        find.textContaining('Every successful prediction'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'health UI shows retry and unavailable service without fabricated metrics',
    (tester) async {
      final repository = FakeModelHealthRepository()
        ..respond = () async => throw const AppException(AppErrorKind.network);
      final model = ModelHealthViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: model,
              child: const ModelHealthView(),
            ),
          ),
        ),
      );
      expect(find.text('Try again'), findsOneWidget);
      repository.respond = () async {
        final data = healthFixture();
        data['service'] = {
          'status': 'UNAVAILABLE',
          'configuredVersion': 'synthetic-v1',
          'registered': false,
          'matchesProduction': false,
          'data': null,
        };
        return AdminModelHealth.fromJson(data);
      };
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Offline evidence unavailable'), findsOneWidget);
      expect(
        find.textContaining('Live statistics unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('100.00%'), findsNothing);
    },
  );
}
