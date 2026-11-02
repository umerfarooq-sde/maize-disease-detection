import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_result_arguments.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_result_view_model.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import 'package:maizedoctor/features/disease_detection/views/result_view.dart';
import 'package:maizedoctor/features/disease_detection/views/scan_view.dart';
import 'package:maizedoctor/features/disease_detection/utils/scan_presentation.dart';
import 'helpers.dart';

Future<void> showResult(
  WidgetTester tester,
  ScanResultViewModel model, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: model,
          child: ScanResultView(onNewScan: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('literal labels have readable names without relabeling', () {
    expect(diseaseLabel('Common_Rust'), 'Common Rust');
    expect(diseaseLabel('Gray_Leaf_Spot'), 'Gray Leaf Spot');
    expect(diseaseLabel('Healthy'), 'Healthy');
    expect(
      diseaseLabel('Northern_Corn_Leaf_Blight'),
      'Northern Corn Leaf Blight',
    );
    expect(scanStatusLabel(ScanStatus.failed), 'Analysis failed');
    expect(modelScore(0.987), '98.7%');
  });
  testWidgets(
    'high model score remains uncertain when no confidence policy is approved',
    (tester) async {
      final data = scanJson(status: ScanStatus.completed);
      final prediction = data['prediction'] as Map<String, Object?>;
      prediction['confidence'] = 0.99;
      prediction['probabilities'] = {
        'Common_Rust': 0.003,
        'Gray_Leaf_Spot': 0.003,
        'Healthy': 0.99,
        'Northern_Corn_Leaf_Blight': 0.004,
      };
      final scan = ScanRecord.fromJson(data);
      final model = ScanResultViewModel(
        FakeScanRecordsRepository(),
        scanId: scan.id,
        initial: ScanResultArguments(scan: scan, selectedImage: leafImage),
      );
      addTearDown(model.dispose);
      await showResult(tester, model);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('prediction-leading-label')))
            .data,
        'Healthy',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('classifier-score'))).data,
        '99.0%',
      );
      expect(find.text('Uncertain result'), findsOneWidget);
      expect(
        find.textContaining('even when its score is high'),
        findsOneWidget,
      );
      expect(find.textContaining('not diagnostic accuracy'), findsOneWidget);
      expect(find.textContaining('does not rule out'), findsOneWidget);
      await tester.ensureVisible(find.text('Analysis details'));
      await tester.tap(find.text('Analysis details'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('mobilenet-v3-small-v2-20261009'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('leaf-image-preview')), findsOneWidget);
      expect(find.text('Four-class breakdown'), findsOneWidget);
      await tester.ensureVisible(find.text('All model scores'));
      await tester.tap(find.text('All model scores'));
      await tester.pumpAndSettle();
      for (final label in [
        'Healthy',
        'Northern_Corn_Leaf_Blight',
        'Common_Rust',
        'Gray_Leaf_Spot',
      ]) {
        expect(find.byKey(ValueKey('probability-$label')), findsOneWidget);
      }
      final ordered =
          [
            'Healthy',
            'Northern_Corn_Leaf_Blight',
            'Common_Rust',
            'Gray_Leaf_Spot',
          ].map(
            (label) => tester
                .getTopLeft(find.byKey(ValueKey('probability-$label')))
                .dy,
          );
      expect(ordered, ordered.toList()..sort());
      expect(
        find.bySemanticsLabel(
          'Healthy, classifier output 99.0%, highest output',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'configured confidence renders a qualified prediction and long disease label',
    (tester) async {
      final data = scanJson(status: ScanStatus.completed);
      final prediction = data['prediction'] as Map<String, Object?>;
      prediction['predictedClass'] = 'Northern_Corn_Leaf_Blight';
      prediction['probabilities'] = {
        'Common_Rust': 0.1,
        'Gray_Leaf_Spot': 0.1,
        'Healthy': 0.1,
        'Northern_Corn_Leaf_Blight': 0.7,
      };
      prediction['confidenceThreshold'] = 0.65;
      prediction['predictionStatus'] = 'CONFIDENT';
      prediction['uncertaintyReason'] = null;
      final scan = ScanRecord.fromJson(data);
      final model = ScanResultViewModel(
        FakeScanRecordsRepository(),
        scanId: scan.id,
        initial: ScanResultArguments(scan: scan, selectedImage: leafImage),
      );
      addTearDown(model.dispose);
      await showResult(tester, model);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('prediction-leading-label')))
            .data,
        'Northern Corn Leaf Blight',
      );
      expect(find.text('Threshold met'), findsOneWidget);
      expect(find.textContaining('not a confirmed diagnosis'), findsOneWidget);
      expect(find.text('Uncertain result'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'below-threshold result stays explicit and readable in dark theme',
    (tester) async {
      final data = scanJson(status: ScanStatus.completed);
      final prediction = data['prediction'] as Map<String, Object?>;
      prediction['confidenceThreshold'] = 0.8;
      prediction['predictionStatus'] = 'LOW_CONFIDENCE';
      prediction['uncertaintyReason'] = 'BELOW_VALIDATION_THRESHOLD';
      final scan = ScanRecord.fromJson(data);
      final model = ScanResultViewModel(
        FakeScanRecordsRepository(),
        scanId: scan.id,
        initial: ScanResultArguments(scan: scan),
      );
      addTearDown(model.dispose);
      await showResult(tester, model, theme: AppTheme.dark);
      expect(find.text('Below confidence threshold'), findsOneWidget);
      expect(find.text('Policy threshold: 80.0%'), findsOneWidget);
      expect(find.byKey(const Key('saved-leaf-image')), findsOneWidget);
      await tester.ensureVisible(find.text('All model scores'));
      await tester.tap(find.text('All model scores'));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('invalid response renders a safe retryable state', (
    tester,
  ) async {
    final records = FakeScanRecordsRepository()
      ..error = const AppException(AppErrorKind.invalidResponse);
    final model = ScanResultViewModel(records, scanId: savedScan.id);
    addTearDown(model.dispose);
    unawaited(model.load());
    await showResult(tester, model);
    expect(find.textContaining('could not read the response'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('prediction-leading-label')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed result retry shows upload progress and analysis wait before success',
    (tester) async {
      final scan = ScanRecord.fromJson(scanJson(status: ScanStatus.failed));
      final uploads = FakeScanRepository()..pending = Completer<ScanRecord>();
      final model = ScanResultViewModel(
        FakeScanRecordsRepository(),
        scanId: scan.id,
        uploads: uploads,
        initial: ScanResultArguments(
          scan: scan,
          selectedImage: leafImage,
          requestKey: '1227d27c-72fa-4f6f-a701-27d9db89ce69',
        ),
      );
      addTearDown(model.dispose);
      await showResult(tester, model);
      final retry = find.byKey(const Key('analysis-retry-action'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      uploads.reportProgress!(0.5);
      await tester.pump();
      expect(find.text('Uploading photo… 50%'), findsOneWidget);
      uploads.reportProgress!(1);
      await tester.pump();
      expect(find.text('Waiting for analysis…'), findsOneWidget);
      uploads.pending!.complete(
        ScanRecord.fromJson(scanJson(status: ScanStatus.completed)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('prediction-leading-label')))
            .data,
        'Healthy',
      );
      expect(find.text('Retry analysis'), findsNothing);
      expect(uploads.keys, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'completion emits a result navigation builder once and keeps the key out of URLs',
    (tester) async {
      final uploads = FakeScanRepository()
        ..result = ScanRecord.fromJson(scanJson(status: ScanStatus.completed));
      final model = ScanViewModel(uploads);
      addTearDown(model.dispose);
      final results = <ScanResultArguments>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: model,
              child: ScanView(onResult: results.add),
            ),
          ),
        ),
      );
      await model.select(LeafImageSource.gallery);
      await model.upload();
      await tester.pumpAndSettle();
      expect(results, hasLength(1));
      expect(results.single.scan.status, ScanStatus.completed);
      expect(results.single.requestKey, uploads.keys.single);
      expect(results.single.selectedImage, leafImage);
      expect(results.single.toString(), isNot(contains(uploads.keys.single)));
      await tester.pump();
      expect(results, hasLength(1));
    },
  );
}
