import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/farmer_analytics.dart';

abstract interface class AnalyticsRepository {
  bool get hasAuthenticatedSession;
  int? get sessionRevision;
  Future<FarmerAnalytics> summary(AnalyticsDateRange range);
  Future<AnalyticsActivityPage> activity(
    AnalyticsDateRange range, {
    String? cursor,
  });
}

class ApiAnalyticsRepository implements AnalyticsRepository {
  const ApiAnalyticsRepository(this._api);
  final ApiClient _api;
  @override
  bool get hasAuthenticatedSession => _api.hasAuthenticatedSession;
  @override
  int? get sessionRevision => _api.sessionRevision;
  @override
  Future<FarmerAnalytics> summary(AnalyticsDateRange range) async {
    final result = FarmerAnalytics.fromJson(
      (await _api.get(
        'analytics/scans',
        query: range.toQuery(),
        authenticated: true,
      )).data,
    );
    if (!result.range.same(range)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return result;
  }

  @override
  Future<AnalyticsActivityPage> activity(
    AnalyticsDateRange range, {
    String? cursor,
  }) async {
    if (cursor != null &&
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(cursor)) {
      throw const AppException(AppErrorKind.validation);
    }
    final result = AnalyticsActivityPage.fromJson(
      (await _api.get(
        'analytics/scans/activity',
        query: {...range.toQuery(), 'limit': '10', 'cursor': ?cursor},
        authenticated: true,
      )).data,
    );
    if (!result.range.same(range) ||
        (cursor != null && result.nextCursor == cursor)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return result;
  }
}
