import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/data/datasources/scan_datasource.dart';
import 'package:maizedoctor/data/models/scan_prediction.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'helpers.dart';

class RecordingClient extends http.BaseClient {
  http.BaseRequest? sent;
  String body = '';
  int status = 201;
  String? errorCode;
  Map<String, Object?> responseData = scanJson();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent = request;
    body = latin1.decode(await request.finalize().toBytes());
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'success': errorCode == null,
            'data': responseData,
            'error': {
              'code': errorCode,
              'message': 'secret unsafe provider error',
            },
            'requestId': 'aa29ad82-93ec-433d-8948-2e8ca17c7428',
          }),
        ),
      ),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

class TokenSource implements AccessTokenSource {
  TokenSource(this.token);
  final String? token;
  @override
  Future<String?> readAccessToken() async => token;
}

class StalledClient extends http.BaseClient {
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    (request as http.Abortable).abortTrigger!.then((_) {
      aborted = true;
    });
    return Completer<http.StreamedResponse>().future;
  }
}

const key = 'ae29ad82-93ec-433d-8948-2e8ca17c7428';
void main() {
  final config = AppConfig(apiBaseUrl: 'https://api.example.test/api/v1');
  test(
    'upload timeout aborts the transport without dropping the retry key',
    () async {
      final client = StalledClient();
      final api = ApiClient(
        config: config,
        client: client,
        uploadTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(api.close);
      await expectLater(
        ScanDatasource(api).upload(leafImage, key, (_) {}),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            AppErrorKind.timeout,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(client.aborted, true);
    },
  );
  test(
    'multipart datasource uses configured origin, original bytes, one file, progress and one response envelope',
    () async {
      final client = RecordingClient();
      final api = ApiClient(config: config, client: client);
      addTearDown(api.close);
      final progress = <double>[];
      final scan = await ScanDatasource(
        api,
      ).upload(leafImage, key, progress.add);
      expect(scan.id, savedScan.id);
      expect(
        client.sent!.url.toString(),
        'https://api.example.test/api/v1/scans',
      );
      expect(client.sent, isA<http.Abortable>());
      expect(client.sent!.followRedirects, false);
      expect(client.sent!.headers['Idempotency-Key'], key);
      expect(client.sent!.headers.containsKey('Authorization'), false);
      expect(client.body, contains('name="image"; filename="leaf.png"'));
      expect(client.body, contains('content-type: image/png'));
      expect(client.body, contains(latin1.decode(leafImage.bytes)));
      expect(progress.last, 1);
    },
  );
  test(
    'farmer token is attached; supplied missing/invalid credentials fail closed',
    () async {
      final client = RecordingClient();
      final api = ApiClient(
        config: config,
        client: client,
        tokenSource: TokenSource('aa.bb.cc'),
      );
      addTearDown(api.close);
      await ScanDatasource(api).upload(leafImage, key, (_) {});
      expect(client.sent!.headers['Authorization'], 'Bearer aa.bb.cc');
      for (final token in [null, 'bad\r\nInjected: value']) {
        final blocked = RecordingClient();
        final invalid = ApiClient(
          config: config,
          client: blocked,
          tokenSource: TokenSource(token),
        );
        addTearDown(invalid.close);
        await expectLater(
          ScanDatasource(invalid).upload(leafImage, key, (_) {}),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.authentication,
            ),
          ),
        );
        expect(blocked.sent, isNull);
      }
    },
  );
  test('server upload errors become safe actionable local messages', () async {
    for (final item in [
      (413, 'PAYLOAD_TOO_LARGE', AppErrorKind.imageTooLarge),
      (415, 'UNSUPPORTED_MEDIA_TYPE', AppErrorKind.invalidImage),
      (400, 'INVALID_IMAGE', AppErrorKind.invalidImage),
      (409, 'UPLOAD_IN_PROGRESS', AppErrorKind.uploadInProgress),
    ]) {
      final client = RecordingClient()
        ..status = item.$1
        ..errorCode = item.$2;
      final api = ApiClient(config: config, client: client);
      addTearDown(api.close);
      await expectLater(
        ScanDatasource(api).upload(leafImage, key, (_) {}),
        throwsA(
          isA<AppException>()
              .having((e) => e.kind, 'kind', item.$3)
              .having(
                (e) => e.message.contains('secret'),
                'secret leaked',
                false,
              ),
        ),
      );
    }
  });
  test('scan response rejects non-HTTPS URLs and unsupported states', () {
    final data = scanJson();
    expect(ScanRecord.fromJson(data).bytes, leafImage.bytes.length);
    data['status'] = 'UNKNOWN';
    expect(() => ScanRecord.fromJson(data), throwsA(isA<AppException>()));
    data['status'] = 'PENDING';
    (data['image'] as Map<String, Object?>)['url'] =
        'http://unsafe.example/image';
    expect(() => ScanRecord.fromJson(data), throwsA(isA<AppException>()));
  });
  test(
    'Node completed response retains typed prediction and unlocked uncertainty',
    () async {
      final client = RecordingClient()
        ..responseData = scanJson(status: ScanStatus.completed);
      final api = ApiClient(config: config, client: client);
      addTearDown(api.close);
      final record = await ScanDatasource(api).upload(leafImage, key, (_) {});
      expect(record.status, ScanStatus.completed);
      expect(record.finishedAt, isNotNull);
      expect(record.prediction?.predictedClass, 'Healthy');
      expect(record.prediction?.modelVersion, 'mobilenet-v3-small-v2-20261009');
      expect(record.prediction?.preprocessingVersion, '1.0.0');
      expect(record.prediction?.confidence, 0.7);
      expect(record.prediction?.confidenceThreshold, isNull);
      expect(
        record.prediction?.predictionStatus,
        ScanPredictionStatus.lowConfidence,
      );
      expect(
        record.prediction?.uncertaintyReason,
        ScanUncertaintyReason.thresholdUnconfigured,
      );
      expect(record.prediction?.inferenceDurationMs, 17.75);
      expect(record.prediction?.probabilities.length, 4);
    },
  );
  test(
    'typed class labels and configured uncertainty stay coherent at the threshold',
    () {
      for (final label in ScanPrediction.classLabels) {
        final data = scanJson(status: ScanStatus.completed);
        final prediction = data['prediction'] as Map<String, Object?>;
        prediction['predictedClass'] = label;
        prediction['probabilities'] = {
          for (final name in ScanPrediction.classLabels)
            name: name == label ? 0.7 : 0.1,
        };
        prediction['confidenceThreshold'] = 0.7;
        prediction['predictionStatus'] = 'CONFIDENT';
        prediction['uncertaintyReason'] = null;
        final parsed = ScanRecord.fromJson(data).prediction!;
        expect(parsed.predictedClass, label);
        expect(parsed.predictionStatus, ScanPredictionStatus.confident);
        expect(() => parsed.probabilities[label] = 0.5, throwsUnsupportedError);
        prediction['confidenceThreshold'] = 0.8;
        prediction['predictionStatus'] = 'LOW_CONFIDENCE';
        prediction['uncertaintyReason'] = 'BELOW_VALIDATION_THRESHOLD';
        expect(
          ScanRecord.fromJson(data).prediction?.uncertaintyReason,
          ScanUncertaintyReason.belowValidationThreshold,
        );
      }
    },
  );
  test(
    'malformed predictions and mismatched scan lifecycle are rejected safely',
    () {
      final mutations = <void Function(Map<String, Object?>)>[
        (data) => data['prediction'] = null,
        (data) => data['finishedAt'] = null,
        (data) => data['status'] = 'PROCESSING',
        (data) => data['analysisError'] = {'code': 'INFERENCE_FAILED'},
        (data) =>
            (data['prediction'] as Map<String, Object?>)['predictedClass'] =
                'invented_class',
        (data) => (data['prediction'] as Map<String, Object?>)['confidence'] =
            double.nan,
        (data) =>
            (data['prediction'] as Map<String, Object?>)['probabilities'] = {
              'Healthy': 1.0,
              'internalSecret': 0.0,
            },
        (data) =>
            (data['prediction'] as Map<String, Object?>)['confidence'] = 0.9,
        (data) =>
            (data['prediction'] as Map<String, Object?>)['predictionStatus'] =
                'CONFIDENT',
        (data) =>
            (data['prediction']
                    as Map<String, Object?>)['confidenceThreshold'] =
                0.8,
        (data) =>
            (data['prediction']
                    as Map<String, Object?>)['confidenceThreshold'] =
                1.0,
        (data) => (data['prediction'] as Map<String, Object?>).remove(
          'confidenceThreshold',
        ),
        (data) => (data['prediction'] as Map<String, Object?>)['modelVersion'] =
            'unsafe/path',
        (data) => (data['prediction'] as Map<String, Object?>).remove(
          'preprocessingVersion',
        ),
        (data) =>
            (data['prediction']
                    as Map<String, Object?>)['inferenceDurationMs'] =
                double.infinity,
        (data) => (data['prediction'] as Map<String, Object?>)['inferredAt'] =
            '2020-01-01T00:00:00Z',
      ];
      for (final mutate in mutations) {
        final data = scanJson(status: ScanStatus.completed);
        mutate(data);
        expect(
          () => ScanRecord.fromJson(data),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.invalidResponse,
            ),
          ),
        );
      }
      final failed = scanJson(status: ScanStatus.failed);
      failed['analysisError'] = {'code': 'PRIVATE_IMPLEMENTATION_DETAIL'};
      expect(() => ScanRecord.fromJson(failed), throwsA(isA<AppException>()));
    },
  );
  test(
    'processing and saved failure responses are valid outcomes, not upload errors',
    () async {
      for (final status in [ScanStatus.processing, ScanStatus.failed]) {
        final client = RecordingClient()
          ..responseData = scanJson(status: status);
        final api = ApiClient(config: config, client: client);
        addTearDown(api.close);
        final record = await ScanDatasource(api).upload(leafImage, key, (_) {});
        expect(record.status, status);
        expect(record.prediction, isNull);
        expect(
          record.analysisErrorCode,
          status == ScanStatus.failed ? 'INFERENCE_TIMEOUT' : null,
        );
        expect(record.toString(), isNot(contains('unsafe internal')));
      }
    },
  );
}
