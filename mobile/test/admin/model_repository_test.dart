import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/models/admin_dashboard.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/data/models/session_account.dart';
import 'package:maizedoctor/data/repositories/admin_dashboard_repository.dart';
import 'package:maizedoctor/data/repositories/session_repository.dart';
import 'package:maizedoctor/data/repositories/farmer_session_repository.dart';
import '../analytics/helpers.dart' show testRange;
import '../auth/session_test.dart' show grant, cookie, response;
import 'helpers.dart';

void main() {
  test(
    'dashboard parses conserved global aggregates, bounded recent items and honest registry/telemetry state',
    () {
      final value = AdminDashboard.fromJson(dashboardJson());
      expect(value.scans.totals['totalScans'], 8);
      expect(value.anonymousScans, 3);
      expect(value.farmers['total'], 3);
      expect(value.recent.single.anonymous, true);
      expect(value.registry, 'NOT_PROMOTED');
      expect(value.productionVersion, isNull);
      expect(() => value.farmers.clear(), throwsUnsupportedError);
      for (final change in [
        {
          'ownership': {'authenticated': 50, 'anonymous': 3},
        },
        {
          'farmers': {
            'total': 4,
            'active': 1,
            'suspended': 1,
            'deactivated': 1,
          },
        },
        {'aiRequestStatistics': 'INVENTED'},
        {'recent': List.filled(11, (dashboardJson()['recent'] as List).first)},
        {
          'model': {...dashboardJson()['model'] as Map, 'readiness': 'READY'},
        },
        {
          'model': {
            ...dashboardJson()['model'] as Map,
            'registry': 'SINGLE_PRODUCTION',
          },
        },
        {'email': 'private'},
      ]) {
        expect(
          () => AdminDashboard.fromJson({...dashboardJson(), ...change}),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
  test(
    'repository uses bearer Node admin route and rejects changed range or malformed output',
    () async {
      final tokens = MemorySessionTokens()
        ..save('admin.access.token', const Duration(minutes: 10));
      final requests = <http.Request>[];
      var altered = false;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: tokens,
        client: MockClient((request) async {
          requests.add(request);
          return response(
            dashboardJson(
              range: altered
                  ? AnalyticsDateRange(testRange.from, testRange.from)
                  : testRange,
            ),
          );
        }),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      final repository = ApiAdminDashboardRepository(api);
      expect((await repository.load(testRange)).authenticatedScans, 5);
      expect(requests.single.url.path, '/api/v1/admin/dashboard');
      expect(
        requests.single.headers['authorization'],
        'Bearer admin.access.token',
      );
      expect(requests.single.url.queryParameters, testRange.toQuery());
      altered = true;
      await expectLater(
        repository.load(testRange),
        throwsA(isA<AppException>()),
      );
      final other = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: tokens,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {'broken': true},
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(other.close);
      await expectLater(
        ApiAdminDashboardRepository(other).load(testRange),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'Admin and Farmer sessions reject the opposite role and revoke rejected refresh grants',
    () async {
      for (final admin in [true, false]) {
        final tokens = MemorySessionTokens();
        final requests = <String>[];
        final api = ApiClient(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          tokenSource: tokens,
          client: MockClient((request) async {
            requests.add(request.url.path);
            return response(
              request.url.path.endsWith('/login')
                  ? grant(role: admin ? 'FARMER' : 'ADMIN')
                  : null,
              setCookie: cookie,
            );
          }),
        );
        final session = admin
            ? SessionRepository(api, tokens, requiredRole: AccountRole.admin)
            : FarmerSessionRepository(api, tokens);
        await expectLater(
          session.signIn('user@example.test', 'synthetic password'),
          throwsA(
            isA<AppException>().having(
              (error) => error.kind,
              'kind',
              AppErrorKind.authorization,
            ),
          ),
        );
        expect(tokens.hasSession, false);
        expect(api.hasRefreshCookie, false);
        expect(requests, ['/api/v1/auth/login', '/api/v1/auth/logout']);
        api.close();
        tokens.dispose();
      }
    },
  );
  test(
    'isolated Admin rotation/logout never transfers credentials to the Farmer client',
    () async {
      final adminTokens = MemorySessionTokens();
      final farmerTokens = MemorySessionTokens();
      final paths = <String>[];
      final config = AppConfig(apiBaseUrl: 'https://api.example.test/api/v1');
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return response(
          request.url.path.endsWith('/logout')
              ? null
              : grant(role: 'ADMIN', expires: 1),
          setCookie: cookie,
        );
      });
      final adminApi = ApiClient(
        config: config,
        tokenSource: adminTokens,
        client: client,
      );
      final farmerApi = ApiClient(
        config: config,
        tokenSource: farmerTokens,
        client: client,
      );
      final session = SessionRepository(
        adminApi,
        adminTokens,
        requiredRole: AccountRole.admin,
      );
      await session.signIn('admin@example.test', 'synthetic password');
      expect(session.account!.role, AccountRole.admin);
      expect(farmerApi.hasAuthenticatedSession, false);
      expect(farmerApi.hasRefreshCookie, false);
      expect(await adminTokens.readAccessToken(), 'header.payload.signature');
      expect(paths.last, '/api/v1/auth/refresh');
      await session.signOut();
      expect(adminApi.hasAuthenticatedSession, false);
      expect(paths.last, '/api/v1/auth/logout');
      adminApi.close();
      farmerApi.close();
      adminTokens.dispose();
      farmerTokens.dispose();
    },
  );
}
