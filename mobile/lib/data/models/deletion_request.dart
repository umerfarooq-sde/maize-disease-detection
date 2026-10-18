import '../../core/exceptions/app_exception.dart';

class DeletionRequest {
  const DeletionRequest({required this.status, required this.requestedAt});
  final String status;
  final DateTime requestedAt;
  static const statuses = {
    'REQUESTED',
    'APPROVED',
    'ASSET_CLEANUP',
    'COMPLETED',
    'REJECTED',
  };
  static DeletionRequest? fromResponse(Object? value) {
    if (value is! Map<String, dynamic> || !value.containsKey('request')) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final request = value['request'];
    if (request == null) return null;
    if (request is! Map<String, dynamic> ||
        !statuses.contains(request['status']) ||
        request['requestedAt'] is! String ||
        request['erasureAutomaticallyEnabled'] != false) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final date = DateTime.tryParse(request['requestedAt'] as String);
    if (date == null) throw const AppException(AppErrorKind.invalidResponse);
    return DeletionRequest(
      status: request['status'] as String,
      requestedAt: date,
    );
  }

  String get description => switch (status) {
    'REQUESTED' =>
      'Your deletion request is awaiting review. Your account and data have not been deleted.',
    'APPROVED' =>
      'Your request has been reviewed. Account access is suspended while erasure is prepared.',
    'ASSET_CLEANUP' =>
      'Account data has been removed. Private image cleanup is still pending.',
    'COMPLETED' =>
      'The approved account-data erasure workflow is complete. Policy-governed audit and backup records may remain.',
    _ =>
      'Your request was not approved. Contact the project administrator for review.',
  };
}
