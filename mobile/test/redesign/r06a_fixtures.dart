import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/features/admin/views/admin_access_view.dart';
import 'package:maizedoctor/features/admin/view_models/admin_session_view_model.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import '../auth/session_test.dart' show grant, response, cookie;
import '../admin/helpers.dart' show dashboardJson;
import '../admin/model_health_test.dart' show healthFixture;

// In-memory test data only. These events and accounts never reach a provider.
Map<String, Object?> r06Operations({
  bool empty = false,
  bool zeroDaily = false,
  int days = 2,
}) => {
  'status': 'COLLECTED',
  'totals': empty
      ? <Object>[]
      : [
          for (final (
                scope,
                operation,
                attempts,
                successes,
                failures,
                abstained,
              )
              in [
                ('NODE', 'INFERENCE', 8, 6, 2, 0),
                ('NODE', 'RETRIEVAL', 4, 3, 1, 0),
                ('NODE', 'GENERATION', 5, 3, 1, 1),
                ('NODE', 'EXPLANATION', 2, 1, 0, 1),
                ('AI_SERVICE', 'RETRIEVAL', 4, 3, 1, 0),
                ('AI_SERVICE', 'GENERATION', 5, 3, 1, 1),
                ('PROVIDER', 'GEMINI', 4, 3, 1, 0),
                ('PROVIDER', 'EMBEDDING', 2, 2, 0, 0),
              ])
            {
              'scope': scope,
              'operation': operation,
              'requests': attempts,
              'successes': successes,
              'failures': failures,
              'abstained': abstained,
              'averageMs': 125.5,
              'p50Ms': 100,
              'p95Ms': 250.25,
            },
        ],
  'daily': empty
      ? <Object>[]
      : [
          for (var i = 0; i < days; i++)
            for (final scope in ['NODE', 'AI_SERVICE', 'PROVIDER'])
              {
                'date': '2026-10-${(i + 1).toString().padLeft(2, '0')}',
                'scope': scope,
                'requests': zeroDaily ? 0 : i + 1,
                'failures': 0,
              },
        ],
  'collection': {'localDropped': empty ? 0 : 2, 'localPending': empty ? 0 : 1},
};

class R06Fixture {
  LeafImageDatasource? images;
  bool empty = false,
      operationsUnavailable = false,
      longIdentity = false,
      largeCounts = false;
  bool farmerGrant = false;
  int dashboardStatus = 200;
  Object? malformedOperations;
  Completer<void>? reportGate;
  final requests = <http.Request>[];
  final theme = ThemeController.system();
  late GoRouter router;
  late AdminSessionViewModel admin;
  late FarmerSessionViewModel farmer;
  http.Client client() => MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/auth/login')) {
      final email =
          (jsonDecode(request.body) as Map<String, dynamic>)['email'] as String;
      final role = email.startsWith('admin') && !farmerGrant
          ? 'ADMIN'
          : 'FARMER';
      final data = grant(role: role);
      data['accessToken'] = role == 'ADMIN'
          ? 'admin.access.token'
          : 'farmer.access.token';
      (data['user'] as Map<String, Object?>)['email'] = longIdentity
          ? '${'long.' * 15}admin@example.test'
          : email;
      return response(data, setCookie: cookie);
    }
    if (path.endsWith('/auth/logout')) return response(null);
    if (path.contains('/admin/')) {
      expect(request.headers['authorization'], 'Bearer admin.access.token');
      if (path.endsWith('/ai-operations')) {
        return response(
          malformedOperations ??
              (operationsUnavailable
                  ? {'status': 'UNAVAILABLE'}
                  : r06Operations(empty: empty)),
        );
      }
      if (path.endsWith('/dashboard')) {
        await reportGate?.future;
        final query = request.url.queryParameters;
        final range = AnalyticsDateRange(
          DateTime.parse(query['from']!),
          DateTime.parse(query['to']!),
        );
        final data = dashboardJson(range: range, empty: empty);
        if (largeCounts) {
          data['farmers'] = {
            'total': 9007199254740991,
            'active': 9007199254740991,
            'suspended': 0,
            'deactivated': 0,
          };
        }
        return response(
          dashboardStatus == 200 ? data : null,
          status: dashboardStatus,
        );
      }
      if (path.endsWith('/model-health')) return response(healthFixture());
      if (path.contains('/disease-images/')) {
        return response({'items': <Object>[]});
      }
      return response({'items': <Object>[], 'nextCursor': null});
    }
    if (path.endsWith('/scans')) {
      return response({'items': <Object>[], 'nextCursor': null});
    }
    return response(null, status: 503);
  });
  Future<void> mount(
    WidgetTester tester, {
    String location = '/admin',
    bool signedIn = true,
    bool dark = false,
    Key? boundary,
  }) async {
    await theme.setMode(dark ? ThemeMode.dark : ThemeMode.light);
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MainApp(
          initialLocation: location,
          themeController: theme,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: client(),
          profileImages: images,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AdminAccessView));
    router = GoRouter.of(context);
    admin = context.read<AdminSessionViewModel>();
    farmer = context.read<FarmerSessionViewModel>();
    if (signedIn) {
      await tester.runAsync(
        () => admin.signIn('admin@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> go(WidgetTester tester, String path) async {
    router.go(path);
    await tester.pumpAndSettle();
  }
}

Future<void> r06Tap(WidgetTester tester, Finder finder) async {
  await r06Reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Locate lazily mounted record controls before ensuring they are visible.
Future<void> r06Reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty &&
      find.byType(CustomScrollView).evaluate().isNotEmpty) {
    final scroll = find.byType(CustomScrollView).last;
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
        )
        .position;
    position.jumpTo(0);
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 80 && finder.evaluate().isEmpty;
      attempt++
    ) {
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(
        (position.pixels + position.viewportDimension * 0.6).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
