import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../exceptions/app_exception.dart';

class AppConfig {
  AppConfig({String apiBaseUrl = '', bool requireHttps = kReleaseMode})
    : baseUrl = _parse(apiBaseUrl, requireHttps);

  factory AppConfig.fromDotEnv() {
    final rawUrl =
        dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';
    final requireHttpsEnv =
        dotenv.isInitialized ? dotenv.env['REQUIRE_HTTPS'] : null;
    final requireHttps = requireHttpsEnv != null
        ? requireHttpsEnv.trim().toLowerCase() == 'true'
        : (rawUrl.trim().toLowerCase().startsWith('http://')
            ? false
            : kReleaseMode);
    return AppConfig(
      apiBaseUrl: rawUrl,
      requireHttps: requireHttps,
    );
  }

  factory AppConfig.fromEnvironment() => AppConfig.fromDotEnv();

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
