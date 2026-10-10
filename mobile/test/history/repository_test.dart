import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/datasources/scan_datasource.dart';
import 'package:maizedoctor/data/models/scan_history_page.dart';
import 'package:maizedoctor/data/repositories/scan_records_repository.dart';
import '../scans/transport_test.dart' show TokenSource;
import 'helpers.dart';

Matcher failure(AppErrorKind kind) =>
    throwsA(isA<AppException>().having((error) => error.kind, 'kind', kind));

http.Response response(Object? data, {int status = 200, String? code}) =>
    http.Response(
      jsonEncode({
        'success': code == null,
        'data': data,
        if (code != null)
          'error': {'code': code, 'message': 'private-provider-message'},
        'requestId': '00000000-0000-4000-8000-000000000001',
      }),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  final config = AppConfig(apiBaseUrl: 'https://api.example.test/api/v1');
  test(
    'authenticated history calls only Node with bounded limit and UUID cursor',
    () async {
      http.Request? sent;
      final api = ApiClient(
        config: config,
        tokenSource: TokenSource('header.payload.signature'),
        client: MockClient((request) async {
          sent = request;
          return response({
            'items': [historyScanJson(2)],
            'nextCursor': null,
          });
        }),
      );
      addTearDown(api.close);
      final repository = ApiScanRecordsRepository(ScanDatasource(api));
      expect(repository.hasAuthenticatedSession, true);
      final page = await repository.history(cursor: historyId(1), limit: 20);
      expect(page.items.single.id, historyId(2));
      expect(sent!.url.origin, 'https://api.example.test');
      expect(sent!.url.path, '/api/v1/scans');
      expect(sent!.url.queryParameters, {
        'limit': '20',
        'cursor': historyId(1),
      });
      expect(sent!.headers['Authorization'], 'Bearer header.payload.signature');
      expect(sent!.headers.containsKey('Idempotency-Key'), false);
      expect(sent!.followRedirects, false);
    },
  );

  test(
    'guest history and missing read capability never open a network request',
    () async {
      var requests = 0;
      final api = ApiClient(
        config: config,
        client: MockClient((_) async {
          requests++;
          return response(null);
        }),
      );
      addTearDown(api.close);
      final repository = ApiScanRecordsRepository(ScanDatasource(api));
      expect(repository.hasAuthenticatedSession, false);
      await expectLater(
        repository.history(),
        failure(AppErrorKind.authentication),
      );
      await expectLater(
        repository.read(historyId(1)),
        failure(AppErrorKind.authentication),
      );
      await expectLater(
        repository.read('https://arbitrary.example/image'),
        failure(AppErrorKind.validation),
      );
      expect(requests, 0);
    },
  );

  test(
    'guest detail sends its private key in a header and checks returned scan identity',
    () async {
      http.Request? sent;
      final api = ApiClient(
        config: config,
        client: MockClient((request) async {
          sent = request;
          return response(historyScanJson(1));
        }),
      );
      addTearDown(api.close);
      final repository = ApiScanRecordsRepository(ScanDatasource(api));
      final scan = await repository.read(
        historyId(1),
        anonymousKey: historyId(9),
      );
      expect(scan.id, historyId(1));
      expect(sent!.url.path, '/api/v1/scans/${historyId(1)}');
      expect(sent!.url.query, '');
      expect(sent!.headers['Idempotency-Key'], historyId(9));
      expect(sent!.headers.containsKey('Authorization'), false);
      await expectLater(
        repository.read(historyId(2), anonymousKey: historyId(9)),
        failure(AppErrorKind.invalidResponse),
      );
    },
  );

  test(
    'farmer detail uses authentication rather than a guest capability',
    () async {
      http.Request? sent;
      final api = ApiClient(
        config: config,
        tokenSource: TokenSource('header.payload.signature'),
        client: MockClient((request) async {
          sent = request;
          return response(historyScanJson(1));
        }),
      );
      addTearDown(api.close);
      await ApiScanRecordsRepository(
        ScanDatasource(api),
      ).read(historyId(1), anonymousKey: historyId(9));
      expect(sent!.headers['Authorization'], 'Bearer header.payload.signature');
      expect(sent!.headers.containsKey('Idempotency-Key'), false);
    },
  );

  test(
    'invalid paging inputs and malformed response pages are rejected safely',
    () async {
      var requests = 0;
      Object? data = {'items': [], 'nextCursor': null};
      final api = ApiClient(
        config: config,
        tokenSource: TokenSource('header.payload.signature'),
        client: MockClient((_) async {
          requests++;
          return response(data);
        }),
      );
      addTearDown(api.close);
      final repository = ApiScanRecordsRepository(ScanDatasource(api));
      for (final limit in [0, 51]) {
        await expectLater(
          repository.history(limit: limit),
          failure(AppErrorKind.validation),
        );
      }
      await expectLater(
        repository.history(cursor: 'untrusted/path'),
        failure(AppErrorKind.validation),
      );
      expect(requests, 0);
      for (final invalid in [
        null,
        {'items': []},
        {'items': 'not-a-list', 'nextCursor': null},
        {'items': [], 'nextCursor': historyId(1)},
        {
          'items': [historyScanJson(1)],
          'nextCursor': historyId(2),
        },
        {
          'items': [historyScanJson(1), historyScanJson(1)],
          'nextCursor': null,
        },
        {
          'items': [historyScanJson(1)],
          'nextCursor': 'private-provider-message',
        },
        {
          'items': [{}],
          'nextCursor': null,
        },
      ]) {
        data = invalid;
        await expectLater(
          repository.history(),
          failure(AppErrorKind.invalidResponse),
        );
      }
      data = {
        'items': [historyScanJson(1), historyScanJson(2)],
        'nextCursor': null,
      };
      await expectLater(
        repository.history(limit: 1),
        failure(AppErrorKind.invalidResponse),
      );
      data = {
        'items': [historyScanJson(1)],
        'nextCursor': historyId(1),
      };
      await expectLater(
        repository.history(cursor: historyId(1)),
        failure(AppErrorKind.invalidResponse),
      );
    },
  );

  test(
    'owner authorization and network failures keep safe application messages',
    () async {
      var code = 'NOT_FOUND';
      var status = 404;
      final api = ApiClient(
        config: config,
        tokenSource: TokenSource('header.payload.signature'),
        client: MockClient(
          (_) async => response(null, status: status, code: code),
        ),
      );
      addTearDown(api.close);
      final repository = ApiScanRecordsRepository(ScanDatasource(api));
      await expectLater(
        repository.read(historyId(1)),
        failure(AppErrorKind.notFound),
      );
      code = 'AUTHORIZATION_ERROR';
      status = 403;
      await expectLater(
        repository.history(),
        failure(AppErrorKind.authorization),
      );
      code = 'AUTHENTICATION_ERROR';
      status = 401;
      await expectLater(
        repository.history(),
        failure(AppErrorKind.authentication),
      );
      expect(
        const AppException(AppErrorKind.authentication).message,
        isNot(contains('private-provider-message')),
      );
    },
  );

  test(
    'history page preserves complete typed scan outcomes and nullable continuation',
    () {
      final page = ScanHistoryPage.fromJson({
        'items': [historyScanJson(1)],
        'nextCursor': historyId(1),
      });
      expect(page.items.single.prediction?.predictedClass, 'Healthy');
      expect(page.nextCursor, historyId(1));
      expect(
        ScanHistoryPage.fromJson({'items': [], 'nextCursor': null}).items,
        isEmpty,
      );
    },
  );
}
