import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/features/ai_assistant/views/assistant_view.dart';
import 'package:maizedoctor/features/ai_assistant/view_models/assistant_view_model.dart';
import 'package:maizedoctor/features/ai_assistant/widgets/assistant_focus_panel.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/profile/views/profile_editor_view.dart';
import 'package:maizedoctor/features/profile/view_models/profile_view_model.dart';
import '../auth/session_test.dart' show cookie, grant, response;
import '../assistant/helpers.dart' show answerJson;
import '../profile/helpers.dart';
import '../profile/widget_test.dart' show pumpProfile;
import '../scans/widget_test.dart' show tapVisible;
import '../scans/helpers.dart' show FakeScanRepository;

void main() {
  for (final authenticated in [false, true]) {
    testWidgets(
      'Focus closes on ${authenticated ? 'Farmer logout' : 'Guest login'} and rejects late responses',
      (tester) async {
        final pending = Completer<http.Response>();
        await tester.pumpWidget(
          MainApp(
            initialLocation: AppRoutes.assistant,
            config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/auth/login')) {
                return response(grant(), setCookie: cookie);
              }
              if (request.url.path.endsWith('/auth/logout')) {
                return response(null);
              }
              if (request.url.path.endsWith('/knowledge/ask')) {
                return pending.future;
              }
              return response(null, status: 401);
            }),
          ),
        );
        await tester.pumpAndSettle();
        final session = tester
            .element(find.byType(AssistantView))
            .read<FarmerSessionViewModel>();
        if (authenticated) {
          await tester.runAsync(
            () => session.signIn('farmer@example.test', 'synthetic-password'),
          );
          await tester.pumpAndSettle();
        }
        final old = tester
            .element(find.byType(AssistantView))
            .read<AssistantViewModel>();
        old.selectDisease('Common_Rust');
        old.selectTopic('SYMPTOMS');
        final operation = old.ask('A fixture maize symptoms question');
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-focus')));
        await tester.pumpAndSettle();
        expect(find.byType(AssistantFocusPanel), findsOneWidget);
        if (authenticated) {
          await tester.runAsync(session.signOut);
        } else {
          await tester.runAsync(
            () => session.signIn('farmer@example.test', 'synthetic-password'),
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(AssistantFocusPanel), findsNothing);
        final current = tester
            .element(find.byType(AssistantView))
            .read<AssistantViewModel>();
        expect(identical(current, old), false);
        expect(current.diseaseLabel, isNull);
        expect(current.turns, isEmpty);
        pending.complete(response(answerJson()));
        await operation;
        await tester.pumpAndSettle();
        expect(current.turns, isEmpty);
        await tester.tap(find.byKey(const Key('assistant-focus')));
        await tester.pumpAndSettle();
        expect(
          tester
              .element(find.byType(AssistantFocusPanel))
              .read<AssistantViewModel>(),
          same(current),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Focus and draft retain one live model across five tabs', (
    tester,
  ) async {
    var questions = 0;
    await tester.pumpWidget(
      MainApp(
        scanRepository: FakeScanRepository(),
        initialLocation: AppRoutes.assistant,
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/knowledge/ask')) {
            questions++;
            return response(answerJson());
          }
          return response(null, status: 503);
        }),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AssistantView));
    final model = context.read<AssistantViewModel>();
    final router = GoRouter.of(context);
    await model.ask('Synthetic maize question for tab retention');
    model.selectDisease('Healthy');
    await tester.enterText(
      find.byKey(const Key('assistant-question')),
      'Retain this draft',
    );
    for (final destination in [
      AppRoutes.home,
      AppRoutes.knowledge,
      AppRoutes.scan,
      AppRoutes.tools,
    ]) {
      await tester.tap(find.byKey(const Key('assistant-focus')));
      await tester.pumpAndSettle();
      expect(
        tester
            .element(find.byType(AssistantFocusPanel))
            .read<AssistantViewModel>(),
        same(model),
      );
      await tester.tap(find.byTooltip('Close focus controls'));
      await tester.pumpAndSettle();
      router.go(destination);
      await tester.pumpAndSettle();
      router.go(AppRoutes.assistant);
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(AssistantView)).read<AssistantViewModel>(),
        same(model),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-question')))
            .controller!
            .text,
        'Retain this draft',
      );
      expect(model.diseaseLabel, 'Healthy');
    }
    expect(questions, 1);
    expect(model.turns, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final systemBack in [true, false]) {
    testWidgets(
      'photo-only draft blocks ${systemBack ? 'system' : 'app-bar'} Back; cancel retains it and discard does not upload',
      (tester) async {
        final repository = FakeProfileRepository();
        final model = ProfileViewModel(repository)..load();
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: model,
                        child: Scaffold(
                          appBar: AppBar(title: const Text('Edit profile')),
                          body: const ProfileEditorView(),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Edit fixture profile'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit fixture profile'));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('profile-choose-photo')));
        expect(model.photo, isNotNull);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved profile changes?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(model.photo, isNotNull);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileEditorView), findsNothing);
        expect(model.photo, isNull);
        expect(repository.uploads, 0);
        expect(repository.removals, 0);
        expect(repository.saved?.avatarUrl, isNull);
      },
    );
  }
  testWidgets(
    'acknowledged photo clears only the pending photo guard without another upload',
    (tester) async {
      final repository = FakeProfileRepository();
      await pumpProfile(tester, repository);
      await tester.pumpAndSettle();
      final model = tester
          .element(find.byType(ProfileEditorView))
          .read<ProfileViewModel>();
      await model.choosePhoto();
      await tester.pumpAndSettle();
      final guard = find.descendant(
        of: find.byType(ProfileEditorView),
        matching: find.byWidgetPredicate((widget) => widget is PopScope),
      );
      expect(tester.widget<PopScope>(guard).canPop, false);
      await model.uploadPhoto();
      await tester.pumpAndSettle();
      expect(model.photo, isNull);
      expect(tester.widget<PopScope>(guard).canPop, true);
      expect(repository.uploads, 1);
      expect(repository.removals, 0);
    },
  );
}
