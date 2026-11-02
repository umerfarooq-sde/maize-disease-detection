import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/admin_accounts.dart';
import 'package:maizedoctor/features/admin/view_models/farmer_management_view_model.dart';
import 'package:maizedoctor/features/admin/view_models/audit_log_view_model.dart';
import 'accounts_helpers.dart';

void main() {
  test('overlapping account pages render one copy per identity', () async {
    final repo = FakeAccountsRepository()..cursor = farmerId;
    final model = FarmerManagementViewModel(repo);
    addTearDown(model.dispose);
    await model.load();
    repo.cursor = null;
    repo.items = [
      ...repo.items,
      ManagedFarmer.fromJson(
        farmerAccountJson(id: '42345678-1234-4123-8123-123456789abc'),
      ),
    ];
    await model.load(more: true);
    expect(model.items.length, 2);
    expect(model.items.map((item) => item.id).toSet().length, 2);
    expect(model.nextCursor, isNull);
  });
  test('overlapping audit pages render one copy per event', () async {
    final repo = FakeAccountsRepository()
      ..cursor = '22345678-1234-4123-8123-123456789abc';
    final model = AuditLogViewModel(repo);
    addTearDown(model.dispose);
    await model.load();
    repo.cursor = null;
    repo.auditItems = [
      ...repo.auditItems,
      AdminAuditEntry.fromJson({
        ...auditJson(),
        'id': '42345678-1234-4123-8123-123456789abc',
      }),
    ];
    await model.load(more: true);
    expect(model.items.length, 2);
    expect(model.items.map((item) => item.id).toSet().length, 2);
  });
  test(
    'repeated account cursor is rejected, retains prior page and permits refresh',
    () async {
      final repo = FakeAccountsRepository()..cursor = farmerId;
      final model = FarmerManagementViewModel(repo);
      addTearDown(model.dispose);
      await model.load();
      await model.load(more: true);
      expect(model.error?.kind, AppErrorKind.invalidResponse);
      expect(model.items.length, 1);
      expect(model.busy, false);
      repo.cursor = null;
      await model.load();
      expect(model.error, isNull);
    },
  );
  test(
    'repeated audit cursor is rejected without a duplicated event',
    () async {
      final repo = FakeAccountsRepository()
        ..cursor = '22345678-1234-4123-8123-123456789abc';
      final model = AuditLogViewModel(repo);
      addTearDown(model.dispose);
      await model.load();
      await model.load(more: true);
      expect(model.error?.kind, AppErrorKind.invalidResponse);
      expect(model.items.length, 1);
      expect(model.busy, false);
    },
  );
  test(
    'late audit page cannot append after account revision changes',
    () async {
      final repo = FakeAccountsRepository()
        ..cursor = '22345678-1234-4123-8123-123456789abc';
      final model = AuditLogViewModel(repo);
      await model.load();
      repo.pendingAudits = Completer();
      final load = model.load(more: true);
      repo.sessionRevision = 2;
      repo.pendingAudits!.complete((items: repo.auditItems, nextCursor: null));
      await load;
      expect(model.items.length, 1);
      model.dispose();
      expect(model.items, isEmpty);
    },
  );
}
