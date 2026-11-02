import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/scan_prediction.dart';
import 'package:maizedoctor/features/disease_detection/widgets/prediction_summary.dart';
import 'helpers.dart';

void main() {
  test('dark theme supplies a contrasting foreground and on-primary color', () {
    final scheme = AppTheme.dark.colorScheme;
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.onSurface, isNot(scheme.surface));
    expect(scheme.onPrimary, isNot(scheme.primary));
  });

  for (final dark in [false, true]) {
    testWidgets(
      'all four model scores are visible in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        final prediction = ScanPrediction.fromJson(predictionJson());
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PredictionSummary(prediction: prediction),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text('All model scores'));
        await tester.tap(find.text('All model scores'));
        await tester.pumpAndSettle();
        for (final name in ScanPrediction.classLabels) {
          expect(
            find.byKey(ValueKey('prediction-score-$name')),
            findsOneWidget,
          );
        }
        expect(find.text('All model scores'), findsOneWidget);
        expect(find.text('Uncertain result'), findsOneWidget);
        expect(find.textContaining('not the probability'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
