import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_ADMIN_CHECK');
  test(
    'real Admin dashboard aggregates system data; Farmer and revoked sessions are denied',
    () async {
      final tokens = MemorySessionTokens();
      final api = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: tokens,
        timeout: const Duration(seconds: 30),
      );
      final repository = ApiAdminDashboardRepository(api);
      final admin = SessionRepository(
        api,
        tokens,
        requiredRole: AccountRole.admin,
      );
      final range = AnalyticsDateRange(
        DateTime.utc(2020, 1, 1),
        DateTime.utc(2020, 1, 2),
      );
      final expected = AdminDashboard.fromJson(
        jsonDecode(Platform.environment['ADMIN_DASHBOARD_EXPECTED']!),
      );
      try {
        await expectLater(
          repository.load(range),
          throwsA(
            isA<AppException>().having(
              (error) => error.kind,
              'kind',
              AppErrorKind.authentication,
            ),
          ),
        );
        final farmer = FarmerSessionRepository(api, tokens);
        await farmer.signIn(
          Platform.environment['ANALYTICS_OWNER_EMAIL']!,
          Platform.environment['ANALYTICS_OWNER_PASSWORD']!,
        );
        await expectLater(
          repository.load(range),
          throwsA(
            isA<AppException>().having(
              (error) => error.kind,
              'kind',
              AppErrorKind.authorization,
            ),
          ),
        );
        await farmer.signOut();
        // Reattach rotation to the Admin session after the intentionally denied Farmer request.
        final adminSession = SessionRepository(
          api,
          tokens,
          requiredRole: AccountRole.admin,
        );
        await adminSession.signIn(
          Platform.environment['ANALYTICS_ADMIN_EMAIL']!,
          Platform.environment['ANALYTICS_ADMIN_PASSWORD']!,
        );
        final result = await repository.load(range);
        expect(result.scans.totals, expected.scans.totals);
        expect(result.farmers, expected.farmers);
        expect(result.authenticatedScans, expected.authenticatedScans);
        expect(result.anonymousScans, expected.anonymousScans);
        expect(result.scans.uncertainty, expected.scans.uncertainty);
        expect(result.registry, expected.registry);
        expect(result.recent.length, 10);
        expect(
          result.scans.daily.map((day) => day.count),
          expected.scans.daily.map((day) => day.count),
        );
        for (final query in [
          {'userId': 'forged'},
          {'from': '2026-02-30', 'to': '2026-03-01'},
          {'from': '2020-01-01'},
        ]) {
          await expectLater(
            api.get('admin/dashboard', authenticated: true, query: query),
            throwsA(
              isA<AppException>().having(
                (error) => error.kind,
                'kind',
                AppErrorKind.validation,
              ),
            ),
          );
        }
        await adminSession.signOut();
        expect(repository.hasSession, false);
        await expectLater(
          repository.load(range),
          throwsA(
            isA<AppException>().having(
              (error) => error.kind,
              'kind',
              AppErrorKind.authentication,
            ),
          ),
        );
      } finally {
        admin.clear();
        api.close();
        tokens.dispose();
      }
    },
    skip: !live,
  );
}
