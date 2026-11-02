import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/models/knowledge.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/disease_detection/views/result_view.dart';
import 'package:maizedoctor/features/disease_detection/views/scan_view.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import 'package:maizedoctor/features/disease_detection/widgets/scan_result_image.dart';
import '../auth/session_test.dart' show response;
import '../scans/helpers.dart';
import '../scans/widget_test.dart' show tapVisible;
import '../knowledge/helpers.dart' as knowledge;
import '../support/design_fonts.dart';

ScanRecord classifiedScan(String label) {
  final data = scanJson(status: ScanStatus.completed);
  final prediction = data['prediction'] as Map<String, Object?>;
  prediction['predictedClass'] = label;
  prediction['probabilities'] = {
    for (final name in knowledge.labels) name: name == label ? 0.7 : 0.1,
  };
  return ScanRecord.fromJson(data);
}

void main() {
  setUpAll(loadDesignFonts);
  for (final (index, label) in knowledge.labels.indexed) {
    testWidgets(
      '$label remains literal, policy uncertain, guest protected, opens existing knowledge',
      (tester) async {
        final uploads = FakeScanRepository()..result = classifiedScan(label);
        final slug = knowledge.slugs[index];
        expect(knowledgeSlugForClass(label), slug);
        expect(knowledgeSlugForClass('Untrained_condition'), isNull);
        await tester.pumpWidget(
          MainApp(
            initialLocation: AppRoutes.scan,
            scanRepository: uploads,
            config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/diseases/$slug')) {
                return response(knowledge.detailJson(slug));
              }
              if (request.url.path.endsWith('/diseases')) {
                return response({
                  'items': [knowledge.summaryJson(slug)],
                });
              }
              return response(null, status: 503);
            }),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('gallery-leaf-action')));
        expect(uploads.keys, isEmpty);
        await tapVisible(tester, find.byKey(const Key('upload-leaf-action')));
        expect(find.byType(ScanResultView), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('prediction-leading-label')))
              .data,
          label.replaceAll('_', ' '),
        );
        expect(find.text('Uncertain result'), findsOneWidget);
        expect(
          find.textContaining('even when its score is high'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('explain-scan-action')), findsNothing);
        final image = tester.widget<ScanResultImage>(
          find.byType(ScanResultImage),
        );
        expect(image.anonymousKey, uploads.keys.single);
        expect(image.selectedImage, same(leafImage));
        expect(find.byKey(const Key('probability-Healthy')), findsNothing);
        await tapVisible(tester, find.text('All model scores'));
        for (final name in knowledge.labels) {
          final bar = tester.widget<LinearProgressIndicator>(
            find.byKey(ValueKey('prediction-score-$name')),
          );
          expect(bar.value, name == label ? 0.7 : 0.1);
        }
        await tapVisible(tester, find.text('Analysis details'));
        expect(
          find.text('Confidence policy: THRESHOLD_UNCONFIGURED'),
          findsOneWidget,
        );
        expect(
          find.text('Confidence threshold: null (not configured)'),
          findsOneWidget,
        );
        expect(
          find.textContaining('mobilenet-v3-small-v2-20261009'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Preprocessing version: 1.0.0'),
          findsOneWidget,
        );
        if (label == 'Healthy') {
          expect(find.textContaining('does not rule out'), findsOneWidget);
        }
        // Closing/reopening after scrolling must not mix bool expansion state with
        // scroll offsets from the page or the selectable version fields.
        await tapVisible(tester, find.text('Analysis details'));
        await tapVisible(tester, find.text('Analysis details'));
        await tapVisible(
          tester,
          find.byKey(const Key('read-disease-information')),
        );
        expect(
          GoRouter.of(
            tester.element(find.text('Reviewed knowledge')),
          ).routeInformationProvider.value.uri.path,
          '${AppRoutes.knowledge}/$slug',
        );
        expect(
          find.text('Synthetic test-only reviewed passage.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'scan another leaf clears selection/result without another upload',
    (tester) async {
      final uploads = FakeScanRepository()..result = classifiedScan('Healthy');
      await tester.pumpWidget(
        MainApp(initialLocation: AppRoutes.scan, scanRepository: uploads),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('gallery-leaf-action')));
      await tapVisible(tester, find.byKey(const Key('upload-leaf-action')));
      await tapVisible(tester, find.byKey(const Key('new-scan-action')));
      expect(find.byType(ScanView), findsOneWidget);
      expect(find.byKey(const Key('leaf-image-preview')), findsNothing);
      expect(uploads.keys, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'progress updates keep selected preview subtree stable and prevent duplicate uploads',
    (tester) async {
      final uploads = FakeScanRepository()..pending = Completer<ScanRecord>();
      final model = ScanViewModel(uploads);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: model,
              child: const ScanView(),
            ),
          ),
        ),
      );
      await model.select(LeafImageSource.gallery);
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(
        find.byKey(const Key('leaf-image-preview')),
      );
      final pending = model.upload();
      await tester.pump();
      await model.upload();
      uploads.reportProgress!(0.37);
      await tester.pump();
      expect(
        tester.widget<Image>(find.byKey(const Key('leaf-image-preview'))),
        same(image),
      );
      expect(find.text('Uploading photo… 37%'), findsOneWidget);
      expect(uploads.keys, hasLength(1));
      uploads.pending!.complete(savedScan);
      await pending;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
