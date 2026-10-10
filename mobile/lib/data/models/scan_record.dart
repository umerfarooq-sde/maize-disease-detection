import '../../core/exceptions/app_exception.dart';
import 'scan_prediction.dart';

enum ScanStatus { pending, processing, completed, failed }

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.imageUrl,
    required this.mimeType,
    required this.bytes,
    required this.uploadedAt,
    required this.createdAt,
    this.status = ScanStatus.pending,
    this.finishedAt,
    this.prediction,
    this.analysisErrorCode,
  });
  final String id;
  final Uri imageUrl;
  final String mimeType;
  final int bytes;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final ScanStatus status;
  final DateTime? finishedAt;
  final ScanPrediction? prediction;
  final String? analysisErrorCode;

  static const _analysisErrorCodes = {
    'INFERENCE_UNAVAILABLE',
    'INFERENCE_TIMEOUT',
    'INFERENCE_FAILED',
    'INFERENCE_INVALID_RESPONSE',
    'INFERENCE_PERSISTENCE_FAILED',
    'INFERENCE_INTERRUPTED',
    'INVALID_IMAGE',
  };

  factory ScanRecord.fromJson(Object? value) {
    if (value is Map<String, dynamic> &&
        value['image'] is Map<String, dynamic>) {
      final image = value['image'] as Map<String, dynamic>;
      final id = value['id'];
      final url = image['url'];
      final mime = image['mimeType'];
      final bytes = image['bytes'];
      final uri = url is String ? Uri.tryParse(url) : null;
      final uploaded = image['uploadedAt'] is String
          ? DateTime.tryParse(image['uploadedAt'] as String)
          : null;
      final created = value['createdAt'] is String
          ? DateTime.tryParse(value['createdAt'] as String)
          : null;
      final status = switch (value['status']) {
        'PENDING' => ScanStatus.pending,
        'PROCESSING' => ScanStatus.processing,
        'COMPLETED' => ScanStatus.completed,
        'FAILED' => ScanStatus.failed,
        _ => null,
      };
      final rawFinished = value['finishedAt'];
      final finished = rawFinished is String
          ? DateTime.tryParse(rawFinished)
          : null;
      final prediction = value['prediction'] == null
          ? null
          : ScanPrediction.fromJson(value['prediction']);
      final rawError = value['analysisError'];
      final errorCode = rawError is Map<String, dynamic>
          ? rawError['code']
          : null;
      final terminal =
          status == ScanStatus.completed || status == ScanStatus.failed;
      if (id is String &&
          RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) &&
          status != null &&
          ((status == ScanStatus.completed) == (prediction != null)) &&
          (terminal == (finished != null)) &&
          (rawFinished == null || finished != null) &&
          (rawError == null ||
              (status == ScanStatus.failed &&
                  errorCode is String &&
                  _analysisErrorCodes.contains(errorCode))) &&
          uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          const ['image/jpeg', 'image/png', 'image/webp'].contains(mime) &&
          bytes is int &&
          bytes > 0 &&
          uploaded != null &&
          created != null &&
          (finished == null || !finished.isBefore(created)) &&
          (prediction == null ||
              (!prediction.inferredAt.isBefore(created) &&
                  !prediction.inferredAt.isAfter(finished!)))) {
        return ScanRecord(
          id: id,
          imageUrl: uri,
          mimeType: mime as String,
          bytes: bytes,
          uploadedAt: uploaded,
          createdAt: created,
          status: status,
          finishedAt: finished,
          prediction: prediction,
          analysisErrorCode: errorCode as String?,
        );
      }
    }
    throw const AppException(AppErrorKind.invalidResponse);
  }
}
