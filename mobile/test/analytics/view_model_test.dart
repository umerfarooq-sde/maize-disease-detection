import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/features/analytics/view_models/analytics_view_model.dart';
import 'helpers.dart';

AnalyticsViewModel model(FakeAnalyticsRepository repository) {
  final value = AnalyticsViewModel(repository, now: () => clock);
  addTearDown(value.dispose);
  return value;
}

void main() {
  test(
    'guest never requests personal analytics or exposes cached farmer data',
    () async {
      final repository = FakeAnalyticsRepository()
        ..hasAuthenticatedSession = false;
      final view = model(repository);
      await view.load();
      expect(view.signedIn, false);
      expect(view.summary, isNull);
      expect(repository.summaryCalls, isEmpty);
    },
  );
  test(
    'load/filter/grouped chart periods account for every day and scan once',
    () async {
      final repository = FakeAnalyticsRepository();
      final view = model(repository);
      await view.load();
      expect(view.range.days, 30);
      expect(view.summary!.totals['totalScans'], 8);
      expect(view.periods.length, lessThanOrEqualTo(6));
      expect(view.periods.fold<int>(0, (sum, period) => sum + period.count), 8);
      expect(view.periods.first.from, view.range.from);
      expect(view.periods.last.to, view.range.to);
      await view.selectDays(7);
      expect(repository.summaryCalls.last.days, 7);
      await view.selectCalendarRange(
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 2),
      );
      expect(view.range.same(testRange), true);
    },
  );
  test(
    'invalid future and oversized calendar choices keep the previous range and issue no request',
    () async {
      final repository = FakeAnalyticsRepository();
      final view = model(repository);
      await view.load();
      final calls = repository.summaryCalls.length;
      await view.selectCalendarRange(
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2025, 1, 1),
      );
      expect(view.filterError, isNotNull);
      expect(repository.summaryCalls.length, calls);
      await view.selectCalendarRange(
        DateTime.utc(2026, 10, 16),
        DateTime.utc(2026, 10, 16),
      );
      expect(view.filterError, isNotNull);
      expect(view.range.days, 30);
    },
  );
  test(
    'pagination appends bounded unique activity and terminates at null cursor',
    () async {
      final repository = FakeAnalyticsRepository()
        ..onActivity = (range, cursor) async => AnalyticsActivityPage.fromJson(
          activityJson(
            range: range,
            next: cursor == null,
            last: cursor != null,
          ),
        );
      final view = model(repository);
      await view.load();
      expect(view.activity.length, 2);
      expect(view.hasMore, true);
      await view.loadMore();
      expect(view.activity.length, 3);
      expect(view.hasMore, false);
      expect(repository.activityCalls, [null, secondId]);
    },
  );
  test(
    'failed page keeps valid summary and supports retry; failed refresh clears old counts',
    () async {
      final repository = FakeAnalyticsRepository()
        ..onActivity = (range, cursor) async {
          if (cursor != null) throw const AppException(AppErrorKind.network);
          return AnalyticsActivityPage.fromJson(
            activityJson(range: range, next: true),
          );
        };
      final view = model(repository);
      await view.load();
      await view.loadMore();
      expect(view.moreError!.kind, AppErrorKind.network);
      expect(view.summary, isNotNull);
      expect(view.activity.length, 2);
      repository.onSummary = (_) async =>
          throw const AppException(AppErrorKind.server);
      await view.load();
      expect(view.summary, isNull);
      expect(view.activity, isEmpty);
      expect(view.error!.kind, AppErrorKind.server);
    },
  );
  test(
    'sign-out and another farmer revision immediately hide stored statistics',
    () async {
      final repository = FakeAnalyticsRepository();
      final view = model(repository);
      await view.load();
      repository.hasAuthenticatedSession = false;
      repository.sessionRevision = 2;
      expect(view.summary, isNull);
      expect(view.activity, isEmpty);
      expect(view.hasMore, false);
      repository.hasAuthenticatedSession = true;
      repository.sessionRevision = 3;
      expect(view.summary, isNull);
      expect(view.activity, isEmpty);
    },
  );
  test(
    'late replies after account switch, disposal or new date range cannot overwrite current data',
    () async {
      for (final action in ['identity', 'dispose', 'range']) {
        final repository = FakeAnalyticsRepository();
        final delayed = Completer<FarmerAnalytics>();
        repository.onSummary = (_) => delayed.future;
        final view = AnalyticsViewModel(repository, now: () => clock);
        final pending = view.load();
        if (action == 'identity') repository.sessionRevision = 2;
        if (action == 'dispose') view.dispose();
        if (action == 'range') {
          repository.onSummary = (range) async =>
              FarmerAnalytics.fromJson(summaryJson(range: range));
          await view.selectDays(7);
        }
        delayed.complete(
          FarmerAnalytics.fromJson(
            summaryJson(range: AnalyticsDateRange.lastDays(30, now: clock)),
          ),
        );
        await pending;
        if (action == 'range') {
          expect(view.summary!.range.days, 7);
        } else {
          expect(view.summary, isNull);
        }
        if (action != 'dispose') view.dispose();
      }
    },
  );
  test(
    'expired authentication clears data and returns the sign-in state',
    () async {
      final repository = FakeAnalyticsRepository();
      final view = model(repository);
      await view.load();
      repository.onSummary = (_) async =>
          throw const AppException(AppErrorKind.authentication);
      await view.load();
      expect(view.signedIn, false);
      expect(view.summary, isNull);
      expect(view.activity, isEmpty);
    },
  );
}
