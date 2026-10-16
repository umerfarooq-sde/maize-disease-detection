import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/admin_dashboard.dart';
import '../models/farmer_analytics.dart';
import '../models/ai_operations.dart';

abstract interface class AdminDashboardRepository {
  bool get hasSession;
  int? get revision;
  Future<AdminDashboard> load(AnalyticsDateRange range);
}

class ApiAdminDashboardRepository implements AdminDashboardRepository {
  const ApiAdminDashboardRepository(this._api);
  final ApiClient _api;
  @override
  bool get hasSession => _api.hasAuthenticatedSession;
  @override
  int? get revision => _api.sessionRevision;
  @override
  Future<AdminDashboard> load(AnalyticsDateRange range) async {
    Object? operations;
    try {
      operations = (await _api.get(
        'admin/ai-operations',
        query: range.toQuery(),
        authenticated: true,
      )).data;
      AiOperations.fromJson(operations);
    } on AppException catch (failure) {
      if (failure.kind == AppErrorKind.authentication ||
          failure.kind == AppErrorKind.authorization) {
        rethrow;
      }
      operations = {'status': 'UNAVAILABLE'};
    }
    final dashboard = AdminDashboard.fromJson(
      (await _api.get(
        'admin/dashboard',
        query: range.toQuery(),
        authenticated: true,
      )).data,
      operations: operations,
    );
    if (!dashboard.scans.range.same(range)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return dashboard;
  }
}
