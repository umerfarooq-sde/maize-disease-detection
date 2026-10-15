import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/admin_accounts.dart';
import '../models/registration_credentials.dart';

typedef FarmerAccountPage = ({List<ManagedFarmer> items, String? nextCursor});
typedef AuditLogPage = ({List<AdminAuditEntry> items, String? nextCursor});

abstract interface class AdminAccountsRepository {
  bool get signedIn;
  int? get sessionRevision;
  Future<FarmerAccountPage> farmers({
    String? status,
    String? email,
    String? cursor,
  });
  Future<ManagedFarmer> changeStatus(ManagedFarmer farmer, String status);
  Future<AuditLogPage> audits({
    String? action,
    String? entityType,
    String? actorId,
    String? from,
    String? to,
    String? cursor,
  });
}

class ApiAdminAccountsRepository implements AdminAccountsRepository {
  const ApiAdminAccountsRepository(this._api);
  final ApiClient _api;
  @override
  bool get signedIn => _api.hasAuthenticatedSession;
  @override
  int? get sessionRevision => _api.sessionRevision;
  @override
  Future<FarmerAccountPage> farmers({
    String? status,
    String? email,
    String? cursor,
  }) async {
    if ((status != null && !farmerAccountStatuses.contains(status)) ||
        (email != null && RegistrationCredentials.emailError(email) != null) ||
        (cursor != null && !accountUuid(cursor))) {
      throw const AppException(AppErrorKind.validation);
    }
    return accountsPage(
      (await _api.get(
        'admin/farmers',
        authenticated: true,
        query: {
          'limit': '20',
          'status': ?status,
          'email': ?email?.trim().toLowerCase(),
          'cursor': ?cursor,
        },
      )).data,
      ManagedFarmer.fromJson,
      (farmer) => farmer.id,
    );
  }

  @override
  Future<ManagedFarmer> changeStatus(
    ManagedFarmer farmer,
    String status,
  ) async {
    if (!accountUuid(farmer.id) ||
        !farmerAccountStatuses.contains(status) ||
        status == farmer.status) {
      throw const AppException(AppErrorKind.validation);
    }
    final response = (await _api.request(
      ApiMethod.patch,
      'admin/farmers/${farmer.id}/status',
      authenticated: true,
      body: {'status': status, 'expectedRevision': farmer.revision},
    )).data;
    if (response is! Map<String, dynamic>) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final result = ManagedFarmer.fromJson(response['farmer']);
    if (result.id != farmer.id || result.status != status) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return result;
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
    if ((action != null && !accountAuditActions.contains(action)) ||
        (entityType != null && !accountAuditEntities.contains(entityType)) ||
        (actorId != null && !accountUuid(actorId)) ||
        (cursor != null && !accountUuid(cursor)) ||
        !_validDates(from, to)) {
      throw const AppException(AppErrorKind.validation);
    }
    return accountsPage(
      (await _api.get(
        'admin/audit-logs',
        authenticated: true,
        query: {
          'limit': '20',
          'action': ?action,
          'entityType': ?entityType,
          'actorId': ?actorId,
          'from': ?from,
          'to': ?to,
          'cursor': ?cursor,
        },
      )).data,
      AdminAuditEntry.fromJson,
      (entry) => entry.id,
    );
  }

  bool _validDates(String? from, String? to) {
    if (from == null && to == null) return true;
    if (from == null ||
        to == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(from) ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(to)) {
      return false;
    }
    final start = DateTime.tryParse('${from}T00:00:00Z'),
        end = DateTime.tryParse('${to}T00:00:00Z');
    return start != null &&
        end != null &&
        start.toIso8601String().startsWith(from) &&
        end.toIso8601String().startsWith(to) &&
        !end.isBefore(start) &&
        end.difference(start).inDays < 366;
  }
}
