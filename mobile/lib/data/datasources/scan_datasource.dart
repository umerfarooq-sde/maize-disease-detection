import '../../core/network/api_client.dart';
import '../../core/exceptions/app_exception.dart';
import '../models/scan_history_page.dart';
import '../models/scan_record.dart';
import '../models/selected_leaf_image.dart';

class ScanDatasource {
  ScanDatasource(this._api);
  final ApiClient _api;
  bool get hasAuthenticatedSession => _api.hasAuthenticatedSession;

  Future<ScanRecord> read(String id, {String? anonymousKey}) async {
    if (!_uuid.hasMatch(id)) {
      throw const AppException(AppErrorKind.validation);
    }
    final authenticated = hasAuthenticatedSession;
    if (!authenticated &&
        (anonymousKey == null || !_anonymousKey.hasMatch(anonymousKey))) {
      throw const AppException(AppErrorKind.authentication);
    }
    final response = await _api.get(
      'scans/$id',
      authenticated: authenticated,
      headers: authenticated ? const {} : {'Idempotency-Key': anonymousKey!},
    );
    final scan = ScanRecord.fromJson(response.data);
    if (scan.id != id) throw const AppException(AppErrorKind.invalidResponse);
    return scan;
  }

  Future<ScanHistoryPage> history({String? cursor, int limit = 20}) async {
    if (!hasAuthenticatedSession) {
      throw const AppException(AppErrorKind.authentication);
    }
    if (limit < 1 ||
        limit > 50 ||
        (cursor != null && !_uuid.hasMatch(cursor))) {
      throw const AppException(AppErrorKind.validation);
    }
    final response = await _api.get(
      'scans',
      authenticated: true,
      query: {'limit': '$limit', 'cursor': ?cursor},
    );
    final page = ScanHistoryPage.fromJson(response.data);
    if (page.items.length > limit ||
        (cursor != null && page.nextCursor == cursor)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return page;
  }

  static final _uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
  static final _anonymousKey = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
  Future<ScanRecord> upload(
    SelectedLeafImage image,
    String requestKey,
    void Function(double) onProgress,
  ) async {
    final response = await _api.uploadImage(
      bytes: image.bytes,
      filename: image.filename,
      mimeType: image.mimeType,
      idempotencyKey: requestKey,
      onProgress: onProgress,
    );
    return ScanRecord.fromJson(response.data);
  }
}
