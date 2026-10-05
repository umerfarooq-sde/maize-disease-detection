import '../../core/exceptions/app_exception.dart';

class BackendHealth {
  const BackendHealth({required this.isAvailable, required this.checkedAt});
  final bool isAvailable;
  final DateTime checkedAt;

  factory BackendHealth.fromJson(Map<String, dynamic> json, int statusCode) {
    final checks = json['checks'];
    final timestamp = json['timestamp'];
    final date = timestamp is String ? DateTime.tryParse(timestamp) : null;
    if (checks is! Map<String, dynamic> ||
        date == null ||
        !['up', 'down'].contains(checks['database']) ||
        !['ok', 'degraded'].contains(json['status']) ||
        (statusCode != 200 && statusCode != 503) ||
        (json['status'] == 'ok') != (checks['database'] == 'up') ||
        (statusCode == 200) != (json['status'] == 'ok')) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return BackendHealth(isAvailable: statusCode == 200, checkedAt: date);
  }
}
