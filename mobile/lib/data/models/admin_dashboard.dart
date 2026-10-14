import '../../core/exceptions/app_exception.dart';
import 'farmer_analytics.dart';
import 'scan_record.dart';

class AdminActivity {
  const AdminActivity(this.createdAt, this.status, this.anonymous, this.label);
  final DateTime createdAt;
  final ScanStatus status;
  final bool anonymous;
  final String? label;
}

class AdminDashboard {
  AdminDashboard._(
    this.scans,
    this.farmers,
    this.authenticatedScans,
    this.anonymousScans,
    this.registry,
    this.productionVersion,
    this.configuredVersion,
    this.inferenceConfigured,
    this.recent,
  );
  final FarmerAnalytics scans;
  final Map<String, int> farmers;
  final int authenticatedScans;
  final int anonymousScans;
  final String registry;
  final String? productionVersion;
  final String? configuredVersion;
  final bool inferenceConfigured;
  final List<AdminActivity> recent;
  factory AdminDashboard.fromJson(Object? value) {
    final data = _object(value, {
      'range',
      'asOf',
      'scans',
      'farmers',
      'ownership',
      'recent',
      'model',
      'aiRequestStatistics',
    });
    final statistics = data['scans'];
    if (statistics is! Map<String, dynamic>) throw _invalid();
    final scans = FarmerAnalytics.fromJson({
      ...statistics,
      'range': data['range'],
      'asOf': data['asOf'],
    });
    final farmers = _object(data['farmers'], {
      'total',
      'active',
      'suspended',
      'deactivated',
    }).map((key, value) => MapEntry(key, _count(value)));
    final ownership = _object(data['ownership'], {
      'authenticated',
      'anonymous',
    });
    final authenticated = _count(ownership['authenticated']);
    final anonymous = _count(ownership['anonymous']);
    final model = _object(data['model'], {
      'registry',
      'productionVersion',
      'configuredVersion',
      'inferenceConfigured',
      'readiness',
    });
    final registry = model['registry'];
    final production = _version(model['productionVersion']);
    final configured = _version(model['configuredVersion']);
    if (farmers['total'] !=
            farmers['active']! +
                farmers['suspended']! +
                farmers['deactivated']! ||
        authenticated + anonymous != scans.totals['totalScans'] ||
        model['readiness'] != 'NOT_CHECKED' ||
        ![
          'NOT_PROMOTED',
          'SINGLE_PRODUCTION',
          'MULTIPLE_PRODUCTION',
        ].contains(registry) ||
        (registry == 'SINGLE_PRODUCTION') != (production != null) ||
        model['inferenceConfigured'] is! bool ||
        data['aiRequestStatistics'] != 'NOT_RECORDED') {
      throw _invalid();
    }
    final raw = data['recent'];
    if (raw is! List || raw.length > 10) throw _invalid();
    final recent = raw.map((value) {
      final row = _object(value, {
        'createdAt',
        'status',
        'origin',
        'predictedClass',
      });
      final date = analyticsTimestamp(row['createdAt']);
      final statuses = ScanStatus.values.where(
        (status) => status.name.toUpperCase() == row['status'],
      );
      final label = row['predictedClass'];
      if (statuses.length != 1 ||
          !['ANONYMOUS', 'AUTHENTICATED'].contains(row['origin']) ||
          date.isBefore(scans.range.from) ||
          !date.isBefore(scans.range.to.add(const Duration(days: 1))) ||
          (label != null &&
              (label is! String ||
                  !analyticsLabels.contains(label) ||
                  statuses.single != ScanStatus.completed))) {
        throw _invalid();
      }
      return AdminActivity(
        date,
        statuses.single,
        row['origin'] == 'ANONYMOUS',
        label as String?,
      );
    }).toList();
    for (var index = 1; index < recent.length; index++) {
      if (recent[index].createdAt.isAfter(recent[index - 1].createdAt)) {
        throw _invalid();
      }
    }
    if (recent.length > scans.totals['totalScans']!) throw _invalid();
    return AdminDashboard._(
      scans,
      Map.unmodifiable(farmers),
      authenticated,
      anonymous,
      registry as String,
      production,
      configured,
      model['inferenceConfigured'] as bool,
      List.unmodifiable(recent),
    );
  }
}

AppException _invalid() => const AppException(AppErrorKind.invalidResponse);
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !keys.every(value.containsKey)) {
    throw _invalid();
  }
  return value;
}

int _count(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) throw _invalid();
  return value;
}

String? _version(Object? value) {
  if (value == null) return null;
  if (value is! String ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(value)) {
    throw _invalid();
  }
  return value;
}
