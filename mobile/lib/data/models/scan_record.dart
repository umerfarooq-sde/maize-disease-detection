import '../../core/exceptions/app_exception.dart';

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.imageUrl,
    required this.mimeType,
    required this.bytes,
    required this.uploadedAt,
    required this.createdAt,
  });
  final String id;
  final Uri imageUrl;
  final String mimeType;
  final int bytes;
  final DateTime uploadedAt;
  final DateTime createdAt;

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
      if (id is String &&
          RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) &&
          value['status'] == 'PENDING' &&
          uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          const ['image/jpeg', 'image/png', 'image/webp'].contains(mime) &&
          bytes is int &&
          bytes > 0 &&
          uploaded != null &&
          created != null) {
        return ScanRecord(
          id: id,
          imageUrl: uri,
          mimeType: mime as String,
          bytes: bytes,
          uploadedAt: uploaded,
          createdAt: created,
        );
      }
    }
    throw const AppException(AppErrorKind.invalidResponse);
  }
}
