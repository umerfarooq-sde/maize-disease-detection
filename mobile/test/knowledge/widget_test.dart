import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/knowledge.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_view_model.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_detail_view_model.dart';
import 'package:maizedoctor/features/disease_knowledge/views/knowledge_view.dart';
import 'package:maizedoctor/features/disease_knowledge/views/knowledge_detail_view.dart';
import '../auth/session_test.dart' show response;
import '../scans/widget_test.dart' show tapVisible;
import 'helpers.dart';

Future<void> pumpKnowledge(
  WidgetTester tester,
  FakeKnowledgeRepository repo,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => KnowledgeViewModel(repo)..load(),
          child: const KnowledgeView(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> pumpDetail(
  WidgetTester tester,
  FakeKnowledgeRepository repo,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => KnowledgeDetailViewModel(repo, 'healthy')..load(),
          child: const KnowledgeDetailView(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'guest catalogue four entries, detail sources, no invented Healthy sections and back',
    (tester) async {
      var listCalls = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.knowledge,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/diseases')) {
              listCalls++;
              return response({'items': slugs.map(summaryJson).toList()});
            }
            return response(detailJson(request.url.pathSegments.last));
          }),
        ),
      );
      await tester.pumpAndSettle();
      for (final slug in slugs) {
        expect(find.byKey(ValueKey('knowledge-$slug')), findsOneWidget);
      }
      await tapVisible(tester, find.byKey(const ValueKey('knowledge-healthy')));
      expect(find.byType(KnowledgeDetailView), findsOneWidget);
      expect(find.text('Fixture overview'), findsOneWidget);
      expect(find.text('Test extension publisher'), findsOneWidget);
      expect(find.text('Treatment'), findsNothing);
      expect(find.text('Causes'), findsNothing);
      expect(find.byType(Image), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(KnowledgeView), findsOneWidget);
      expect(
        listCalls,
        1,
        reason: 'Back preserves screen-local catalogue state.',
      );
      await tapVisible(tester, find.text('Refresh catalogue'));
      expect(listCalls, 2);
    },
  );
  testWidgets(
    'semantic search displays candidates/source and clear restores catalogue',
    (tester) async {
      final repo = FakeKnowledgeRepository();
      await pumpKnowledge(tester, repo);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('knowledge-query')),
        'healthy maize',
      );
      await tapVisible(tester, find.byKey(const Key('knowledge-search')));
      expect(find.text('Retrieved passages'), findsOneWidget);
      expect(
        find.text('Synthetic test-only reviewed passage.'),
        findsOneWidget,
      );
      expect(
        find.text('https://extension.example.test/reviewed'),
        findsOneWidget,
      );
      expect(find.textContaining('not a generated answer'), findsOneWidget);
      expect(repo.searchCalls, 1);
      await tapVisible(tester, find.text('Clear search'));
      expect(find.text('Retrieved passages'), findsNothing);
      repo.emptySearch = true;
      await tester.enterText(
        find.byKey(const Key('knowledge-query')),
        'other maize',
      );
      await tapVisible(tester, find.byKey(const Key('knowledge-search')));
      expect(find.text('No matching passages'), findsOneWidget);
      expect(repo.catalogueCalls, 1);
    },
  );
  testWidgets('catalogue loading/empty and failure/retry are visible', (
    tester,
  ) async {
    final repo = FakeKnowledgeRepository()..pendingCatalogue = Completer();
    await pumpKnowledge(tester, repo);
    expect(find.text('Loading the catalogue…'), findsOneWidget);
    repo.pendingCatalogue!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No published entries yet'), findsOneWidget);
    repo.pendingCatalogue = null;
    repo.failure = const AppException(AppErrorKind.network);
    await tapVisible(tester, find.text('Refresh catalogue'));
    expect(find.textContaining('Check your internet'), findsOneWidget);
    repo.failure = null;
    await tapVisible(tester, find.text('Try again'));
    expect(find.byKey(const ValueKey('knowledge-healthy')), findsOneWidget);
  });
  testWidgets(
    'search loading, timeout retry and validation do not hide catalogue',
    (tester) async {
      final repo = FakeKnowledgeRepository();
      await pumpKnowledge(tester, repo);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('knowledge-query')), 'ab');
      await tapVisible(tester, find.byKey(const Key('knowledge-search')));
      expect(find.textContaining('Enter 3–1000'), findsOneWidget);
      repo.pendingSearch = Completer();
      await tester.enterText(
        find.byKey(const Key('knowledge-query')),
        'maize symptoms',
      );
      await tester.ensureVisible(find.byKey(const Key('knowledge-search')));
      await tester.tap(find.byKey(const Key('knowledge-search')));
      await tester.pump();
      expect(find.text('Searching reviewed passages…'), findsOneWidget);
      repo.pendingSearch!.completeError(
        const AppException(AppErrorKind.timeout),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('connection took too long'), findsOneWidget);
      repo.pendingSearch = null;
      await tapVisible(tester, find.text('Try again'));
      expect(find.text('Retrieved passages'), findsOneWidget);
      expect(find.byKey(const ValueKey('knowledge-healthy')), findsOneWidget);
    },
  );
  testWidgets('detail loading then not found; no stale source content', (
    tester,
  ) async {
    final repo = FakeKnowledgeRepository()..pendingDetail = Completer();
    await pumpDetail(tester, repo);
    expect(find.text('Loading reviewed information…'), findsOneWidget);
    repo.pendingDetail!.completeError(
      const AppException(AppErrorKind.notFound),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entry unavailable'), findsOneWidget);
    expect(find.text('Fixture overview'), findsNothing);
  });
  testWidgets(
    'detail server error retries and empty sections produce no headings',
    (tester) async {
      final repo = FakeKnowledgeRepository()
        ..failure = const AppException(AppErrorKind.server);
      await pumpDetail(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      repo.failure = null;
      repo.pendingDetail = Completer();
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      repo.pendingDetail!.complete(
        DiseaseDetail.fromJson({...detailJson(), 'sections': []}),
      );
      await tester.pumpAndSettle();
      expect(find.text('No reviewed sections published'), findsOneWidget);
      expect(find.text('Source'), findsNothing);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(640, 360),
    const Size(1024, 768),
  ]) {
    testWidgets('library/details handle long returned text at $size, scale 2', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.knowledge,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient(
            (request) async => response(
              request.url.path.endsWith('/diseases')
                  ? {
                      'items': [
                        {
                          ...summaryJson(),
                          'description': 'Long returned text ' * 60,
                        },
                      ],
                    }
                  : detailJson(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('knowledge-healthy')));
      expect(find.byType(KnowledgeDetailView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
