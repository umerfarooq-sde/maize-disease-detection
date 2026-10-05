import 'package:flutter/foundation.dart';
import '../exceptions/app_exception.dart';

class AppConfig {
  AppConfig({String apiBaseUrl = '', bool requireHttps = kReleaseMode})
    : baseUrl = _parse(apiBaseUrl, requireHttps);

  factory AppConfig.fromEnvironment() =>
      AppConfig(apiBaseUrl: const String.fromEnvironment('API_BASE_URL'));

  final Uri? baseUrl;
  bool get isConfigured => baseUrl != null;

  static Uri? _parse(String value, bool requireHttps) {
    if (value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    final path = uri?.path.replaceFirst(RegExp(r'/+$'), '') ?? '';
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        (requireHttps && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !path.endsWith('/api/v1') ||
        uri.pathSegments.any((segment) => segment == '..' || segment == '.')) {
      throw const AppException(AppErrorKind.configuration);
    }
    return uri.replace(path: '$path/');
  }
}
