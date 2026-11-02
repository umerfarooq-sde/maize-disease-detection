import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/data/models/scan_history_page.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/home/view_models/home_view_model.dart';
import 'package:maizedoctor/features/home/views/home_view.dart';
import 'package:maizedoctor/features/disease_detection/views/result_view.dart';
import '../auth/session_test.dart' show grant, response, cookie;
import '../history/helpers.dart' as history;
import '../scans/helpers.dart' show FakeScanRepository, leafImage;
import '../scans/widget_test.dart' show tapVisible;
import '../features/home_view_model_test.dart' show ControlledRepository;
import '../support/design_fonts.dart';

void main() {
  setUpAll(loadDesignFonts);
  test(
    'recent projection is bounded, shares no pagination, guests never fetch',
    () async {
      final records = history.FakeScanRecordsRepository()
        ..hasAuthenticatedSession = false;
      final model = HomeViewModel(ControlledRepository(), records: records);
      addTearDown(model.dispose);
      await model.loadRecentScans();
      expect(records.requests, isEmpty);
      records.hasAuthenticatedSession = true;
      records.responses.add(
        Future.value(
          ScanHistoryPage(
            items: [for (var i = 1; i <= 4; i++) history.historyScan(i)],
            nextCursor: history.historyId(4),
          ),
        ),
      );
      await model.loadRecentScans();
      expect(records.requests.single.limit, 3);
      expect(records.requests.single.cursor, isNull);
      expect(model.recentScans, hasLength(3));
      expect(model.recentLoading, false);
      records.hasAuthenticatedSession = false;
      expect(model.recentScans, isEmpty);
    },
  );

  test(
    'pending history suppresses duplicates, failure is not empty success, retry and disposal fence work',
    () async {
      final records = history.FakeScanRecordsRepository();
      final pending = Completer<ScanHistoryPage>();
      records.responses.add(pending.future);
      final model = HomeViewModel(ControlledRepository(), records: records);
      final load = model.loadRecentScans();
      await model.loadRecentScans();
      expect(records.requests, hasLength(1));
      expect(model.recentLoading, true);
      pending.completeError(const AppException(AppErrorKind.network));
      await load;
      expect(model.recentError?.kind, AppErrorKind.network);
      expect(model.recentLoading, false);
      await model.loadRecentScans();
      expect(model.recentError, isNull);
      final late = Completer<ScanHistoryPage>();
      records.responses.add(late.future);
      final last = model.loadRecentScans();
      model.dispose();
      late.complete(
        ScanHistoryPage(items: [history.historyScan(1)], nextCursor: null),
      );
      await last;
      expect(model.recentScans, isEmpty);
    },
  );

  testWidgets(
    'guest Home primary CTA, Profile and three shortcuts never request private history',
    (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(
        MainApp(
          scanRepository: FakeScanRepository(),
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            requests.add(request.url.path);
            return response(null, status: 503);
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your field companion'), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(HomeView)));
      for (final action in [
        ('home-learn', AppRoutes.knowledge),
        ('home-assistant', AppRoutes.assistant),
        ('home-tools', AppRoutes.tools),
      ]) {
        await tapVisible(tester, find.byKey(Key(action.$1)));
        expect(router.routeInformationProvider.value.uri.path, action.$2);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
      }
      await tapVisible(tester, find.byKey(const Key('open-profile')));
      expect(find.text('Your field, your space'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('scan-leaf-action')));
      expect(find.text('Scan a maize leaf'), findsOneWidget);
      expect(requests.where((p) => p.endsWith('/scans')), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Farmer recent scans use real repository/authorized thumbnails, retry and returning refresh',
    (tester) async {
      var reads = 0;
      var fail = false;
      var empty = false;
      final images = <String>[];
      await tester.pumpWidget(
        MainApp(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/login')) {
              return response(grant(), setCookie: cookie);
            }
            if (request.url.path.endsWith('/scans')) {
              reads++;
              expect(request.headers['Authorization'], isNotNull);
              expect(request.url.queryParameters['limit'], '3');
              if (fail) return response(null, status: 503);
              return response({
                'items': empty
                    ? []
                    : [for (var i = 1; i <= 3; i++) history.historyScanJson(i)],
                'nextCursor': null,
              });
            }
            if (request.url.path.endsWith('/image')) {
              images.add(request.url.path);
              expect(request.headers['Authorization'], isNotNull);
              return http.Response.bytes(
                leafImage.bytes,
                200,
                headers: {'content-type': 'image/png'},
              );
            }
            return response(null, status: 503);
          }),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(HomeView));
      final session = context.read<FarmerSessionViewModel>();
      final router = GoRouter.of(context);
      await tester.runAsync(
        () => session.signIn('farmer@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(reads, 1);
      expect(images, hasLength(3));
      expect(
        find.byKey(ValueKey('recent-${history.historyId(1)}')),
        findsOneWidget,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('farmer-tab-0')));
      await tester.pumpAndSettle();
      expect(reads, 1);
      router.go(AppRoutes.assistant);
      await tester.pumpAndSettle();
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(reads, 2);
      fail = true;
      await tapVisible(tester, find.byTooltip('Refresh recent scans'));
      expect(find.textContaining('temporarily unavailable'), findsOneWidget);
      expect(find.text('Your first scan starts here'), findsNothing);
      fail = false;
      empty = true;
      await tapVisible(tester, find.text('Try again'));
      expect(find.text('Your first scan starts here'), findsOneWidget);
      empty = false;
      await tapVisible(tester, find.byTooltip('Refresh recent scans'));
      await tapVisible(
        tester,
        find.byKey(ValueKey('recent-${history.historyId(1)}')),
      );
      expect(find.byType(ScanResultView), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byType(ScanResultView))).uri.path,
        '${AppRoutes.history}/scans/${history.historyId(1)}',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late account A history cannot render after account B signs in', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    var firstAccount = true;
    await tester.pumpWidget(
      MainApp(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            final data = grant();
            (data['user'] as Map<String, Object?>)['email'] = jsonDecode(
              request.body,
            )['email'];
            return response(data, setCookie: cookie);
          }
          if (request.url.path.endsWith('/logout')) return response(null);
          if (request.url.path.endsWith('/scans')) {
            return firstAccount
                ? old.future
                : response({
                    'items': [history.historyScanJson(2)],
                    'nextCursor': null,
                  });
          }
          if (request.url.path.endsWith('/image')) {
            return http.Response.bytes(
              leafImage.bytes,
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          return response(null, status: 503);
        }),
      ),
    );
    await tester.pumpAndSettle();
    final session = tester
        .element(find.byType(HomeView))
        .read<FarmerSessionViewModel>();
    await tester.runAsync(
      () => session.signIn('first@example.test', 'synthetic-password'),
    );
    await tester.pump();
    expect(find.text('Loading recent scans…'), findsOneWidget);
    await tester.runAsync(session.signOut);
    firstAccount = false;
    await tester.runAsync(
      () => session.signIn('second@example.test', 'synthetic-password'),
    );
    await tester.pumpAndSettle();
    old.complete(
      response({
        'items': [history.historyScanJson(1)],
        'nextCursor': null,
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('recent-${history.historyId(1)}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('recent-${history.historyId(2)}')),
      findsOneWidget,
    );
    await tester.runAsync(session.signOut);
    await tester.pumpAndSettle();
    expect(find.text('Your field companion'), findsOneWidget);
    expect(
      find.byKey(ValueKey('recent-${history.historyId(2)}')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
