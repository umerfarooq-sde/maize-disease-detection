import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/disease_detection/views/result_view.dart';
import 'package:maizedoctor/features/scan_history/views/history_view.dart';
import 'auth/session_test.dart' show cookie, grant, response;
import 'scans/helpers.dart';
import 'scans/widget_test.dart' show tapVisible;

void main() {
  testWidgets(
    'guest preview submit routes to model result and new scan clears draft',
    (tester) async {
      final scans = FakeScanRepository()
        ..result = ScanRecord.fromJson(scanJson(status: ScanStatus.completed));
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.scan,
          scanRepository: scans,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient(
            (request) async => response(null, status: 401),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('gallery-leaf-action')));
      await tapVisible(tester, find.byKey(const Key('upload-leaf-action')));
      expect(find.byType(ScanResultView), findsOneWidget);
      expect(find.text('Model prediction'), findsWidgets);
      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('Uncertain result'), findsOneWidget);
      expect(
        GoRouter.of(tester.element(find.byType(ScanResultView))).canPop(),
        true,
      );
      await tapVisible(tester, find.byKey(const Key('new-scan-action')));
      expect(find.byType(ScanResultView), findsNothing);
      expect(find.byKey(const Key('leaf-image-preview')), findsNothing);
      expect(find.byKey(const Key('gallery-leaf-action')), findsOneWidget);
      expect(scans.keys, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sign in from guest history, open detail/back, logout removes account data',
    (tester) async {
      var historyCalls = 0;
      var detailCalls = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.history,
          scanRepository: FakeScanRepository(),
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return response(grant(), setCookie: cookie);
            }
            if (request.url.path.endsWith('/auth/logout')) {
              return response(null);
            }
            if (request.url.path.endsWith('/scans')) {
              historyCalls++;
              expect(request.headers['Authorization'], isNotNull);
              return response({
                'items': [scanJson(status: ScanStatus.completed)],
                'nextCursor': null,
              });
            }
            detailCalls++;
            return response(null, status: 401);
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(historyCalls, 0);
      await tapVisible(tester, find.byKey(const Key('history-sign-in')));
      await tester.enterText(
        find.byType(TextFormField).first,
        'farmer@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'synthetic-password',
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
      expect(find.text('Your saved scans'), findsOneWidget);
      expect(historyCalls, 1);
      await tapVisible(tester, find.byKey(ValueKey(savedScan.id)));
      expect(find.byType(ScanResultView), findsOneWidget);
      expect(find.text('Healthy'), findsOneWidget);
      final context = tester.element(find.byType(ScanResultView));
      final router = GoRouter.of(context);
      final session = context.read<FarmerSessionViewModel>();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HistoryView), findsOneWidget);
      await tapVisible(tester, find.byKey(ValueKey(savedScan.id)));
      await tester.runAsync(session.signOut);
      await tester.pumpAndSettle();
      expect(find.text('Healthy'), findsNothing);
      expect(
        detailCalls,
        0,
        reason: 'Guest cannot reload an account result without credentials.',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Sign in to see your scans'), findsOneWidget);
      expect(historyCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid credentials keep form editable with safe error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MainApp(
        initialLocation: AppRoutes.auth,
        scanRepository: FakeScanRepository(),
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        httpClient: MockClient((request) async => response(null, status: 401)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'farmer@example.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    expect(
      find.text('We could not sign you in. Check your email and password.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      true,
    );
    expect(tester.takeException(), isNull);
  });
}
