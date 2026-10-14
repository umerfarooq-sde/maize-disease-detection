import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/data/repositories/analytics_repository.dart';

const firstId = '00000000-0000-4000-8000-000000000001';
const secondId = '00000000-0000-4000-8000-000000000002';
const thirdId = '00000000-0000-4000-8000-000000000003';
final clock = DateTime.utc(2026, 10, 15, 12);
final testRange = AnalyticsDateRange(
  DateTime.utc(2026, 10, 1),
  DateTime.utc(2026, 10, 2),
);
Map<String, Object?> rangeJson(AnalyticsDateRange range) => {
  ...range.toQuery(),
  'timeZone': 'UTC',
  'days': range.days,
};
Map<String, Object?> summaryJson({
  AnalyticsDateRange? range,
  bool empty = false,
}) {
  final window = range ?? testRange;
  return {
    'range': rangeJson(window),
    'asOf': clock.toIso8601String(),
    'totals': {
      'totalScans': empty ? 0 : 8,
      'completedScans': empty ? 0 : 5,
      'pendingScans': empty ? 0 : 1,
      'processingScans': empty ? 0 : 1,
      'failedScans': empty ? 0 : 1,
      'withPrediction': empty ? 0 : 4,
      'completedWithoutPrediction': empty ? 0 : 1,
      'healthyPredictions': empty ? 0 : 1,
      'diseasePredictions': empty ? 0 : 2,
      'otherPredictions': empty ? 0 : 1,
    },
    'uncertainty': {
      'lowConfidence': empty ? 0 : 2,
      'confident': empty ? 0 : 1,
      'unavailable': empty ? 0 : 1,
    },
    'distribution': [
      for (final label in analyticsLabels)
        {
          'label': label,
          'count': empty || label == 'Northern_Corn_Leaf_Blight' ? 0 : 1,
        },
    ],
    'daily': [
      for (var index = 0; index < window.days; index++)
        {
          'date': analyticsDateText(window.from.add(Duration(days: index))),
          'count': empty
              ? 0
              : window.days == 1
              ? 8
              : index == 0
              ? 5
              : index == window.days - 1
              ? 3
              : 0,
        },
    ],
  };
}

Map<String, Object?> activityJson({
  AnalyticsDateRange? range,
  bool empty = false,
  bool next = false,
  bool last = false,
}) {
  final window = range ?? testRange;
  final ids = empty
      ? <String>[]
      : last
      ? [thirdId]
      : [firstId, secondId];
  return {
    'range': rangeJson(window),
    'items': [
      for (var index = 0; index < ids.length; index++)
        {
          'id': ids[index],
          'status': 'COMPLETED',
          'createdAt': window.to
              .add(Duration(seconds: last ? 1 : 3 - index))
              .toIso8601String(),
          'predictedClass': index == 0 ? 'Healthy' : 'Common_Rust',
        },
    ],
    'nextCursor': next && ids.isNotEmpty ? ids.last : null,
  };
}

class FakeAnalyticsRepository implements AnalyticsRepository {
  @override
  bool hasAuthenticatedSession = true;
  @override
  int? sessionRevision = 1;
  final summaryCalls = <AnalyticsDateRange>[];
  final activityCalls = <String?>[];
  Future<FarmerAnalytics> Function(AnalyticsDateRange)? onSummary;
  Future<AnalyticsActivityPage> Function(AnalyticsDateRange, String?)?
  onActivity;
  @override
  Future<FarmerAnalytics> summary(AnalyticsDateRange range) async {
    summaryCalls.add(range);
    return onSummary != null
        ? onSummary!(range)
        : FarmerAnalytics.fromJson(summaryJson(range: range));
  }

  @override
  Future<AnalyticsActivityPage> activity(
    AnalyticsDateRange range, {
    String? cursor,
  }) async {
    activityCalls.add(cursor);
    return onActivity != null
        ? onActivity!(range, cursor)
        : AnalyticsActivityPage.fromJson(activityJson(range: range));
  }
}
