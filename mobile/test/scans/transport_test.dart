import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/data/datasources/scan_datasource.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'helpers.dart';

class RecordingClient extends http.BaseClient {
  http.BaseRequest? sent;
  String body = '';
  int status = 201;
  String? errorCode;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent = request;
    body = latin1.decode(await request.finalize().toBytes());
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'success': errorCode == null,
            'data': scanJson(),
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
    data['status'] = 'COMPLETED';
    expect(() => ScanRecord.fromJson(data), throwsA(isA<AppException>()));
    data['status'] = 'PENDING';
    (data['image'] as Map<String, Object?>)['url'] =
        'http://unsafe.example/image';
    expect(() => ScanRecord.fromJson(data), throwsA(isA<AppException>()));
  });
}
