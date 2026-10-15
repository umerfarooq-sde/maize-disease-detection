import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/models/admin_accounts.dart';
import 'package:maizedoctor/data/repositories/admin_accounts_repository.dart';
import 'package:maizedoctor/features/admin/view_models/farmer_management_view_model.dart';
import 'package:maizedoctor/features/admin/view_models/audit_log_view_model.dart';
import '../auth/session_test.dart' show response;
import '../profile/model_repository_test.dart' show ProfileTokens;
import 'accounts_helpers.dart';

void main() {
  test(
    'Admin transport authenticates, paginates, pins status revision and parses only safe audit data',
    () async {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: ProfileTokens(),
        client: MockClient((request) async {
          expect(request.headers['Authorization'], isNotNull);
          if (request.method == 'PATCH') {
            expect(jsonDecode(request.body), {
              'status': 'SUSPENDED',
              'expectedRevision': 'a' * 64,
            });
            return response({'farmer': farmerAccountJson(status: 'SUSPENDED')});
          }
          expect(request.url.queryParameters['limit'], '20');
          if (request.url.path.endsWith('audit-logs')) {
            return response({
              'items': [auditJson()],
              'nextCursor': null,
            });
          }
          expect(request.url.queryParameters['status'], 'ACTIVE');
          return response({
            'items': [farmerAccountJson()],
            'nextCursor': null,
          });
        }),
      );
      addTearDown(api.close);
      final repo = ApiAdminAccountsRepository(api);
      final page = await repo.farmers(status: 'ACTIVE');
      expect(page.items.single.status, 'ACTIVE');
      expect(
        (await repo.changeStatus(page.items.single, 'SUSPENDED')).status,
        'SUSPENDED',
      );
      final audits = await repo.audits(
        action: 'DEACTIVATE',
        from: '2026-10-15',
        to: '2026-10-15',
      );
      expect(audits.items.single.metadata['revokedSessions'], 2);
    },
  );
  test(
    'Admin DTOs reject secrets, unknown roles, malformed pages and invalid filters before HTTP',
    () async {
      expect(
        () => ManagedFarmer.fromJson({
          ...farmerAccountJson(),
          'passwordHash': 'private',
        }),
        throwsA(isA<AppException>()),
      );
      expect(
        () => AdminAuditEntry.fromJson({
          ...auditJson(),
          'metadata': {'token': 'private'},
        }),
        throwsA(isA<AppException>()),
      );
      expect(
        () => accountsPage(
          {
            'items': [farmerAccountJson(), farmerAccountJson()],
            'nextCursor': null,
          },
          ManagedFarmer.fromJson,
          (farmer) => farmer.id,
        ),
        throwsA(isA<AppException>()),
      );
      var calls = 0;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((_) async {
          calls++;
          return response(null);
        }),
      );
      addTearDown(api.close);
      final repo = ApiAdminAccountsRepository(api);
      await expectLater(
        repo.farmers(status: 'ADMIN'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.farmers(cursor: 'bad'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.audits(from: '2026-02-30', to: '2026-03-01'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.audits(from: '2025-01-01', to: '2026-10-15'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.audits(actorId: 'bad'),
        throwsA(isA<AppException>()),
      );
      expect(calls, 0);
    },
  );
  test(
    'farmer management loads/filters/updates, suppresses duplicate requests and retries',
    () async {
      final repo = FakeAccountsRepository()..pendingFarmers = Completer();
      final model = FarmerManagementViewModel(repo);
      addTearDown(model.dispose);
      final pending = model.load();
      expect(model.busy, true);
      await model.load();
      expect(repo.farmerCalls, 1);
      repo.pendingFarmers!.complete((items: repo.items, nextCursor: farmerId));
      await pending;
      expect(model.nextCursor, farmerId);
      repo.pendingFarmers = null;
      await model.changeStatus(model.items.single, 'SUSPENDED');
      expect(model.items.single.status, 'SUSPENDED');
      expect(model.message, contains('sessions were revoked'));
      await model.filter('DEACTIVATED', '');
      expect(model.items, isEmpty);
      expect(repo.lastStatus, 'DEACTIVATED');
      repo.failure = const AppException(AppErrorKind.timeout);
      await model.load();
      expect(model.error!.kind, AppErrorKind.timeout);
      repo.failure = null;
      await model.load();
      expect(model.error, isNull);
    },
  );
  test('audit loading/pagination/filters and failures are explicit', () async {
    final repo = FakeAccountsRepository();
    final model = AuditLogViewModel(repo);
    addTearDown(model.dispose);
    await model.load();
    expect(model.items.single.action, 'DEACTIVATE');
    await model.load(more: true);
    expect(repo.auditCalls, 1);
    await model.filter(
      selectedAction: 'DEACTIVATE',
      start: '2026-10-15',
      end: '2026-10-15',
    );
    expect(repo.lastAction, 'DEACTIVATE');
    repo.failure = const AppException(AppErrorKind.server);
    await model.load();
    expect(model.error!.kind, AppErrorKind.server);
    repo.failure = null;
    repo.auditItems = [];
    await model.load();
    expect(model.items, isEmpty);
  });
  test(
    'Admin account/audit results are fenced after session changes or disposal',
    () async {
      final repo = FakeAccountsRepository()..pendingFarmers = Completer();
      final model = FarmerManagementViewModel(repo);
      final pending = model.load();
      repo.sessionRevision = 2;
      repo.pendingFarmers!.complete((items: repo.items, nextCursor: null));
      await pending;
      expect(model.items, isEmpty);
      model.dispose();
      final other = FakeAccountsRepository()..pendingAudits = Completer();
      final audit = AuditLogViewModel(other);
      final late = audit.load();
      audit.dispose();
      other.pendingAudits!.complete((
        items: other.auditItems,
        nextCursor: null,
      ));
      await late;
      expect(audit.items, isEmpty);
    },
  );
}
