import '../../core/exceptions/app_exception.dart';
import 'scan_prediction.dart';
import 'scan_record.dart';

const analyticsLabels = [...ScanPrediction.classLabels, 'OTHER'];
const _day = Duration(days: 1);
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !keys.every(value.containsKey)) {
    throw _invalid();
  }
  return value;
}

AppException _invalid() => const AppException(AppErrorKind.invalidResponse);
String analyticsDateText(DateTime date) =>
    date.toIso8601String().substring(0, 10);
DateTime _date(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      value.compareTo('0001-01-01') < 0) {
    throw _invalid();
  }
  final parsed = DateTime.tryParse('${value}T00:00:00.000Z');
  if (parsed == null || analyticsDateText(parsed) != value) throw _invalid();
  return parsed;
}

DateTime _timestamp(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,6})?Z$',
      ).hasMatch(value)) {
    throw _invalid();
  }
  _date(value.substring(0, 10));
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) throw _invalid();
  return parsed;
}

int _count(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) throw _invalid();
  return value;
}

String _uuid(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
      ).hasMatch(value)) {
    throw _invalid();
  }
  return value;
}

class AnalyticsDateRange {
  AnalyticsDateRange(DateTime from, DateTime to)
    : from = DateTime.utc(from.year, from.month, from.day),
      to = DateTime.utc(to.year, to.month, to.day) {
    if (days < 1 || days > 366 || this.from.year < 1 || this.to.year > 9999) {
      throw const AppException(AppErrorKind.validation);
    }
  }
  factory AnalyticsDateRange.lastDays(int days, {DateTime? now}) {
    final utc = (now ?? DateTime.now()).toUtc();
    final today = DateTime.utc(utc.year, utc.month, utc.day);
    return AnalyticsDateRange(today.subtract(Duration(days: days - 1)), today);
  }
  final DateTime from;
  final DateTime to;
  int get days => to.difference(from).inDays + 1;
  Map<String, String> toQuery() => {
    'from': analyticsDateText(from),
    'to': analyticsDateText(to),
  };
  bool same(AnalyticsDateRange other) => from == other.from && to == other.to;
  factory AnalyticsDateRange.fromJson(Object? value) {
    final data = _object(value, const {'from', 'to', 'timeZone', 'days'});
    try {
      final range = AnalyticsDateRange(_date(data['from']), _date(data['to']));
      if (data['timeZone'] != 'UTC' || _count(data['days']) != range.days) {
        throw _invalid();
      }
      return range;
    } on AppException {
      throw _invalid();
    }
  }
}

class AnalyticsCount {
  const AnalyticsCount(this.label, this.count);
  final String label;
  final int count;
}

class AnalyticsDay {
  const AnalyticsDay(this.date, this.count);
  final DateTime date;
  final int count;
}

class FarmerAnalytics {
  FarmerAnalytics._(
    this.range,
    this.asOf,
    Map<String, int> totals,
    Map<String, int> uncertainty,
    List<AnalyticsCount> distribution,
    List<AnalyticsDay> daily,
  ) : totals = Map.unmodifiable(totals),
      uncertainty = Map.unmodifiable(uncertainty),
      distribution = List.unmodifiable(distribution),
      daily = List.unmodifiable(daily);
  final AnalyticsDateRange range;
  final DateTime asOf;
  final Map<String, int> totals;
  final Map<String, int> uncertainty;
  final List<AnalyticsCount> distribution;
  final List<AnalyticsDay> daily;
  static const _totalKeys = {
    'totalScans',
    'completedScans',
    'pendingScans',
    'processingScans',
    'failedScans',
    'withPrediction',
    'completedWithoutPrediction',
    'healthyPredictions',
    'diseasePredictions',
    'otherPredictions',
  };
  factory FarmerAnalytics.fromJson(Object? value) {
    final data = _object(value, const {
      'range',
      'asOf',
      'totals',
      'uncertainty',
      'distribution',
      'daily',
    });
    final range = AnalyticsDateRange.fromJson(data['range']);
    final totals = _object(
      data['totals'],
      _totalKeys,
    ).map((key, value) => MapEntry(key, _count(value)));
    final uncertainty = _object(data['uncertainty'], const {
      'lowConfidence',
      'confident',
      'unavailable',
    }).map((key, value) => MapEntry(key, _count(value)));
    final rawDistribution = data['distribution'];
    final rawDays = data['daily'];
    if (rawDistribution is! List ||
        rawDistribution.length != analyticsLabels.length ||
        rawDays is! List ||
        rawDays.length != range.days) {
      throw _invalid();
    }
    final distribution = rawDistribution.map((row) {
      final item = _object(row, const {'label', 'count'});
      final label = item['label'];
      if (label is! String || !analyticsLabels.contains(label)) {
        throw _invalid();
      }
      return AnalyticsCount(label, _count(item['count']));
    }).toList();
    final daily = rawDays.map((row) {
      final item = _object(row, const {'date', 'count'});
      return AnalyticsDay(_date(item['date']), _count(item['count']));
    }).toList();
    final counts = {for (final item in distribution) item.label: item.count};
    if (counts.length != analyticsLabels.length ||
        totals['totalScans'] !=
            totals['completedScans']! +
                totals['pendingScans']! +
                totals['processingScans']! +
                totals['failedScans']! ||
        totals['completedScans'] !=
            totals['withPrediction']! + totals['completedWithoutPrediction']! ||
        totals['withPrediction'] !=
            totals['healthyPredictions']! +
                totals['diseasePredictions']! +
                totals['otherPredictions']! ||
        totals['withPrediction'] !=
            uncertainty.values.fold<int>(0, (sum, value) => sum + value) ||
        totals['withPrediction'] !=
            counts.values.fold<int>(0, (sum, value) => sum + value) ||
        totals['healthyPredictions'] != counts['Healthy'] ||
        totals['otherPredictions'] != counts['OTHER'] ||
        totals['diseasePredictions'] !=
            counts['Common_Rust']! +
                counts['Gray_Leaf_Spot']! +
                counts['Northern_Corn_Leaf_Blight']! ||
        totals['totalScans'] !=
            daily.fold<int>(0, (sum, item) => sum + item.count)) {
      throw _invalid();
    }
    for (var index = 0; index < daily.length; index++) {
      if (daily[index].date != range.from.add(_day * index)) throw _invalid();
    }
    return FarmerAnalytics._(
      range,
      _timestamp(data['asOf']),
      totals,
      uncertainty,
      distribution,
      daily,
    );
  }
}

class AnalyticsActivity {
  const AnalyticsActivity._(
    this.id,
    this.status,
    this.createdAt,
    this.predictedClass,
  );
  final String id;
  final ScanStatus status;
  final DateTime createdAt;
  final String? predictedClass;
  factory AnalyticsActivity.fromJson(Object? value) {
    final data = _object(value, const {
      'id',
      'status',
      'createdAt',
      'predictedClass',
    });
    final status = switch (data['status']) {
      'PENDING' => ScanStatus.pending,
      'PROCESSING' => ScanStatus.processing,
      'COMPLETED' => ScanStatus.completed,
      'FAILED' => ScanStatus.failed,
      _ => throw _invalid(),
    };
    final label = data['predictedClass'];
    if (label != null &&
        (label is! String ||
            !analyticsLabels.contains(label) ||
            status != ScanStatus.completed)) {
      throw _invalid();
    }
    return AnalyticsActivity._(
      _uuid(data['id']),
      status,
      _timestamp(data['createdAt']),
      label as String?,
    );
  }
}

class AnalyticsActivityPage {
  AnalyticsActivityPage._(
    this.range,
    List<AnalyticsActivity> items,
    this.nextCursor,
  ) : items = List.unmodifiable(items);
  final AnalyticsDateRange range;
  final List<AnalyticsActivity> items;
  final String? nextCursor;
  factory AnalyticsActivityPage.fromJson(Object? value) {
    final data = _object(value, const {'range', 'items', 'nextCursor'});
    final range = AnalyticsDateRange.fromJson(data['range']);
    final raw = data['items'];
    if (raw is! List || raw.length > 50) throw _invalid();
    final items = raw.map(AnalyticsActivity.fromJson).toList();
    final cursor = data['nextCursor'] == null
        ? null
        : _uuid(data['nextCursor']);
    if (items.map((item) => item.id).toSet().length != items.length ||
        (cursor != null && (items.isEmpty || cursor != items.last.id))) {
      throw _invalid();
    }
    for (var index = 0; index < items.length; index++) {
      final date = items[index].createdAt;
      if (date.isBefore(range.from) ||
          !date.isBefore(range.to.add(_day)) ||
          (index > 0 && date.isAfter(items[index - 1].createdAt))) {
        throw _invalid();
      }
    }
    return AnalyticsActivityPage._(range, items, cursor);
  }
}
