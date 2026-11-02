import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/data/models/selected_leaf_image.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/home/views/home_view.dart';
import 'package:maizedoctor/features/disease_detection/views/scan_view.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import '../auth/session_test.dart' show grant, response, cookie;
import '../history/helpers.dart' as history;
import '../scans/helpers.dart';
import '../scans/widget_test.dart' show tapVisible;
import '../support/design_fonts.dart';

// Original geometric fixture, visibly marked UI TEST. It is never shipped,
// published as a reference photograph or submitted to an inference provider.
Future<SelectedLeafImage> _illustratedFixture() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xffeff3ec), BlendMode.src);
  final leaf = Path()
    ..moveTo(160, 350)
    ..cubicTo(55, 275, 70, 100, 175, 35)
    ..cubicTo(245, 135, 250, 280, 160, 350)
    ..close();
  canvas.drawPath(leaf, Paint()..color = const Color(0xff287551));
  canvas.drawLine(
    const Offset(160, 350),
    const Offset(175, 65),
    Paint()
      ..color = const Color(0xffe4f09a)
      ..strokeWidth = 4,
  );
  final label = TextPainter(
    text: const TextSpan(
      text: 'UI TEST · SYNTHETIC',
      style: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 14,
        color: Color(0xff172b22),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, const Offset(16, 372));
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 400);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return SelectedLeafImage(
    bytes: data!.buffer.asUint8List(),
    mimeType: 'image/png',
    width: 320,
    height: 400,
  );
}

Map<String, Object?> _goldenScan({int? index}) {
  final data = index == null
      ? scanJson(status: ScanStatus.completed)
      : history.historyScanJson(index);
  // Fixed displayed local time across hosts; still serialized as real ISO UTC.
  final created = DateTime(2026, 10, 6, 9).toUtc();
  final finished = created.add(const Duration(seconds: 1));
  data['createdAt'] = created.toIso8601String();
  data['finishedAt'] = finished.toIso8601String();
  (data['image'] as Map<String, Object?>)['uploadedAt'] = created
      .toIso8601String();
  (data['prediction'] as Map<String, Object?>)['inferredAt'] = finished
      .toIso8601String();
  return data;
}

void main() {
  setUpAll(loadDesignFonts);
  for (final config in [
    ('home-guest-light', false, 360.0, 915.0, 'home'),
    ('home-farmer-dark', true, 412.0, 1400.0, 'farmer'),
    ('scan-ready-light', false, 360.0, 915.0, 'ready'),
    ('scan-selected-dark', true, 360.0, 915.0, 'selected'),
    ('scan-uploading-light', false, 360.0, 915.0, 'uploading'),
    ('result-uncertain-light', false, 412.0, 1400.0, 'result'),
    ('result-uncertain-dark', true, 360.0, 1400.0, 'result'),
    ('result-details-dark', true, 412.0, 1400.0, 'details'),
  ]) {
    testWidgets('R-03 ${config.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(config.$3, config.$4);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final theme = ThemeController.system();
      await theme.setMode(config.$2 ? ThemeMode.dark : ThemeMode.light);
      addTearDown(theme.dispose);
      final image = await tester.runAsync(_illustratedFixture);
      expect(image, isNotNull);
      final uploads = FakeScanRepository()
        ..selection = image
        ..result = ScanRecord.fromJson(_goldenScan());
      if (config.$5 == 'uploading') uploads.pending = Completer<ScanRecord>();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MainApp(
            themeController: theme,
            initialLocation: config.$5 == 'home' || config.$5 == 'farmer'
                ? AppRoutes.home
                : AppRoutes.scan,
            scanRepository: uploads,
            config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/login')) {
                return response(grant(), setCookie: cookie);
              }
              if (request.url.path.endsWith('/scans')) {
                return response({
                  'items': [for (var i = 1; i <= 3; i++) _goldenScan(index: i)],
                  'nextCursor': null,
                });
              }
              if (request.url.path.endsWith('/image')) {
                return http.Response.bytes(
                  image!.bytes,
                  200,
                  headers: {'content-type': 'image/png'},
                );
              }
              return response(null, status: 503);
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (config.$5 == 'farmer') {
        await tester.runAsync(
          () => tester
              .element(find.byType(HomeView))
              .read<FarmerSessionViewModel>()
              .signIn('fixture@example.test', 'synthetic-password'),
        );
        await tester.pumpAndSettle();
      }
      if (['selected', 'uploading', 'result', 'details'].contains(config.$5)) {
        final model = tester
            .element(find.byType(ScanView))
            .read<ScanViewModel>();
        await model.select(LeafImageSource.gallery);
        await tester.pumpAndSettle();
        if (config.$5 == 'uploading') {
          unawaited(model.upload());
          uploads.reportProgress!(0.37);
          await tester.pumpAndSettle();
        } else if (config.$5 != 'selected') {
          await model.upload();
          await tester.pumpAndSettle();
          if (config.$5 == 'details') {
            await tapVisible(tester, find.text('All model scores'));
            await tapVisible(tester, find.text('Analysis details'));
          }
        }
      }
      // Image codecs may finish outside the fake test clock after a settled
      // frame. Await the actual displayed providers so blank previews cannot
      // accidentally become approved visual baselines.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate().toList()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
            onError: (error, stack) =>
                throw StateError('Synthetic fixture failed to decode'),
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/${config.$1}.png'),
      );
      if (uploads.pending != null) {
        uploads.pending!.complete(uploads.result);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
