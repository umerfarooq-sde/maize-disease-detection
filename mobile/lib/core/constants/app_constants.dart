abstract final class AppConstants {
  static const name = 'MAIZEDOCTOR';
  static const requestTimeout = Duration(seconds: 15);
  static const maxResponseBytes = 1024 * 1024;
  static const uploadTimeout = Duration(seconds: 90);
  static const maxImageBytes = 5 * 1024 * 1024;
  static const maxImagePixels = 16000000;
  static const previewPixels = 1024;
}
