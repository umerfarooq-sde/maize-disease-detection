import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/repositories/farmer_session_repository.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import '../core/api_client_test.dart' show errorKind;

Map<String, Object?> grant({String role = 'FARMER', int expires = 900}) => {
  'accessToken': 'header.payload.signature',
  'tokenType': 'Bearer',
  'expiresIn': expires,
  'user': {
    'email': 'farmer@example.test',
    'role': role,
    'createdAt': '2026-10-10T00:00:00.000Z',
  },
};
const cookie =
    '__Host-maizedoctor_refresh=refresh.payload.signature; Path=/; HttpOnly; Secure; SameSite=Strict';
http.Response response(Object? data, {int status = 200, String? setCookie}) =>
    http.Response(
      jsonEncode({'success': status < 300, 'data': data, 'error': {}}),
      status,
      headers: {'content-type': 'application/json', 'set-cookie': ?setCookie},
    );

class SessionFixture {
  SessionFixture(http.Client client) {
    api = ApiClient(
      config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
      client: client,
      tokenSource: tokens,
    );
    repository = FarmerSessionRepository(api, tokens);
    model = FarmerSessionViewModel(repository);
    addTearDown(() {
      model.dispose();
      tokens.dispose();
      api.close();
    });
  }
  final tokens = MemorySessionTokens();
  late final ApiClient api;
  late final FarmerSessionRepository repository;
  late final FarmerSessionViewModel model;
  Future<void> login() =>
      repository.signIn(' FARMER@Example.test ', 'synthetic-password');
}

class DelayedBodyClient extends http.BaseClient {
  DelayedBodyClient() {
    body = StreamController<List<int>>(onListen: () => received.complete());
  }
  late final StreamController<List<int>> body;
  final received = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/scans')) {
      return http.StreamedResponse(
        body.stream,
        401,
        headers: {'content-type': 'application/json'},
      );
    }
    final result = response(grant(), setCookie: cookie);
    return http.StreamedResponse(
      Stream.value(result.bodyBytes),
      result.statusCode,
      headers: result.headers,
    );
  }
}

void main() {
  test(
    'closing the client fences a delayed login grant and refresh cookie',
    () async {
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      final fixture = SessionFixture(
        MockClient((request) {
          started.complete();
          return gate.future;
        }),
      );
      final rejected = expectLater(
        fixture.login(),
        throwsA(errorKind(AppErrorKind.network)),
      );
      await started.future;
      fixture.api.close();
      gate.complete(response(grant(), setCookie: cookie));
      await rejected;
      expect(fixture.tokens.hasSession, false);
      expect(fixture.api.hasRefreshCookie, false);
    },
  );
  test(
    'farmer login normalizes email; credentials stay on auth routes',
    () async {
      final requests = <http.Request>[];
      final fixture = SessionFixture(
        MockClient((request) async {
          requests.add(request);
          return response(grant(), setCookie: cookie);
        }),
      );
      await fixture.login();
      expect(jsonDecode(requests.first.body)['email'], 'farmer@example.test');
      expect(fixture.model.signedIn, true);
      expect(fixture.model.account!.email, 'farmer@example.test');
      await fixture.api.get('scans', authenticated: true);
      expect(
        requests.last.headers['Authorization'],
        'Bearer header.payload.signature',
      );
      expect(requests.last.headers['Cookie'], isNull);
      await fixture.repository.signOut();
      expect(requests.last.url.path, endsWith('/auth/logout'));
      expect(
        requests.last.headers['Cookie'],
        startsWith('__Host-maizedoctor_refresh='),
      );
      expect(fixture.tokens.hasSession, false);
      expect(fixture.api.hasRefreshCookie, false);
    },
  );

  test('wrong password and invalid input return safe errors', () async {
    var calls = 0;
    final fixture = SessionFixture(
      MockClient((request) async {
        calls++;
        return response({'passwordHash': 'unsafe'}, status: 401);
      }),
    );
    await fixture.model.signIn('invalid', 'x');
    expect(fixture.model.error!.kind, AppErrorKind.validation);
    expect(calls, 0);
    await fixture.model.signIn('farmer@example.test', 'wrong');
    expect(fixture.model.error!.kind, AppErrorKind.authentication);
    expect(fixture.model.error.toString(), isNot(contains('unsafe')));
    expect(fixture.model.signedIn, false);
  });

  for (final mode in ['admin', 'no-cookie', 'bad-cookie', 'bad-token']) {
    test('reject $mode grant and retain no credentials', () async {
      var logout = 0;
      final fixture = SessionFixture(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/logout')) {
            logout++;
            return response(null);
          }
          final value = grant(role: mode == 'admin' ? 'ADMIN' : 'FARMER');
          if (mode == 'bad-token') value['accessToken'] = 'unsafe';
          return response(
            value,
            setCookie: mode == 'no-cookie'
                ? null
                : mode == 'bad-cookie'
                ? 'maizedoctor_refresh=a.b.c; Path=/; SameSite=Strict'
                : cookie,
          );
        }),
      );
      await expectLater(fixture.login(), throwsA(isA<AppException>()));
      expect(fixture.tokens.hasSession, false);
      expect(fixture.api.hasRefreshCookie, false);
      expect(logout, mode == 'admin' || mode == 'bad-token' ? 1 : 0);
    });
  }

  test(
    'short-lived tokens refresh once for concurrent protected requests',
    () async {
      var refreshes = 0;
      final gate = Completer<void>();
      final started = Completer<void>();
      final fixture = SessionFixture(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return response(grant(expires: 1), setCookie: cookie);
          }
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshes++;
            started.complete();
            expect(
              request.headers['Cookie'],
              startsWith('__Host-maizedoctor_refresh='),
            );
            await gate.future;
            return response(grant(), setCookie: cookie);
          }
          expect(request.headers['Cookie'], isNull);
          expect(request.headers['Authorization'], isNotNull);
          return response([]);
        }),
      );
      await fixture.login();
      final revision = fixture.tokens.revision;
      final first = fixture.api.get('scans', authenticated: true);
      final second = fixture.api.get('scans', authenticated: true);
      await started.future;
      gate.complete();
      await Future.wait([first, second]);
      expect(refreshes, 1);
      expect(fixture.tokens.revision, revision);
    },
  );

  test('offline refresh fails closed and never submits anonymously', () async {
    var protectedCalls = 0;
    final fixture = SessionFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return response(grant(expires: 1), setCookie: cookie);
        }
        if (request.url.path.endsWith('/auth/refresh')) {
          throw http.ClientException('private connection detail');
        }
        protectedCalls++;
        return response(null);
      }),
    );
    await fixture.login();
    await expectLater(
      fixture.api.get('scans', authenticated: true),
      throwsA(errorKind(AppErrorKind.network)),
    );
    expect(protectedCalls, 0);
    expect(fixture.api.hasAuthenticatedSession, true);
  });

  test(
    'offline logout forgets local session and exposes retryable safe error',
    () async {
      final fixture = SessionFixture(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return response(grant(), setCookie: cookie);
          }
          throw http.ClientException('private server path');
        }),
      );
      await fixture.login();
      await fixture.model.signOut();
      expect(fixture.model.signedIn, false);
      expect(fixture.model.error!.kind, AppErrorKind.network);
      expect(fixture.api.hasRefreshCookie, false);
      expect(fixture.tokens.hasSession, false);
    },
  );

  test('current authenticated401 clears session', () async {
    final fixture = SessionFixture(
      MockClient(
        (request) async => request.url.path.endsWith('/auth/login')
            ? response(grant(), setCookie: cookie)
            : response(null, status: 401),
      ),
    );
    await fixture.login();
    await expectLater(
      fixture.api.get('scans', authenticated: true),
      throwsA(errorKind(AppErrorKind.authentication)),
    );
    expect(fixture.model.signedIn, false);
    expect(fixture.api.hasRefreshCookie, false);
  });

  test('delayed old401 body cannot clear a new login', () async {
    final client = DelayedBodyClient();
    final fixture = SessionFixture(client);
    await fixture.login();
    final pending = fixture.api.get('scans', authenticated: true);
    final rejected = expectLater(
      pending,
      throwsA(errorKind(AppErrorKind.authentication)),
    );
    await client.received.future;
    fixture.repository.clear();
    await fixture.login();
    client.body.add(utf8.encode(jsonEncode({'success': false, 'error': {}})));
    await client.body.close();
    await rejected;
    expect(fixture.model.signedIn, true);
    expect(fixture.api.hasRefreshCookie, true);
  });

  test('old refresh failure cannot revoke new session', () async {
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    var logins = 0;
    final fixture = SessionFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          logins++;
          return response(
            grant(expires: logins == 1 ? 1 : 900),
            setCookie: cookie,
          );
        }
        started.complete();
        return gate.future;
      }),
    );
    await fixture.login();
    final rejected = expectLater(
      fixture.api.get('scans', authenticated: true),
      throwsA(errorKind(AppErrorKind.authentication)),
    );
    await started.future;
    fixture.repository.clear();
    await fixture.login();
    gate.complete(response(null, status: 401));
    await rejected;
    expect(fixture.model.signedIn, true);
    expect(fixture.api.hasRefreshCookie, true);
  });

  test(
    'credentials are absent in a new app session and lifecycle revisions advance',
    () async {
      final first = MemorySessionTokens();
      final second = MemorySessionTokens();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first.save('a.b.c', const Duration(minutes: 15));
      expect(first.revision, 1);
      first.save('d.e.f', const Duration(minutes: 15));
      expect(first.revision, 1);
      expect(await second.readAccessToken(), isNull);
      first.invalidate();
      expect(first.revision, 2);
      expect(await first.readAccessToken(), isNull);
    },
  );
}
