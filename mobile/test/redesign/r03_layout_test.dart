import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/home/view_models/home_view_model.dart';
import 'package:maizedoctor/features/home/views/home_view.dart';
import 'package:maizedoctor/features/disease_detection/views/scan_view.dart';
import 'package:maizedoctor/features/disease_detection/views/result_view.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_result_arguments.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_result_view_model.dart';
import '../features/home_view_model_test.dart' show ControlledRepository;
import '../scans/helpers.dart';
import '../scans/widget_test.dart' show tapVisible;
import '../support/design_fonts.dart';

Widget r03Host(Widget child, bool dark) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Scaffold(
    appBar: AppBar(title: const Text('MAIZEDOCTOR')),
    body: child,
  ),
);

void main() {
  setUpAll(loadDesignFonts);
  for (final width in [
    320.0,
    360.0,
    412.0,
    480.0,
    600.0,
    840.0,
    1024.0,
    1280.0,
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'R-03 $width dp / $scale text light and dark Home, scan and expanded result',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 915);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
          });
          for (final dark in [false, true]) {
            final home = HomeViewModel(ControlledRepository());
            final uploads = FakeScanRepository();
            final scan = ScanViewModel(uploads);
            final record = ScanRecord.fromJson(
              scanJson(status: ScanStatus.completed),
            );
            final result = ScanResultViewModel(
              FakeScanRecordsRepository(),
              scanId: record.id,
              initial: ScanResultArguments(
                scan: record,
                selectedImage: leafImage,
              ),
            );
            await tester.pumpWidget(
              r03Host(
                ChangeNotifierProvider.value(
                  value: home,
                  child: const HomeView(),
                ),
                dark,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Home $width $scale $dark',
            );
            if (scale == 1) {
              expect(
                find.byKey(const Key('scan-leaf-action')).hitTestable(),
                findsOneWidget,
              );
            }
            await tester.ensureVisible(find.byKey(const Key('home-assistant')));
            expect(
              find.byKey(const Key('home-assistant')).hitTestable(),
              findsOneWidget,
            );
            await tester.pumpWidget(
              r03Host(
                ChangeNotifierProvider.value(
                  value: scan,
                  child: const ScanView(),
                ),
                dark,
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const Key('camera-leaf-action')),
            );
            expect(
              find.byKey(const Key('camera-leaf-action')).hitTestable(),
              findsOneWidget,
            );
            await scan.select(LeafImageSource.gallery);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<Image>(find.byKey(const Key('leaf-image-preview')))
                  .fit,
              BoxFit.contain,
            );
            await tester.ensureVisible(
              find.byKey(const Key('upload-leaf-action')),
            );
            expect(
              find.byKey(const Key('upload-leaf-action')).hitTestable(),
              findsOneWidget,
            );
            await scan.upload();
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Start a new scan'));
            expect(find.text('Start a new scan').hitTestable(), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Scan $width $scale $dark',
            );
            await tester.pumpWidget(
              r03Host(
                ChangeNotifierProvider.value(
                  value: result,
                  child: ScanResultView(onNewScan: () {}),
                ),
                dark,
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Uncertain result'), findsOneWidget);
            await tapVisible(tester, find.text('All model scores'));
            await tapVisible(tester, find.text('Analysis details'));
            await tester.ensureVisible(
              find.textContaining('Preprocessing version: 1.0.0'),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'Result $width $scale $dark',
            );
            await tester.pumpWidget(const SizedBox());
            home.dispose();
            scan.dispose();
            result.dispose();
          }
        },
      );
    }
  }
}
