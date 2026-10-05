import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/constants/app_constants.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/data/datasources/backend_datasource.dart';
import 'package:maizedoctor/data/repositories/backend_repository.dart';

const correlationId = 'ae29ad82-93ec-433d-8948-2e8ca17c7428';
http.Response jsonResponse(
  Object? data, {
  int status = 200,
  bool success = true,
}) => http.Response(
  jsonEncode({
    'success': success,
    'data': data,
    'error': {'message': 'private unsafe server detail'},
    'requestId': correlationId,
  }),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Matcher errorKind(AppErrorKind kind) =>
    isA<AppException>().having((e) => e.kind, 'kind', kind);

class FakeTokenSource implements AccessTokenSource {
  FakeTokenSource(this.token);
  final Future<String?> token;
  @override
  Future<String?> readAccessToken() => token;
}

void main() {
  final config = AppConfig(apiBaseUrl: 'https://api.example.test/api/v1');
  test(
    'missing configuration keeps shell usable; invalid/release HTTP URLs fail safely',
    () {
      expect(AppConfig().isConfigured, false);
      for (final url in [
        'https://user:password@host/api/v1',
        'https://host/api/v1?secret=x',
        'https://host/other',
        'file:///api/v1',
        'https://host/api/v1#secret',
      ]) {
        expect(
          () => AppConfig(apiBaseUrl: url),
          throwsA(errorKind(AppErrorKind.configuration)),
        );
      }
      expect(
        () => AppConfig(
          apiBaseUrl: 'http://10.0.2.2:3000/api/v1',
          requireHttps: true,
        ),
        throwsA(errorKind(AppErrorKind.configuration)),
      );
      expect(
        AppConfig(apiBaseUrl: 'http://10.0.2.2:3000/api/v1/').baseUrl!.path,
        '/api/v1/',
      );
    },
  );

  test(
    'JSON requests preserve API prefix/query/UTF-8 and unwrap one envelope',
    () async {
      final api = ApiClient(
        config: config,
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.example.test/api/v1/auth/login?lang=ur',
          );
          expect(request.headers['X-Auth-Request'], '1');
          expect(request.headers.containsKey('Authorization'), false);
          expect(jsonDecode(request.body), {'label': 'مکئی'});
          expect(request.followRedirects, false);
          return jsonResponse({'label': 'مکئی'});
        }),
      );
      addTearDown(api.close);
      final response = await api.request(
        ApiMethod.post,
        'auth/login',
        body: {'label': 'مکئی'},
        query: {'lang': 'ur'},
      );
      expect(response.data, {'label': 'مکئی'});
      expect(response.requestId, correlationId);
      expect(response.isSuccessful, true);
    },
  );

  test(
    'credentials attach only to explicit authenticated requests on the configured origin',
    () async {
      final calls = <http.Request>[];
      final api = ApiClient(
        config: config,
        tokenSource: FakeTokenSource(Future.value('header.payload.signature')),
        client: MockClient((request) async {
          calls.add(request);
          return jsonResponse({});
        }),
      );
      addTearDown(api.close);
      await api.get('health');
      await api.get('auth/me', authenticated: true);
      expect(calls[0].headers.containsKey('Authorization'), false);
      expect(
        calls[1].headers['Authorization'],
        'Bearer header.payload.signature',
      );
      for (final path in [
        'https://evil.test',
        '../auth/me',
        '/auth/me',
        '%2e%2e/auth',
        'health?token=x',
      ]) {
        await expectLater(
          api.get(path, authenticated: true),
          throwsArgumentError,
        );
      }
      expect(calls.length, 2);
    },
  );

  test('missing and header-injection tokens fail before transport', () async {
    for (final token in [null, 'secret\r\nX-Injected: yes']) {
      final api = ApiClient(
        config: config,
        tokenSource: FakeTokenSource(Future.value(token)),
        client: MockClient(
          (_) async => fail('Must not send without a valid token'),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.get('auth/me', authenticated: true),
        throwsA(errorKind(AppErrorKind.authentication)),
      );
    }
  });

  for (final entry in {
    400: AppErrorKind.validation,
    401: AppErrorKind.authentication,
    403: AppErrorKind.authorization,
    404: AppErrorKind.notFound,
    409: AppErrorKind.conflict,
    429: AppErrorKind.rateLimited,
    500: AppErrorKind.server,
  }.entries) {
    test(
      'HTTP ${entry.key} maps to a safe ${entry.value.name} error',
      () async {
        final api = ApiClient(
          config: config,
          client: MockClient(
            (_) async => jsonResponse(null, status: entry.key, success: false),
          ),
        );
        addTearDown(api.close);
        try {
          await api.get('health');
          fail('Expected application error');
        } on AppException catch (error) {
          expect(error.kind, entry.value);
          expect(error.statusCode, entry.key);
          expect(error.requestId, correlationId);
          expect(error.message, isNot(contains('private')));
          expect(error.toString(), isNot(contains('private')));
        }
      },
    );
  }

  test(
    'malformed JSON, non-JSON, missing envelope and oversized bodies fail safely',
    () async {
      for (final response in [
        http.Response(
          '{bad',
          200,
          headers: {'content-type': 'application/json'},
        ),
        http.Response(
          'private html',
          500,
          headers: {'content-type': 'text/html'},
        ),
        http.Response('[]', 200, headers: {'content-type': 'application/json'}),
        http.Response(
          'x' * (AppConstants.maxResponseBytes + 1),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ]) {
        final api = ApiClient(
          config: config,
          client: MockClient((_) async => response),
        );
        addTearDown(api.close);
        await expectLater(
          api.get('health'),
          throwsA(errorKind(AppErrorKind.invalidResponse)),
        );
      }
    },
  );

  test(
    'timeout bounds body reception and aborts supported transports',
    () async {
      var aborted = false;
      // Use a non-completing body so timeout covers decoding, not only headers.
      final body = StreamController<List<int>>();
      final slow = ApiClient(
        config: config,
        timeout: const Duration(milliseconds: 10),
        client: MockClient.streaming((request, _) async {
          (request as http.AbortableRequest).abortTrigger!.then((_) {
            aborted = true;
          });
          return http.StreamedResponse(
            body.stream,
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(slow.close);
      await expectLater(
        slow.get('health'),
        throwsA(errorKind(AppErrorKind.timeout)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(aborted, true);
      await body.close();
    },
  );

  test('late token lookup cannot send a request after timeout', () async {
    final token = Completer<String?>();
    var calls = 0;
    final api = ApiClient(
      config: config,
      tokenSource: FakeTokenSource(token.future),
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) async {
        calls++;
        return jsonResponse({});
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.get('auth/me', authenticated: true),
      throwsA(errorKind(AppErrorKind.timeout)),
    );
    token.complete('header.payload.signature');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
  });

  test(
    'transport exceptions and closed/unconfigured clients do not expose details',
    () async {
      final api = ApiClient(
        config: config,
        client: MockClient(
          (_) async => throw http.ClientException('private token and URL'),
        ),
      );
      await expectLater(
        api.get('health'),
        throwsA(errorKind(AppErrorKind.network)),
      );
      api.close();
      api.close();
      await expectLater(
        api.get('health'),
        throwsA(errorKind(AppErrorKind.network)),
      );
      final unset = ApiClient(config: AppConfig());
      addTearDown(unset.close);
      await expectLater(
        unset.get('health'),
        throwsA(errorKind(AppErrorKind.configuration)),
      );
    },
  );

  test(
    'repository decodes healthy/degraded reports; ordinary HTTP 503 still fails',
    () async {
      for (final status in [200, 503]) {
        final api = ApiClient(
          config: config,
          client: MockClient(
            (_) async => jsonResponse({
              'status': status == 200 ? 'ok' : 'degraded',
              'timestamp': '2026-10-06T00:00:00Z',
              'checks': {'database': status == 200 ? 'up' : 'down'},
            }, status: status),
          ),
        );
        addTearDown(api.close);
        final repository = ApiBackendRepository(BackendDatasource(api));
        expect((await repository.checkConnection()).isAvailable, status == 200);
        if (status == 503) {
          await expectLater(
            api.get('health'),
            throwsA(errorKind(AppErrorKind.server)),
          );
        }
      }
    },
  );

  test('repository rejects inconsistent health payloads', () async {
    final api = ApiClient(
      config: config,
      client: MockClient(
        (_) async => jsonResponse({
          'status': 'ok',
          'timestamp': 'invalid',
          'checks': {'database': 'down'},
        }),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      ApiBackendRepository(BackendDatasource(api)).checkConnection(),
      throwsA(errorKind(AppErrorKind.invalidResponse)),
    );
  });
}
