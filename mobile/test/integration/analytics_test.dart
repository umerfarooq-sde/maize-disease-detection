import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/data/repositories/analytics_repository.dart';
import 'package:maizedoctor/data/repositories/farmer_session_repository.dart';

Matcher _failure(AppErrorKind kind) =>
    throwsA(isA<AppException>().having((error) => error.kind, 'kind', kind));
void main() {
  const live = bool.fromEnvironment('RUN_LIVE_ANALYTICS_CHECK');
  test(
    'real farmer analytics preserve private aggregates/date pages and reject cross-owner access',
    () async {
      final tokens = MemorySessionTokens();
      final api = ApiClient(
        config: AppConfig.fromEnvironment(),
        tokenSource: tokens,
        timeout: const Duration(seconds: 30),
      );
      final repository = ApiAnalyticsRepository(api);
      final session = FarmerSessionRepository(api, tokens);
      final range = AnalyticsDateRange(
        DateTime.utc(2020, 1, 1),
        DateTime.utc(2020, 1, 2),
      );
      try {
        await expectLater(
          repository.summary(range),
          _failure(AppErrorKind.authentication),
        );
        await session.signIn(
          Platform.environment['ANALYTICS_OWNER_EMAIL']!,
          Platform.environment['ANALYTICS_OWNER_PASSWORD']!,
        );
        final summary = await repository.summary(range);
        expect(summary.totals['totalScans'], 8);
        expect(summary.totals['withPrediction'], 4);
        expect(summary.totals['healthyPredictions'], 1);
        expect(summary.totals['diseasePredictions'], 2);
        expect(summary.totals['otherPredictions'], 1);
        expect(summary.uncertainty['lowConfidence'], 2);
        expect(summary.daily.map((item) => item.count), [5, 3]);
        final oneDay = await repository.summary(
          AnalyticsDateRange(
            DateTime.utc(2020, 1, 2),
            DateTime.utc(2020, 1, 2),
          ),
        );
        expect(oneDay.totals['totalScans'], 3);
        final first = AnalyticsActivityPage.fromJson(
          (await api.get(
            'analytics/scans/activity',
            authenticated: true,
            query: {...range.toQuery(), 'limit': '2'},
          )).data,
        );
        expect(first.items.length, 2);
        expect(first.nextCursor, isNotNull);
        final next = AnalyticsActivityPage.fromJson(
          (await api.get(
            'analytics/scans/activity',
            authenticated: true,
            query: {
              ...range.toQuery(),
              'limit': '2',
              'cursor': first.nextCursor!,
            },
          )).data,
        );
        expect(
          next.items.every(
            (item) => !first.items.any((before) => before.id == item.id),
          ),
          true,
        );
        for (final key in [
          'ANALYTICS_FOREIGN_CURSOR',
          'ANALYTICS_ANONYMOUS_CURSOR',
        ]) {
          await expectLater(
            repository.activity(range, cursor: Platform.environment[key]!),
            _failure(AppErrorKind.notFound),
          );
        }
        for (final query in [
          {'from': '2020-02-30', 'to': '2020-03-01'},
          {'from': '2020-01-01'},
          {'userId': '00000000-0000-4000-8000-000000000001'},
        ]) {
          await expectLater(
            api.get('analytics/scans', authenticated: true, query: query),
            _failure(AppErrorKind.validation),
          );
        }
        await session.signOut();
        await session.signIn(
          Platform.environment['ANALYTICS_EMPTY_EMAIL']!,
          Platform.environment['ANALYTICS_EMPTY_PASSWORD']!,
        );
        expect((await repository.summary(range)).totals['totalScans'], 0);
        expect((await repository.activity(range)).items, isEmpty);
        await expectLater(
          repository.activity(range, cursor: first.items.first.id),
          _failure(AppErrorKind.notFound),
        );
        await session.signOut();
        final grant = await api.request(
          ApiMethod.post,
          'auth/login',
          body: {
            'email': Platform.environment['ANALYTICS_ADMIN_EMAIL']!,
            'password': Platform.environment['ANALYTICS_ADMIN_PASSWORD']!,
          },
        );
        final data = grant.data as Map<String, dynamic>;
        tokens.save(data['accessToken'] as String, const Duration(minutes: 5));
        await expectLater(
          repository.summary(range),
          _failure(AppErrorKind.authorization),
        );
      } finally {
        api.close();
        tokens.dispose();
      }
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
