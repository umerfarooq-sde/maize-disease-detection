import 'package:http/http.dart' as http;

/// Reports bytes handed to the transport, including multipart framing. Reaching
/// 100% does not mean Cloudinary storage/database creation has finished.
class UploadRequest extends http.MultipartRequest with http.Abortable {
  UploadRequest(
    super.method,
    super.url, {
    required this.abortTrigger,
    required this.onProgress,
  });
  @override
  final Future<void> abortTrigger;
  final void Function(double)? onProgress;
  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      super.finalize().map((chunk) {
        sent += chunk.length;
        onProgress?.call((sent / total).clamp(0, 1));
        return chunk;
      }),
    );
  }
}
