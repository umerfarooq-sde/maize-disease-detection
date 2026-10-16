import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/admin_dashboard.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/features/admin/view_models/admin_dashboard_view_model.dart';
import 'package:maizedoctor/features/admin/views/admin_dashboard_view.dart';
import '../analytics/helpers.dart' show clock;
import '../auth/session_test.dart' show grant, cookie, response;
import 'helpers.dart';

Future<void> submit(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('admin-email')),
    'admin@example.test',
  );
  await tester.enterText(
    find.byKey(const Key('admin-password')),
    'synthetic password',
  );
  await tester.ensureVisible(find.text('Sign in as Admin'));
  await tester.tap(find.text('Sign in as Admin'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Admin route has separate sign-in and navigation; real repository loads server aggregates and logout clears them',
    (tester) async {
      final requests = <http.Request>[];
      await tester.pumpWidget(
        MainApp(
          initialLocation: '/admin',
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/login')) {
              return response(grant(role: 'ADMIN'), setCookie: cookie);
            }
            if (request.url.path.endsWith('/logout')) return response(null);
            if (request.url.path.endsWith('/ai-operations')) {
              return response({'status': 'UNAVAILABLE'});
            }
            final query = request.url.queryParameters;
            return response(
              dashboardJson(
                range: AnalyticsDateRange(
                  DateTime.parse('${query['from']}T00:00:00Z'),
                  DateTime.parse('${query['to']}T00:00:00Z'),
                ),
              ),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administrator sign-in'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(requests, isEmpty);
      await submit(tester);
      expect(find.text('Registered farmers'), findsOneWidget);
      expect(find.text('Scan ownership'), findsOneWidget);
      expect(find.text('Model label distribution'), findsOneWidget);
      expect(find.textContaining('no model has been promoted'), findsOneWidget);
      expect(
        find.textContaining('readiness has not been checked'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Operational statistics are unavailable'),
        findsOneWidget,
      );
      final dashboard = requests.singleWhere(
        (request) => request.url.path.endsWith('/admin/dashboard'),
      );
      expect(
        dashboard.headers['authorization'],
        'Bearer header.payload.signature',
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Administrator sign-in'), findsOneWidget);
      expect(find.text('Saved scans'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('farmer grant cannot open the dashboard and is revoked', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(
      MainApp(
        initialLocation: '/admin',
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          return response(
            request.url.path.endsWith('/login') ? grant() : null,
            setCookie: cookie,
          );
        }),
      ),
    );
    await tester.pumpAndSettle();
    await submit(tester);
    expect(find.text('You do not have access to this area.'), findsOneWidget);
    expect(find.text('Registered farmers'), findsNothing);
    expect(paths, ['/api/v1/auth/login', '/api/v1/auth/logout']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'empty scan range retains real account/system summary without fabricated charts',
    (tester) async {
      final repository = FakeAdminRepository()
        ..respond = (range) async =>
            AdminDashboard.fromJson(dashboardJson(range: range, empty: true));
      final model = AdminDashboardViewModel(repository, now: () => clock);
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: model,
              child: const AdminDashboardView(),
            ),
          ),
        ),
      );
      expect(find.text('No scans in this period'), findsOneWidget);
      expect(find.text('Registered farmers'), findsOneWidget);
      expect(find.text('Scans over time'), findsNothing);
    },
  );
  testWidgets(
    'dashboard loading, network retry and preset filters use ViewModel',
    (tester) async {
      final gate = Completer<AdminDashboard>();
      final repository = FakeAdminRepository()..respond = (_) => gate.future;
      final model = AdminDashboardViewModel(repository, now: () => clock);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: model,
              child: const AdminDashboardView(),
            ),
          ),
        ),
      );
      unawaited(model.load());
      await tester.pump();
      expect(find.text('Loading system overview…'), findsOneWidget);
      gate.completeError(const AppException(AppErrorKind.network));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your internet'), findsOneWidget);
      repository.respond = (range) async =>
          AdminDashboard.fromJson(dashboardJson(range: range));
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Registered farmers'), findsOneWidget);
      await tester.ensureVisible(find.text('7 days'));
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(repository.calls.last.days, 7);
    },
  );
  testWidgets(
    '320px with large text, keyboard and long version strings scrolls without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeAdminRepository()
        ..respond = (range) async {
          final json = dashboardJson(range: range);
          json['model'] = <String, Object?>{
            ...json['model'] as Map<String, Object?>,
            'configuredVersion': List.filled(79, 'v').join(),
          };
          return AdminDashboard.fromJson(json);
        };
      final model = AdminDashboardViewModel(repository, now: () => clock);
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 220),
              ),
              child: Scaffold(
                body: ChangeNotifierProvider.value(
                  value: model,
                  child: const AdminDashboardView(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recent scan activity'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
