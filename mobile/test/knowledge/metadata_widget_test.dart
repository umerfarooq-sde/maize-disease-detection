import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/repositories/knowledge_repository.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_detail_view_model.dart';
import 'package:maizedoctor/features/disease_knowledge/views/knowledge_detail_view.dart';
import '../auth/session_test.dart' show response;
import 'helpers.dart';

Map<String, Object?> reviewedFixture() => {
  ...summaryJson(),
  'slug': 'synthetic-info',
  'name': 'Synthetic informational fixture',
  'sections': <Object>[],
  'catalogue': {
    'classifierSupported': false,
    'literalLabel': null,
    'applicability': {
      'growthStages': ['Synthetic reviewed fixture text. ' * 12],
      'severityDescriptors': ['Synthetic severity fixture only.'],
      'source': sourceJson(),
    },
  },
};

Future<void> showDetail(
  WidgetTester tester,
  KnowledgeDetailViewModel model,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: model,
          child: const KnowledgeDetailView(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'slow reviewed API data renders stage, severity and attribution with long text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final pending = Completer<http.Response>();
      http.Request? observed;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((request) {
          observed = request;
          return pending.future;
        }),
      );
      addTearDown(api.close);
      final model = KnowledgeDetailViewModel(
        ApiKnowledgeRepository(api),
        'synthetic-info',
      );
      addTearDown(model.dispose);
      await showDetail(tester, model);
      final loading = model.load();
      await tester.pump();
      expect(observed?.url.path, '/api/v1/diseases/synthetic-info');
      expect(observed?.headers.containsKey('authorization'), false);
      expect(model.error, isNull);
      expect(model.loading, true);
      expect(find.text('Loading reviewed information…'), findsOneWidget);
      expect(find.text('Reviewed growth-stage applicability'), findsNothing);
      pending.complete(response(reviewedFixture()));
      await loading;
      await tester.pumpAndSettle();
      expect(find.text('Reviewed growth-stage applicability'), findsOneWidget);
      expect(find.text('Reviewed severity descriptions'), findsOneWidget);
      expect(find.text('Synthetic severity fixture only.'), findsOneWidget);
      expect(find.text('Test extension publisher'), findsOneWidget);
      expect(
        find.text(
          'Informational knowledge entry · not a trained classifier output',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final failure in ['api', 'parse']) {
    testWidgets(
      '$failure failure is terminal and explicit retry renders reviewed metadata',
      (tester) async {
        var calls = 0;
        final api = ApiClient(
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          client: MockClient((_) async {
            if (++calls == 1) {
              return failure == 'api'
                  ? response(null, status: 503)
                  : response({'slug': 'synthetic-info'});
            }
            return response(reviewedFixture());
          }),
        );
        addTearDown(api.close);
        final model = KnowledgeDetailViewModel(
          ApiKnowledgeRepository(api),
          'synthetic-info',
        );
        addTearDown(model.dispose);
        await showDetail(tester, model);
        await model.load();
        await tester.pumpAndSettle();
        expect(model.loading, false);
        expect(model.detail, isNull);
        expect(
          model.error?.kind,
          failure == 'api' ? AppErrorKind.server : AppErrorKind.invalidResponse,
        );
        expect(find.text('Reviewed growth-stage applicability'), findsNothing);
        await tester.ensureVisible(find.text('Try again'));
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(model.error, isNull);
        expect(
          find.text('Reviewed growth-stage applicability'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
