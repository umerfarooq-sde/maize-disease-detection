import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/features/analytics/view_models/analytics_view_model.dart';
import 'package:maizedoctor/features/analytics/views/analytics_view.dart';
import 'helpers.dart';

Future<AnalyticsViewModel> mount(
  WidgetTester tester,
  FakeAnalyticsRepository repository, {
  ValueChanged<String>? onOpen,
  double scale = 1,
}) async {
  final model = AnalyticsViewModel(repository, now: () => clock);
  addTearDown(model.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: model,
          child: AnalyticsView(onOpenScan: onOpen),
        ),
      ),
    ),
  );
  unawaited(model.load());
  await tester.pump();
  return model;
}

void main() {
  testWidgets(
    'real router supplies private analytics state and never requests guest data',
    (tester) async {
      final requests = <Uri>[];
      await tester.pumpWidget(
        MainApp(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return http.Response('{}', 500);
          }),
          initialLocation: '/profile/analytics',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in to see your field insights'), findsOneWidget);
      expect(requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('guest sees private-account gate without any analytics request', (
    tester,
  ) async {
    final repository = FakeAnalyticsRepository()
      ..hasAuthenticatedSession = false;
    await mount(tester, repository);
    expect(find.text('Sign in to see your field insights'), findsOneWidget);
    expect(find.textContaining('Guest scans stay anonymous'), findsOneWidget);
    expect(repository.summaryCalls, isEmpty);
    expect(find.text('Saved scans'), findsNothing);
  });

  testWidgets('empty account shows scan CTA instead of fabricated charts', (
    tester,
  ) async {
    final repository = FakeAnalyticsRepository()
      ..onSummary = (range) async {
        return FarmerAnalytics.fromJson(summaryJson(range: range, empty: true));
      }
      ..onActivity = (range, _) async => AnalyticsActivityPage.fromJson(
        activityJson(range: range, empty: true),
      );
    await mount(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('No saved scans in this period'), findsOneWidget);
    expect(find.text('Scan a leaf'), findsOneWidget);
    expect(find.text('Scans over time'), findsNothing);
  });

  testWidgets(
    'private counts, distribution, uncertainty and inclusive periods are explained',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester, FakeAnalyticsRepository());
      await tester.pumpAndSettle();
      for (final text in [
        'Saved scans',
        'Healthy model labels',
        'Disease model labels',
        'Scans over time',
        'Model label distribution',
        'Low confidence: 2',
        'Confident flag: 1',
        'Legacy / unavailable flag: 1',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(
        find.textContaining('Correctness has not been measured.'),
        findsNWidgets(2),
      );
      expect(find.textContaining('do not measure how often'), findsOneWidget);
      await tester.ensureVisible(find.text('Healthy'));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Healthy: 1 model predictions')),
        findsWidgets,
      );
      semantics.dispose();
    },
  );

  testWidgets('loading and network failure allow a successful retry', (
    tester,
  ) async {
    final pending = Completer<FarmerAnalytics>();
    final repository = FakeAnalyticsRepository()
      ..onSummary = (_) => pending.future;
    await mount(tester, repository);
    expect(find.textContaining('Loading your field insights'), findsOneWidget);
    pending.completeError(const AppException(AppErrorKind.network));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your internet'), findsOneWidget);
    repository.onSummary = (range) async =>
        FarmerAnalytics.fromJson(summaryJson(range: range));
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Saved scans'), findsOneWidget);
  });

  testWidgets('date preset reloads; pagination opens the selected owned scan', (
    tester,
  ) async {
    String? opened;
    final repository = FakeAnalyticsRepository()
      ..onActivity = (range, cursor) async => AnalyticsActivityPage.fromJson(
        activityJson(range: range, next: cursor == null, last: cursor != null),
      );
    await mount(tester, repository, onOpen: (id) => opened = id);
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(repository.summaryCalls.last.days, 7);
    await tester.ensureVisible(find.text('Load more activity'));
    await tester.tap(find.text('Load more activity'));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('analytics-activity-$thirdId'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    expect(opened, thirdId);
    expect(find.text('Load more activity'), findsNothing);
  });

  testWidgets(
    'narrow screen with large text and keyboard scrolls without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await mount(tester, FakeAnalyticsRepository(), scale: 2);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recent activity'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
