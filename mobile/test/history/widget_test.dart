import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/scan_history_page.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/features/scan_history/view_models/scan_history_view_model.dart';
import 'package:maizedoctor/features/scan_history/views/history_view.dart';
import 'helpers.dart';

Widget page(
  ScanHistoryViewModel model, {
  ValueChanged<ScanRecord>? onOpen,
  VoidCallback? onSignIn,
  double textScale = 1,
}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: ChangeNotifierProvider.value(
        value: model,
        child: HistoryView(onOpenScan: onOpen, onSignIn: onSignIn),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'guest has an actionable sign-in boundary and makes no history request',
    (tester) async {
      final repository = FakeScanRecordsRepository()
        ..hasAuthenticatedSession = false;
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      var signIns = 0;
      await model.load();
      await tester.pumpWidget(page(model, onSignIn: () => signIns++));
      expect(find.text('Sign in to see your scans'), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-sign-in')));
      expect(signIns, 1);
      expect(repository.requests, isEmpty);
    },
  );

  testWidgets('loading, empty and safe retry errors have distinct states', (
    tester,
  ) async {
    final pending = Completer<ScanHistoryPage>();
    final repository = FakeScanRecordsRepository()
      ..responses.add(pending.future);
    final model = ScanHistoryViewModel(repository);
    addTearDown(model.dispose);
    final loading = model.load();
    await tester.pumpWidget(page(model));
    expect(find.text('Loading your scans…'), findsOneWidget);
    pending.complete(ScanHistoryPage(items: [], nextCursor: null));
    await loading;
    await tester.pumpAndSettle();
    expect(find.text('Your scan history starts here'), findsOneWidget);
    repository.responses.add(
      Future.error(const AppException(AppErrorKind.network)),
    );
    await model.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Something needs attention'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'private history shows model suggestions, uncertainty and opens a typed scan',
    (tester) async {
      final repository = FakeScanRecordsRepository()
        ..responses.add(
          Future.value(
            ScanHistoryPage(items: [historyScan(1)], nextCursor: null),
          ),
        );
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      ScanRecord? opened;
      await tester.pumpWidget(page(model, onOpen: (scan) => opened = scan));
      await tester.pumpAndSettle();
      expect(find.text('Model suggestion: Healthy'), findsOneWidget);
      expect(find.text('Model score: 70.0%'), findsOneWidget);
      expect(find.text('Uncertain result'), findsOneWidget);
      expect(
        find.textContaining('mobilenet-v3-small-v2-20261009'),
        findsOneWidget,
      );
      await tester.tap(find.text('View scan'));
      expect(opened?.id, historyId(1));
      expect(tester.takeException(), null);
    },
  );

  testWidgets('load-more failure keeps prior scans visible with a retry', (
    tester,
  ) async {
    final repository = FakeScanRecordsRepository()
      ..responses.add(
        Future.value(
          ScanHistoryPage(items: [historyScan(1)], nextCursor: historyId(1)),
        ),
      );
    final model = ScanHistoryViewModel(repository);
    addTearDown(model.dispose);
    await model.load();
    await tester.pumpWidget(page(model));
    final failed = Completer<ScanHistoryPage>();
    repository.responses.add(failed.future);
    await tester.tap(find.byKey(const Key('history-load-more')));
    failed.completeError(const AppException(AppErrorKind.network));
    await tester.pumpAndSettle();
    expect(find.text('Model suggestion: Healthy'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    repository.responses.add(
      Future.value(ScanHistoryPage(items: [historyScan(2)], nextCursor: null)),
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Model suggestion: Healthy'), findsNWidgets(2));
  });

  testWidgets('narrow large-text history remains scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeScanRecordsRepository()
      ..responses.add(
        Future.value(
          ScanHistoryPage(
            items: [
              historyScan(1, status: ScanStatus.failed),
              historyScan(2),
            ],
            nextCursor: null,
          ),
        ),
      );
    final model = ScanHistoryViewModel(repository);
    addTearDown(model.dispose);
    await model.load();
    await tester.pumpWidget(page(model, textScale: 2));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
}
