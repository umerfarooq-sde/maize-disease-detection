import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/auth/views/auth_intro_view.dart';
import 'package:maizedoctor/features/auth/views/registration_view.dart';
import '../scans/widget_test.dart' show tapVisible;
import 'registration_test.dart' show registeredUser, registrationPassword;
import 'session_test.dart' show response, grant, cookie;

void main() {
  testWidgets(
    'login/register navigation, validation, password visibility, registration/login/logout',
    (tester) async {
      var registrations = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.auth,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/register')) {
              registrations++;
              expect(jsonDecode(request.body)['password'], 'maize6');
              return response(registeredUser(), status: 201);
            }
            if (request.url.path.endsWith('/login')) {
              expect(jsonDecode(request.body)['password'], 'maize6');
              return response(grant(), setCookie: cookie);
            }
            return response(null);
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('open-registration')));
      expect(find.byType(RegistrationView), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const Key('register-submit')));
      expect(registrations, 0);
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const Key('registration-password')),
            )
            .errorText,
        'Password must be at least 6 characters.',
      );
      await tester.enterText(
        find.byKey(const Key('registration-email')),
        'farmer@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('registration-password')),
        'short',
      );
      await tapVisible(tester, find.byKey(const Key('register-submit')));
      expect(registrations, 0);
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const Key('registration-password')),
            )
            .errorText,
        'Password must be at least 6 characters.',
      );
      await tester.enterText(
        find.byKey(const Key('registration-password')),
        'a' * 129,
      );
      await tapVisible(tester, find.byKey(const Key('register-submit')));
      expect(registrations, 0);
      expect(
        find.text('Password must be at most 128 characters.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('registration-password')),
        'maize6',
      );
      await tapVisible(tester, find.byTooltip('Show password'));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('registration-password')),
            )
            .enabled,
        true,
      );
      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(find.text('ADMIN'), findsNothing);
      await tapVisible(tester, find.byKey(const Key('register-submit')));
      expect(registrations, 1);
      expect(find.text('Your farmer account is ready'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('registration-sign-in')));
      expect(find.byType(AuthIntroView), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'farmer@example.test',
      );
      await tester.enterText(find.byType(TextFormField).last, 'maize6');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
      expect(find.textContaining('Signed in as'), findsOneWidget);
      await tapVisible(tester, find.text('Sign out'));
      expect(find.text('You are exploring as a guest.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'busy disables form and repeated submit, duplicate retry preserves input',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.register,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((_) async {
            calls++;
            await pending.future;
            return response(null, status: 409);
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('registration-email')),
        'farmer@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('registration-password')),
        registrationPassword,
      );
      await tester.ensureVisible(find.byKey(const Key('register-submit')));
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pump();
      expect(find.text('Creating account…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('register-submit')))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('An account already uses'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('registration-email')))
            .controller!
            .text,
        'farmer@example.test',
      );
      await tapVisible(tester, find.byKey(const Key('register-submit')));
      expect(calls, 2);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(640, 360),
    const Size(1024, 768),
  ]) {
    testWidgets('registration fits $size with large text and keyboard', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        const MainApp(initialLocation: AppRoutes.register),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('registration-email')),
        'bad',
      );
      await tapVisible(tester, find.byKey(const Key('register-submit')));
      expect(tester.takeException(), isNull);
    });
  }
}
