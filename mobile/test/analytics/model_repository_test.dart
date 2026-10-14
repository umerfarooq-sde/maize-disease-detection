import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/data/repositories/analytics_repository.dart';
import 'helpers.dart';

Matcher failure(AppErrorKind kind) =>
    throwsA(isA<AppException>().having((error) => error.kind, 'kind', kind));
http.Response response(Object? data, {int status = 200}) => http.Response(
  jsonEncode(
    status == 200
        ? {'success': true, 'data': data, 'requestId': firstId}
        : {
            'success': false,
            'error': {'code': 'SAFE_ERROR', 'message': 'private internals'},
            'requestId': firstId,
          },
  ),
  status,
  headers: {'content-type': 'application/json'},
);
void main() {
  test(
    'date ranges preserve inclusive UTC leap days and reject reversed/oversized windows',
    () {
      expect(
        AnalyticsDateRange(
          DateTime.utc(2024, 1, 1),
          DateTime.utc(2024, 12, 31),
        ).days,
        366,
      );
      expect(AnalyticsDateRange.lastDays(30, now: clock).toQuery(), {
        'from': '2026-09-16',
        'to': '2026-10-15',
      });
      for (final endpoints in [
        [DateTime.utc(2026, 1, 2), DateTime.utc(2026, 1, 1)],
        [DateTime.utc(2024, 1, 1), DateTime.utc(2025, 1, 1)],
      ]) {
        expect(
          () => AnalyticsDateRange(endpoints[0], endpoints[1]),
          failure(AppErrorKind.validation),
        );
      }
    },
  );
  test(
    'summary retains immutable counts, every date, known/legacy labels and confidence flags',
    () {
      final summary = FarmerAnalytics.fromJson(summaryJson());
      expect(summary.totals['totalScans'], 8);
      expect(summary.totals['diseasePredictions'], 2);
      expect(summary.uncertainty['unavailable'], 1);
      expect(summary.daily.map((day) => day.count), [5, 3]);
      expect(() => summary.totals['totalScans'] = 99, throwsUnsupportedError);
      expect(() => summary.distribution.clear(), throwsUnsupportedError);
      expect(
        FarmerAnalytics.fromJson(summaryJson(empty: true)).totals['totalScans'],
        0,
      );
    },
  );
  test(
    'incoherent statuses, duplicates, invalid dates, unknown fields and negative counts fail parsing',
    () {
      final original = summaryJson();
      for (final change in [
        {
          'totals': {...original['totals'] as Map, 'totalScans': 9},
        },
        {
          'uncertainty': {'lowConfidence': 8, 'confident': 0, 'unavailable': 0},
        },
        {
          'range': {
            'from': '2026-02-30',
            'to': '2026-03-01',
            'timeZone': 'UTC',
            'days': 2,
          },
        },
        {
          'daily': [
            {'date': '2026-10-01', 'count': 5},
            {'date': '2026-10-01', 'count': 3},
          ],
        },
        {
          'distribution': List.filled(5, {'label': 'Healthy', 'count': 1}),
        },
        {'userId': 'private'},
        {'asOf': '2026-02-30T00:00:00Z'},
        {'asOf': '2026-10-15T25:00:00Z'},
      ]) {
        expect(
          () => FarmerAnalytics.fromJson({...original, ...change}),
          failure(AppErrorKind.invalidResponse),
        );
      }
    },
  );
  test(
    'activity validates range, supported labels, status, unique IDs and last-item cursor',
    () {
      final page = AnalyticsActivityPage.fromJson(activityJson(next: true));
      expect(page.items.length, 2);
      expect(page.nextCursor, secondId);
      final original = activityJson();
      for (final change in [
        {'nextCursor': thirdId},
        {'items': List.filled(2, (original['items'] as List).first)},
        {
          'items': [
            {
              'id': firstId,
              'status': 'FAILED',
              'createdAt': '2026-10-02T00:00:00Z',
              'predictedClass': 'Healthy',
            },
          ],
        },
        {
          'items': [
            {
              'id': firstId,
              'status': 'COMPLETED',
              'createdAt': '2026-10-03T00:00:00Z',
              'predictedClass': 'Healthy',
            },
          ],
        },
      ]) {
        expect(
          () => AnalyticsActivityPage.fromJson({...original, ...change}),
          failure(AppErrorKind.invalidResponse),
        );
      }
    },
  );
  test(
    'repository sends only date/cursor filters with bearer auth to Node and validates echoed range',
    () async {
      final tokens = MemorySessionTokens()
        ..save('header.payload.signature', const Duration(minutes: 5));
      final sent = <http.Request>[];
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: tokens,
        client: MockClient((request) async {
          sent.add(request);
          return response(
            request.url.path.endsWith('/activity')
                ? activityJson()
                : summaryJson(),
          );
        }),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      final repository = ApiAnalyticsRepository(api);
      await repository.summary(testRange);
      await repository.activity(testRange, cursor: firstId);
      expect(sent.first.url.path, '/api/v1/analytics/scans');
      expect(
        sent.first.headers['authorization'],
        'Bearer header.payload.signature',
      );
      expect(sent.first.url.queryParameters, testRange.toQuery());
      expect(sent.last.url.queryParameters, {
        ...testRange.toQuery(),
        'limit': '10',
        'cursor': firstId,
      });
      expect(sent.every((item) => item.body.isEmpty), true);
      await expectLater(
        repository.activity(testRange, cursor: 'invalid'),
        failure(AppErrorKind.validation),
      );
      expect(sent.length, 2);
    },
  );
  test(
    'repository rejects changed date ranges and maps network/auth/server errors safely',
    () async {
      for (final status in [200, 401, 403, 503]) {
        final tokens = MemorySessionTokens()
          ..save('header.payload.signature', const Duration(minutes: 5));
        final api = ApiClient(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          tokenSource: tokens,
          client: MockClient(
            (_) async => response(
              summaryJson(range: AnalyticsDateRange.lastDays(7, now: clock)),
              status: status,
            ),
          ),
        );
        addTearDown(api.close);
        addTearDown(tokens.dispose);
        await expectLater(
          ApiAnalyticsRepository(api).summary(testRange),
          failure(
            status == 200
                ? AppErrorKind.invalidResponse
                : status == 401
                ? AppErrorKind.authentication
                : status == 403
                ? AppErrorKind.authorization
                : AppErrorKind.server,
          ),
        );
      }
    },
  );
}
