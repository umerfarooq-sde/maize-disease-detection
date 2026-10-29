import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/models/registration_credentials.dart';
import 'package:maizedoctor/data/models/session_account.dart';
import 'package:maizedoctor/data/repositories/registration_repository.dart';
import 'package:maizedoctor/features/auth/view_models/registration_view_model.dart';
import 'session_test.dart' show response;

const registrationPassword = 'a long synthetic passphrase';
Map<String, Object?> registeredUser({String role = 'FARMER'}) => {
  'user': {
    'email': 'farmer@example.test',
    'role': role,
    'createdAt': '2026-10-15T00:00:00Z',
  },
};

class FakeRegistrationRepository implements RegistrationRepository {
  int calls = 0;
  Object? failure;
  Completer<SessionAccount>? pending;
  @override
  Future<SessionAccount> register(String email, String password) async {
    calls++;
    if (failure case final error?) throw error;
    return pending?.future ?? SessionAccount.fromJson(registeredUser()['user']);
  }
}

void main() {
  test(
    'registration email and Unicode password boundaries match server rules',
    () {
      for (final email in [
        ' FARMER@EXAMPLE.TEST ',
        "farmer.o'neil+crop@example.test",
      ]) {
        expect(RegistrationCredentials.emailError(email), isNull);
      }
      for (final email in [
        '',
        'bad',
        '.lead@example.test',
        'double..dot@example.test',
        'end.@example.test',
        'x@a.c',
        '${'a' * 244}@example.test',
      ]) {
        expect(
          RegistrationCredentials.emailError(email),
          isNotNull,
          reason: email,
        );
      }
      for (final password in [
        'a' * 6,
        'a' * 8,
        'a' * 15,
        '🌽' * 6,
        ' ' * 6,
        'a' * 128,
        '🌽' * 128,
      ]) {
        expect(RegistrationCredentials.passwordError(password), isNull);
      }
      for (final password in ['', 'a' * 5, '🌽' * 5, 'a' * 129, '🌽' * 129]) {
        expect(RegistrationCredentials.passwordError(password), isNotNull);
      }
    },
  );
  for (final (password, accepted) in [
    ('', false),
    ('a' * 5, false),
    ('a' * 6, true),
    ('a' * 8, true),
    ('a' * 15, true),
    ('a' * 128, true),
    ('a' * 129, false),
    ('🌽' * 5, false),
    ('🌽' * 6, true),
  ]) {
    test(
      'repository enforces ${password.runes.length} code points (${password.length} code units)',
      () async {
        var calls = 0;
        final api = ApiClient(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          client: MockClient((request) async {
            calls++;
            expect(jsonDecode(request.body)['password'], password);
            return response(registeredUser(), status: 201);
          }),
        );
        addTearDown(api.close);
        final operation = ApiRegistrationRepository(
          api,
        ).register('farmer@example.test', password);
        if (accepted) {
          expect((await operation).role, AccountRole.farmer);
          expect(calls, 1);
        } else {
          await expectLater(
            operation,
            throwsA(
              isA<AppException>().having(
                (e) => e.kind,
                'kind',
                AppErrorKind.validation,
              ),
            ),
          );
          expect(calls, 0);
        }
      },
    );
  }
  test(
    'repository sends only normalized email/unmodified password and creates no session',
    () async {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/register');
          expect(request.headers['X-Auth-Request'], '1');
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'email': 'farmer@example.test',
            'password': ' $registrationPassword ',
          });
          return response(registeredUser(), status: 201);
        }),
      );
      addTearDown(api.close);
      final account = await ApiRegistrationRepository(
        api,
      ).register(' FARMER@EXAMPLE.TEST ', ' $registrationPassword ');
      expect(account.role, AccountRole.farmer);
      expect(api.hasRefreshCookie, false);
      expect(api.hasAuthenticatedSession, false);
    },
  );
  for (final entry in {
    400: AppErrorKind.validation,
    409: AppErrorKind.conflict,
    429: AppErrorKind.rateLimited,
    503: AppErrorKind.server,
  }.entries) {
    test(
      'registration maps HTTP ${entry.key} without raw response text',
      () async {
        final api = ApiClient(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          client: MockClient((_) async => response(null, status: entry.key)),
        );
        addTearDown(api.close);
        await expectLater(
          ApiRegistrationRepository(
            api,
          ).register('farmer@example.test', registrationPassword),
          throwsA(
            isA<AppException>().having((e) => e.kind, 'kind', entry.value),
          ),
        );
      },
    );
  }
  test('registration rejects wrong role and malformed success', () async {
    for (final data in [
      registeredUser(role: 'ADMIN'),
      {'accessToken': 'secret'},
    ]) {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((_) async => response(data, status: 201)),
      );
      await expectLater(
        ApiRegistrationRepository(
          api,
        ).register('farmer@example.test', registrationPassword),
        throwsA(isA<AppException>()),
      );
      api.close();
    }
    final api = ApiClient(
      config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
      client: MockClient((_) async => response(registeredUser(), status: 200)),
    );
    addTearDown(api.close);
    await expectLater(
      ApiRegistrationRepository(
        api,
      ).register('farmer@example.test', registrationPassword),
      throwsA(isA<AppException>()),
    );
  });
  test('offline and timeout map safely', () async {
    for (final offline in [true, false]) {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        timeout: const Duration(milliseconds: 5),
        client: MockClient((_) async {
          if (offline) throw http.ClientException('private transport detail');
          await Future<void>.delayed(const Duration(milliseconds: 25));
          return response(registeredUser(), status: 201);
        }),
      );
      await expectLater(
        ApiRegistrationRepository(
          api,
        ).register('farmer@example.test', registrationPassword),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            offline ? AppErrorKind.network : AppErrorKind.timeout,
          ),
        ),
      );
      api.close();
    }
  });
  test('ViewModel busy guard, success guard and disposal fence', () async {
    final repo = FakeRegistrationRepository()..pending = Completer();
    final model = RegistrationViewModel(repo);
    final pending = model.register('farmer@example.test', registrationPassword);
    expect(model.busy, true);
    await model.register('farmer@example.test', registrationPassword);
    expect(repo.calls, 1);
    repo.pending!.complete(SessionAccount.fromJson(registeredUser()['user']));
    await pending;
    expect(model.registeredEmail, 'farmer@example.test');
    await model.register('farmer@example.test', registrationPassword);
    expect(repo.calls, 1);
    model.dispose();
    final disposedRepo = FakeRegistrationRepository()..pending = Completer();
    final disposed = RegistrationViewModel(disposedRepo);
    final operation = disposed.register(
      'farmer@example.test',
      registrationPassword,
    );
    disposed.dispose();
    disposedRepo.pending!.complete(
      SessionAccount.fromJson(registeredUser()['user']),
    );
    await operation;
    expect(disposed.registeredEmail, isNull);
  });
  for (final kind in [
    AppErrorKind.conflict,
    AppErrorKind.validation,
    AppErrorKind.network,
    AppErrorKind.timeout,
    AppErrorKind.server,
    AppErrorKind.rateLimited,
  ]) {
    test('ViewModel reports $kind and permits explicit retry', () async {
      final repo = FakeRegistrationRepository()..failure = AppException(kind);
      final model = RegistrationViewModel(repo);
      addTearDown(model.dispose);
      await model.register('farmer@example.test', registrationPassword);
      expect(model.error!.kind, kind);
      expect(model.errorMessage, isNotEmpty);
      expect(model.busy, false);
      repo.failure = null;
      await model.register('farmer@example.test', registrationPassword);
      expect(model.registeredEmail, isNotNull);
      expect(repo.calls, 2);
    });
  }
}
