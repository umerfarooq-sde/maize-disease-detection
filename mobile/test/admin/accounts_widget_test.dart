import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/features/admin/view_models/farmer_management_view_model.dart';
import 'package:maizedoctor/features/admin/view_models/audit_log_view_model.dart';
import 'package:maizedoctor/features/admin/views/farmer_management_view.dart';
import 'package:maizedoctor/features/admin/views/audit_log_view.dart';
import '../scans/widget_test.dart' show tapVisible;
import 'accounts_helpers.dart';

Future<void> pumpFarmers(
  WidgetTester tester,
  FakeAccountsRepository repo,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => FarmerManagementViewModel(repo)..load(),
          child: const FarmerManagementView(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> pumpAudits(
  WidgetTester tester,
  FakeAccountsRepository repo,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => AuditLogViewModel(repo)..load(),
          child: const AuditLogView(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'farmer status needs explicit confirmation; cancel preserves account',
    (tester) async {
      final repo = FakeAccountsRepository();
      await pumpFarmers(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Fixture farmer'), findsOneWidget);
      await tapVisible(tester, find.text('Set SUSPENDED'));
      expect(repo.changes, 0);
      await tapVisible(tester, find.text('Cancel'));
      expect(repo.changes, 0);
      await tapVisible(tester, find.text('Set SUSPENDED'));
      await tapVisible(tester, find.text('Confirm status change'));
      expect(repo.changes, 1);
      expect(find.text('Status: SUSPENDED'), findsOneWidget);
    },
  );
  testWidgets('farmer list loading/failure/retry/empty states', (tester) async {
    final repo = FakeAccountsRepository()..pendingFarmers = Completer();
    await pumpFarmers(tester, repo);
    expect(find.text('Updating farmer accounts…'), findsOneWidget);
    repo.pendingFarmers!.completeError(
      const AppException(AppErrorKind.network),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    repo.pendingFarmers = null;
    repo.items = [];
    await tapVisible(tester, find.text('Try again'));
    expect(find.text('No farmer accounts match'), findsOneWidget);
  });
  testWidgets(
    'audit shows timestamp, actor, entity and safe status metadata without editing',
    (tester) async {
      final repo = FakeAccountsRepository();
      await pumpAudits(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('DEACTIVATE · farmer_account'), findsOneWidget);
      expect(find.text('Revoked sessions: 2'), findsOneWidget);
      expect(find.text('Edit audit'), findsNothing);
      await tester.enterText(find.byKey(const Key('audit-from')), '2026-10-15');
      await tester.enterText(find.byKey(const Key('audit-to')), '2026-10-15');
      await tapVisible(tester, find.byKey(const Key('audit-filter')));
      expect(repo.auditCalls, 2);
    },
  );
  testWidgets('audit error retry and empty state', (tester) async {
    final repo = FakeAccountsRepository()
      ..failure = const AppException(AppErrorKind.server);
    await pumpAudits(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    repo.failure = null;
    repo.auditItems = [];
    await tapVisible(tester, find.text('Try again'));
    expect(find.text('No recorded actions match'), findsOneWidget);
  });
  for (final size in [
    const Size(320, 568),
    const Size(640, 360),
    const Size(1024, 768),
  ]) {
    testWidgets('farmer/audit screens fit $size at scale 2', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await pumpFarmers(tester, FakeAccountsRepository());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpAudits(tester, FakeAccountsRepository());
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('audit-filter')));
      expect(tester.takeException(), isNull);
    });
  }
}
