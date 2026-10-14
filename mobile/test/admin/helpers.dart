import 'package:maizedoctor/data/models/admin_dashboard.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/data/repositories/admin_dashboard_repository.dart';
import '../analytics/helpers.dart' as analytics;

Map<String, Object?> dashboardJson({
  AnalyticsDateRange? range,
  bool empty = false,
}) {
  final scans = analytics.summaryJson(range: range, empty: empty);
  final window = scans.remove('range');
  final asOf = scans.remove('asOf');
  return {
    'range': window,
    'asOf': asOf,
    'scans': scans,
    'farmers': {'total': 3, 'active': 1, 'suspended': 1, 'deactivated': 1},
    'ownership': {'authenticated': empty ? 0 : 5, 'anonymous': empty ? 0 : 3},
    'recent': empty
        ? <Object>[]
        : [
            {
              'createdAt': (range ?? analytics.testRange).to.toIso8601String(),
              'status': 'COMPLETED',
              'origin': 'ANONYMOUS',
              'predictedClass': 'Healthy',
            },
          ],
    'model': {
      'registry': 'NOT_PROMOTED',
      'productionVersion': null,
      'configuredVersion': 'research-v2',
      'inferenceConfigured': true,
      'readiness': 'NOT_CHECKED',
    },
    'aiRequestStatistics': 'NOT_RECORDED',
  };
}

class FakeAdminRepository implements AdminDashboardRepository {
  @override
  bool hasSession = true;
  @override
  int? revision = 1;
  final calls = <AnalyticsDateRange>[];
  Future<AdminDashboard> Function(AnalyticsDateRange)? respond;
  @override
  Future<AdminDashboard> load(AnalyticsDateRange range) async {
    calls.add(range);
    return respond == null
        ? AdminDashboard.fromJson(dashboardJson(range: range))
        : respond!(range);
  }
}
