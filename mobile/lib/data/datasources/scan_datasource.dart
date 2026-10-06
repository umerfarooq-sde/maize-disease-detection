import '../../core/network/api_client.dart';
import '../models/scan_record.dart';
import '../models/selected_leaf_image.dart';

class ScanDatasource {
  ScanDatasource(this._api);
  final ApiClient _api;
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
