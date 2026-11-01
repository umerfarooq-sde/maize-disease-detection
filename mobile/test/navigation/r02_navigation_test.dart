import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/ai_assistant/views/assistant_view.dart';
import 'package:maizedoctor/features/ai_assistant/view_models/assistant_view_model.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/shell/views/farmer_shell.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import '../auth/session_test.dart' show cookie, grant, response;
import '../assistant/helpers.dart' show answerJson, classifierJson;
import '../scans/helpers.dart' show scanJson, leafImage, FakeScanRepository;
import '../scans/widget_test.dart' show tapVisible;
import '../support/design_fonts.dart';

Future<void> _tab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('farmer-tab-$index')));
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester, {
  String route = AppRoutes.home,
  Future<http.Response> Function(http.Request)? handle,
}) async {
  await tester.pumpWidget(
    MainApp(
      initialLocation: route,
      scanRepository: FakeScanRepository(),
      config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
      httpClient: MockClient(
        handle ?? (_) async => response(null, status: 503),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadDesignFonts);

  testWidgets(
    'five ordered branches, Scan central, Android Back returns Home',
    (tester) async {
      await _mount(tester);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final labels = bar.destinations.cast<NavigationDestination>().map(
        (d) => d.label,
      );
      expect(labels, ['Home', 'Learn', 'Scan', 'AI Assistant', 'Tools']);
      expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
      for (final entry in [
        (1, AppRoutes.knowledge),
        (2, AppRoutes.scan),
        (3, AppRoutes.assistant),
        (4, AppRoutes.tools),
      ]) {
        await _tab(tester, entry.$1);
        final router = GoRouter.of(tester.element(find.byType(FarmerShell)));
        expect(router.routeInformationProvider.value.uri.path, entry.$2);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          entry.$1,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Assistant retains one model, conversation and draft on switch and reselect',
    (tester) async {
      var requests = 0;
      await _mount(
        tester,
        route: AppRoutes.assistant,
        handle: (request) async {
          requests++;
          return response(answerJson());
        },
      );
      final context = tester.element(find.byType(AssistantView));
      final model = context.read<AssistantViewModel>();
      await model.ask('What are common rust symptoms?');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('assistant-question')),
        'My unfinished maize question',
      );
      // Dismiss the keyboard just as the system Back key does before changing tabs.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _tab(tester, 0);
      await _tab(tester, 3);
      await _tab(tester, 3);
      expect(
        tester.element(find.byType(AssistantView)).read<AssistantViewModel>(),
        same(model),
      );
      expect(model.turns, hasLength(1));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-question')))
            .controller!
            .text,
        'My unfinished maize question',
      );
      expect(requests, 1);
      expect(find.byType(AssistantView, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tools nested stack and Profile originating stack survive tab changes',
    (tester) async {
      await _mount(tester, route: AppRoutes.tools);
      final router = GoRouter.of(tester.element(find.byType(FarmerShell)));
      router.push(AppRoutes.fertilizer);
      await tester.pumpAndSettle();
      await _tab(tester, 0);
      await _tab(tester, 4);
      expect(find.text('Fertilizer planning').first, findsOneWidget);
      expect(router.canPop(), true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Tools for your field'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Your field, your space'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Tools for your field'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy Assistant deep link redirects to the single primary instance',
    (tester) async {
      await _mount(tester, route: AppRoutes.legacyAssistant);
      final router = GoRouter.of(tester.element(find.byType(AssistantView)));
      final model = tester
          .element(find.byType(AssistantView))
          .read<AssistantViewModel>();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.assistant,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      router.go(AppRoutes.legacyAssistant);
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(AssistantView)).read<AssistantViewModel>(),
        same(model),
      );
      expect(find.byType(AssistantView, skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets(
    'compact tabs keep labels, full Assistant semantics and reduced motion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester);
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(
          bar.destinations.cast<NavigationDestination>().map((d) => d.label),
          ['Home', 'Learn', 'Scan', 'AI', 'Tools'],
        );
        expect(bar.animationDuration, Duration.zero);
        await _tab(tester, 3);
        final assistant = tester.getSemantics(
          find.byKey(const ValueKey('farmer-tab-3')),
        );
        expect(assistant.label, contains('AI Assistant'));
        expect(assistant.flagsCollection.isSelected, Tristate.isTrue);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'mounted Assistant receives each owned scan once, rejects pending previous scan and identity',
    (tester) async {
      final first = Completer<http.Response>();
      final requested = <String>[];
      const firstId = '00000000-0000-4000-8000-000000000001';
      const nextId = '00000000-0000-4000-8000-000000000002';
      await _mount(
        tester,
        route: AppRoutes.assistant,
        handle: (request) async {
          if (request.url.path.endsWith('/auth/login')) {
            final account = grant();
            (account['user'] as Map<String, Object?>)['email'] =
                (jsonDecode(request.body) as Map<String, dynamic>)['email'];
            return response(account, setCookie: cookie);
          }
          if (request.url.path.endsWith('/auth/logout')) return response(null);
          if (request.url.path.endsWith('/explanation')) {
            requested.add(request.url.path);
            expect(request.headers['Authorization'], isNotNull);
            return requested.length == 1
                ? first.future
                : response(answerJson(classifier: classifierJson()));
          }
          if (request.url.path.endsWith('/image')) {
            return http.Response.bytes(
              leafImage.bytes,
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          if (request.url.path.endsWith('/scans')) {
            return response({
              'items': [
                for (final id in [firstId, nextId])
                  {
                    ...scanJson(status: ScanStatus.completed),
                    'id': id,
                    'image': {
                      ...scanJson()['image'] as Map<String, Object?>,
                      'url': 'scans/$id/image',
                    },
                  },
              ],
              'nextCursor': null,
            });
          }
          return response(null, status: 503);
        },
      );
      final context = tester.element(find.byType(AssistantView));
      final session = context.read<FarmerSessionViewModel>();
      final router = GoRouter.of(context);
      await tester.runAsync(
        () => session.signIn('farmer@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      final model = tester
          .element(find.byType(AssistantView))
          .read<AssistantViewModel>();
      Future<void> openScan(String id, {bool pending = false}) async {
        router.push(AppRoutes.history);
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(ValueKey(id)));
        if (pending) {
          await tester.ensureVisible(
            find.byKey(const Key('explain-scan-action')),
          );
          await tester.tap(find.byKey(const Key('explain-scan-action')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        } else {
          await tapVisible(
            tester,
            find.byKey(const Key('explain-scan-action')),
          );
        }
      }

      await openScan(firstId, pending: true);
      expect(requested, hasLength(1));
      expect(model.busy, true);
      await openScan(nextId);
      expect(requested, hasLength(2));
      expect(
        tester.element(find.byType(AssistantView)).read<AssistantViewModel>(),
        same(model),
      );
      expect(model.selectedScan?.id, nextId);
      expect(model.turns, hasLength(1));
      await _tab(tester, 0);
      await _tab(tester, 3);
      await _tab(tester, 3);
      expect(requested, hasLength(2));
      first.complete(response(answerJson(classifier: classifierJson())));
      await tester.pumpAndSettle();
      expect(model.selectedScan?.id, nextId);
      expect(model.turns.single.scan?.id, nextId);
      // Change identity while Assistant is offstage, then return: no draft or scan.
      await tester.enterText(
        find.byKey(const Key('assistant-question')),
        'Private draft',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _tab(tester, 0);
      await tester.runAsync(session.signOut);
      await tester.runAsync(
        () => session.signIn('other@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      await _tab(tester, 3);
      final replacement = tester
          .element(find.byType(AssistantView))
          .read<AssistantViewModel>();
      expect(replacement, isNot(same(model)));
      expect(replacement.turns, isEmpty);
      expect(replacement.selectedScan, isNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-question')))
            .controller!
            .text,
        isEmpty,
      );
      expect(requested, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
