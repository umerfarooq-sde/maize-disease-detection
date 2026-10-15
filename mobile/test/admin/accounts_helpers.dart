import 'dart:async';
import 'package:maizedoctor/data/models/admin_accounts.dart';
import 'package:maizedoctor/data/repositories/admin_accounts_repository.dart';

const farmerId = '12345678-1234-4123-8123-123456789abc';
Map<String, Object?> farmerAccountJson({
  String id = farmerId,
  String status = 'ACTIVE',
}) => {
  'id': id,
  'email': 'farmer@example.test',
  'displayName': 'Fixture farmer',
  'status': status,
  'createdAt': '2026-10-15T00:00:00Z',
  'revision': 'a' * 64,
};
Map<String, Object?> auditJson() => {
  'id': '22345678-1234-4123-8123-123456789abc',
  'action': 'DEACTIVATE',
  'entityType': 'farmer_account',
  'entityId': farmerId,
  'createdAt': '2026-10-15T00:00:00Z',
  'actor': {'id': '32345678-1234-4123-8123-123456789abc', 'role': 'ADMIN'},
  'metadata': {
    'fromStatus': 'ACTIVE',
    'toStatus': 'SUSPENDED',
    'revokedSessions': 2,
  },
};

class FakeAccountsRepository implements AdminAccountsRepository {
  @override
  bool signedIn = true;
  @override
  int? sessionRevision = 1;
  Object? failure;
  List<ManagedFarmer> items = [ManagedFarmer.fromJson(farmerAccountJson())];
  List<AdminAuditEntry> auditItems = [AdminAuditEntry.fromJson(auditJson())];
  Completer<FarmerAccountPage>? pendingFarmers;
  Completer<AuditLogPage>? pendingAudits;
  int farmerCalls = 0, auditCalls = 0, changes = 0;
  String? lastStatus, lastAction, cursor;
  @override
  Future<FarmerAccountPage> farmers({
    String? status,
    String? email,
    String? cursor,
  }) async {
    farmerCalls++;
    lastStatus = status;
    if (failure case final error?) throw error;
    return pendingFarmers?.future ??
        (
          items: items
              .where((item) => status == null || item.status == status)
              .toList(),
          nextCursor: this.cursor,
        );
  }

  @override
  Future<ManagedFarmer> changeStatus(
    ManagedFarmer farmer,
    String status,
  ) async {
    changes++;
    if (failure case final error?) throw error;
    return ManagedFarmer.fromJson(
      farmerAccountJson(id: farmer.id, status: status),
    );
  }

  @override
  Future<AuditLogPage> audits({
    String? action,
    String? entityType,
    String? actorId,
    String? from,
    String? to,
    String? cursor,
  }) async {
    auditCalls++;
    lastAction = action;
    if (failure case final error?) throw error;
    return pendingAudits?.future ??
        (items: auditItems, nextCursor: this.cursor);
  }
}
