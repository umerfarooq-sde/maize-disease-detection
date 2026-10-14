import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/ai_assistant/view_models/assistant_view_model.dart';
import 'package:maizedoctor/features/ai_assistant/views/assistant_view.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/disease_detection/views/result_view.dart';
import '../auth/session_test.dart' show cookie, grant, response;
import '../scans/helpers.dart' show scanJson;
import '../scans/widget_test.dart' show tapVisible;
import 'helpers.dart';

void main() {
  testWidgets(
    'guest assistant routes to grounded API and account change discards pending chat/draft',
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
            if (request.url.path.endsWith('/knowledge/ask')) {
              return pending.future;
            }
            return response(null, status: 401);
          }),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AssistantView));
      final model = context.read<AssistantViewModel>();
      final old = model.ask('What symptoms identify common rust in maize?');
      await tester.pump();
      final session = context.read<FarmerSessionViewModel>();
      await tester.runAsync(
        () => session.signIn('farmer@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('What symptoms identify common rust in maize?'),
        findsNothing,
      );
      final replacement = tester
          .element(find.byType(AssistantView))
          .read<AssistantViewModel>();
      expect(identical(replacement, model), false);
      expect(replacement.turns, isEmpty);
      pending.complete(response(answerJson()));
      await old;
      await tester.pumpAndSettle();
      expect(replacement.turns, isEmpty);
      expect(find.text('Synthetic reviewed test paragraph.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'farmer opens an owned result in assistant; logout hides scan and conversation',
    (tester) async {
      var explanations = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.history,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return response(grant(), setCookie: cookie);
            }
            if (request.url.path.endsWith('/auth/logout')) {
              return response(null);
            }
            if (request.url.path.endsWith('/scans')) {
              return response({
                'items': [scanJson(status: ScanStatus.completed)],
                'nextCursor': null,
              });
            }
            if (request.url.path.endsWith('/explanation')) {
              explanations++;
              expect(request.headers['Authorization'], isNotNull);
              expect(request.body, '{}');
              return response(answerJson(classifier: classifierJson()));
            }
            return response(null, status: 401);
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('history-sign-in')));
      final context = tester.element(find.byType(TextFormField).first);
      final session = context.read<FarmerSessionViewModel>();
      await tester.runAsync(
        () => session.signIn('farmer@example.test', 'synthetic-password'),
      );
      GoRouter.of(context).pop();
      await tester.pumpAndSettle();
      final scan = ScanRecord.fromJson(scanJson(status: ScanStatus.completed));
      await tapVisible(tester, find.byKey(ValueKey(scan.id)));
      expect(find.byType(ScanResultView), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('explain-scan-action')));
      expect(find.byType(AssistantView), findsOneWidget);
      final model = tester
          .element(find.byType(AssistantView))
          .read<AssistantViewModel>();
      expect(explanations, 1);
      expect(model.selectedScan?.id, scan.id);
      expect(
        model.turns.single.answer?.classifierPrediction?.matches(
          scan.prediction!,
        ),
        true,
      );
      await tester.runAsync(session.signOut);
      await tester.pumpAndSettle();
      final guest = tester
          .element(find.byType(AssistantView))
          .read<AssistantViewModel>();
      expect(guest.selectedScan, isNull);
      expect(guest.turns, isEmpty);
      expect(find.byKey(const Key('assistant-choose-scan')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scan chooser uses authenticated pagination and only completed predictions',
    (tester) async {
      const pendingId = '00000000-0000-4000-8000-000000000001';
      const firstId = '00000000-0000-4000-8000-000000000002';
      const nextId = '00000000-0000-4000-8000-000000000003';
      final cursors = <String?>[];
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.assistant,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return response(grant(), setCookie: cookie);
            }
            if (request.url.path.endsWith('/scans')) {
              expect(request.headers['Authorization'], isNotNull);
              final cursor = request.url.queryParameters['cursor'];
              cursors.add(cursor);
              return response({
                'items': cursor == null
                    ? [
                        {...scanJson(), 'id': pendingId},
                        {
                          ...scanJson(status: ScanStatus.completed),
                          'id': firstId,
                        },
                      ]
                    : [
                        {
                          ...scanJson(status: ScanStatus.completed),
                          'id': nextId,
                        },
                      ],
                'nextCursor': cursor == null ? firstId : null,
              });
            }
            if (request.url.path.endsWith('/explanation')) {
              expect(request.url.path, endsWith('/scans/$nextId/explanation'));
              return response(answerJson(classifier: classifierJson()));
            }
            return response(null, status: 401);
          }),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AssistantView));
      await tester.runAsync(
        () => context.read<FarmerSessionViewModel>().signIn(
          'farmer@example.test',
          'synthetic-password',
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('assistant-choose-scan')));
      expect(
        find.byKey(const ValueKey('assistant-scan-$pendingId')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('assistant-scan-$firstId')),
        findsOneWidget,
      );
      await tapVisible(
        tester,
        find.byKey(const Key('assistant-scans-load-more')),
      );
      expect(cursors, [null, firstId]);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('assistant-scan-$nextId')),
      );
      expect(find.text('Choose a scan to explain'), findsNothing);
      final model = tester
          .element(find.byType(AssistantView))
          .read<AssistantViewModel>();
      expect(model.selectedScan?.id, nextId);
      expect(model.turns.single.answer?.classifierPrediction, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
