import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/admin_dashboard.dart';
import '../models/farmer_analytics.dart';

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
    final dashboard = AdminDashboard.fromJson(
      (await _api.get(
        'admin/dashboard',
        query: range.toQuery(),
        authenticated: true,
      )).data,
    );
    if (!dashboard.scans.range.same(range)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return dashboard;
  }
}
