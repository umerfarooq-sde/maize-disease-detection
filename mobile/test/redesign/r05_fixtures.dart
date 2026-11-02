import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/tools/views/tools_view.dart';
import '../auth/session_test.dart' show grant, cookie, response;
import '../fertilizer/helpers.dart' as fertilizer;
import '../yield/helpers.dart' as yield_fixture;
import '../analytics/helpers.dart' as analytics;
import '../history/helpers.dart' as history;
import '../profile/helpers.dart' as profile;
import '../profile/privacy_test.dart' show receipt;
import '../scans/helpers.dart' show leafImage;

// All content, arithmetic, accounts and media are disposable in-memory UI
// fixtures. No fixture is sent to a real backend or published as advice.
class R05Fixture {
  bool pending = false;
  bool longContent = false;
  List<int> image = leafImage.bytes;
  final paths = <String>[];
  final theme = ThemeController.system();
  late GoRouter router;
  late FarmerSessionViewModel session;

  http.Client client() => MockClient((request) async {
    final path = request.url.path;
    paths.add(path);
    if (path.endsWith('/auth/login')) {
      final data = grant();
      if (longContent) {
        (data['user'] as Map<String, Object?>)['email'] =
            '${'long.' * 22}farmer@example.test';
      }
      return response(data, setCookie: cookie);
    }
    if (path.endsWith('/auth/logout')) return response(null);
    if (path.endsWith('/profile/data-deletion')) return response(receipt());
    if (path.endsWith('/profile')) {
      return response(
        profile.profileJson(
          name: longContent
              ? 'Long fixture farmer name for wrapping verification'
              : 'Fixture farmer',
          photo: 'profile/avatar?v=${'a' * 64}',
        ),
      );
    }
    if (path.endsWith('/image') || path.endsWith('/avatar')) {
      expect(
        request.headers['authorization'],
        'Bearer header.payload.signature',
      );
      return http.Response.bytes(
        image,
        200,
        headers: {'content-type': 'image/png', 'cache-control': 'no-store'},
      );
    }
    if (path == '/api/v1/scans') {
      return response({
        'items': [for (var i = 1; i <= 3; i++) history.historyScanJson(i)],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/analytics/scans') ||
        path.endsWith('/analytics/scans/activity')) {
      final range = AnalyticsDateRange(
        DateTime.parse(request.url.queryParameters['from']!),
        DateTime.parse(request.url.queryParameters['to']!),
      );
      return response(
        path.endsWith('/activity')
            ? analytics.activityJson(range: range)
            : analytics.summaryJson(range: range),
      );
    }
    if (path.endsWith('/fertilizer/rules')) {
      final rule = fertilizer.ruleJson(
        title: longContent
            ? 'Synthetic long rule for responsive source and rule layout verification only'
            : 'Synthetic arithmetic fixture — not agricultural advice',
      );
      if (longContent) {
        (rule['source'] as Map<String, Object?>)['citation'] =
            'Synthetic citation for layout verification. ' * 12;
      }
      return response(
        fertilizer.catalogueJson(pending: pending, items: [rule]),
      );
    }
    if (path.endsWith('/yield/configurations')) {
      return response(yield_fixture.catalogueJson(pending: pending));
    }
    if (path.endsWith('/fertilizer/calculate')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return response(
        fertilizer.resultJson(
          input: fertilizer.fixtureInput(area: body['area'] as String),
          quantity: longContent ? '123456789012345.125' : '25.000',
        ),
      );
    }
    if (path.endsWith('/yield/calculate')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return response(
        yield_fixture.resultJson(
          input: yield_fixture.fixtureInput(area: body['area'] as String),
          value: longContent ? '123456789012345.125' : '25.000',
        ),
      );
    }
    return response(null, status: 503);
  });

  Future<void> mount(
    WidgetTester tester, {
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
          initialLocation: AppRoutes.tools,
          themeController: theme,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: client(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ToolsView));
    router = GoRouter.of(context);
    session = context.read<FarmerSessionViewModel>();
    if (signedIn) {
      await tester.runAsync(
        () => session.signIn('fixture@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> go(WidgetTester tester, String path) async {
    router.go(path);
    await tester.pumpAndSettle();
  }
}
