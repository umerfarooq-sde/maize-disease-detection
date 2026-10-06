import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'helpers.dart';

Future<void> pumpScan(
  WidgetTester tester,
  FakeScanRepository repository, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    MainApp(initialLocation: AppRoutes.scan, scanRepository: repository),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'gallery preview, failed upload, retry, saved pending scan and reset',
    (tester) async {
      final repo = FakeScanRepository()
        ..uploadError = const AppException(AppErrorKind.network);
      await pumpScan(tester, repo);
      await tapVisible(tester, find.byKey(const Key('gallery-leaf-action')));
      expect(find.byKey(const Key('leaf-image-preview')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('upload-leaf-action')));
      expect(find.text('Try again'), findsOneWidget);
      repo.uploadError = null;
      await tapVisible(tester, find.text('Try again'));
      expect(find.text('Photo saved'), findsOneWidget);
      expect(
        find.text('Your scan is saved. Disease analysis is not available yet.'),
        findsOneWidget,
      );
      expect(repo.keys[0], repo.keys[1]);
      await tapVisible(tester, find.text('Start a new scan'));
      expect(find.byKey(const Key('leaf-image-preview')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large text, camera availability and upload progress fit a small screen',
    (tester) async {
      final repo = FakeScanRepository()
        ..cameraSupported = false
        ..pending = Completer<ScanRecord>();
      await pumpScan(tester, repo, scale: 2);
      expect(find.byKey(const Key('camera-leaf-action')), findsNothing);
      await tapVisible(tester, find.byKey(const Key('gallery-leaf-action')));
      await tester.ensureVisible(find.byKey(const Key('upload-leaf-action')));
      await tester.tap(find.byKey(const Key('upload-leaf-action')));
      await tester.pump();
      repo.reportProgress!(0.4);
      await tester.pump();
      expect(find.text('Uploading photo… 40%'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('gallery-leaf-action')),
            )
            .onPressed,
        isNull,
      );
      repo.reportProgress!(1);
      await tester.pump();
      expect(find.text('Saving your scan…'), findsOneWidget);
      repo.pending!.complete(savedScan);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
