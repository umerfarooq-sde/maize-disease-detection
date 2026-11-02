import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:provider/provider.dart';
import 'session_test.dart' show grant, response, cookie;
import '../scans/widget_test.dart' show tapVisible;
import '../support/design_fonts.dart';
import '../profile/helpers.dart' show profileJson;

void main() {
  setUpAll(loadDesignFonts);
  testWidgets('Farmer keyboard traversal and existing short login remain valid', (
    tester,
  ) async {
    var calls = 0;
    var profileReads = 0;
    await tester.pumpWidget(
      MainApp(
        initialLocation: AppRoutes.auth,
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/profile')) {
            profileReads++;
            return response(profileJson());
          }
          calls++;
          expect(jsonDecode(request.body)['password'], 'old');
          return response(grant(), setCookie: cookie);
        }),
      ),
    );
    await tester.pumpAndSettle();
    final email = find.byType(TextFormField).first;
    final password = find.byType(TextFormField).last;
    await tester.enterText(email, 'farmer@example.test');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .focusNode
          .hasFocus,
      true,
    );
    await tester.enterText(password, 'old');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      profileReads,
      1,
      reason:
          'After login, the visible account centre loads its functional projection once.',
    );
    expect(find.textContaining('Signed in as'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Admin empty and malformed input is inline, never public registration',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.admin,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((_) async {
            calls++;
            return response(null, status: 401);
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Sign in as Admin'),
      );
      expect(find.text('Enter your Admin email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('admin-email')),
        'not-an-email',
      );
      await tester.enterText(
        find.byKey(const Key('admin-password')),
        'any-existing-password',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Sign in as Admin'),
      );
      expect(calls, 0);
      expect(find.byKey(const Key('open-registration')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home account action uses initials without an extra profile/image request',
    (tester) async {
      var calls = 0;
      final paths = <String>[];
      await tester.pumpWidget(
        MainApp(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            calls++;
            paths.add(request.url.path);
            if (request.url.path.endsWith('/profile')) {
              return response(profileJson());
            }
            if (request.url.path.endsWith('/scans')) {
              expect(request.url.queryParameters['limit'], '3');
              return response({'items': [], 'nextCursor': null});
            }
            return response(grant(), setCookie: cookie);
          }),
        ),
      );
      await tester.pumpAndSettle();
      final session = tester
          .element(find.byKey(const Key('open-profile')))
          .read<FarmerSessionViewModel>();
      expect(find.byTooltip('Guest profile and sign-in'), findsOneWidget);
      await tester.runAsync(
        () => session.signIn('farmer@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Your profile'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('open-profile')),
          matching: find.text('F'),
        ),
        findsOneWidget,
      );
      expect(
        calls,
        2,
      ); // Login plus functional recent history, no avatar fetch.
      expect(paths, ['/api/v1/auth/login', '/api/v1/scans']);
      await tester.tap(find.byKey(const Key('open-profile')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Signed in as'), findsOneWidget);
      expect(calls, 3);
      expect(paths, ['/api/v1/auth/login', '/api/v1/scans', '/api/v1/profile']);
      expect(tester.takeException(), isNull);
    },
  );
}
