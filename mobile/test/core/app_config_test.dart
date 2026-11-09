import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/app_config.dart';

void main() {
  setUp(() {
    dotenv.clean();
  });

  tearDown(() {
    dotenv.clean();
  });

  group('AppConfig dotEnv loading', () {
    test('returns unconfigured when dotenv is not initialized', () {
      expect(dotenv.isInitialized, isFalse);
      final config = AppConfig.fromDotEnv();
      expect(config.isConfigured, isFalse);
      expect(config.baseUrl, isNull);

      final envConfig = AppConfig.fromEnvironment();
      expect(envConfig.isConfigured, isFalse);
      expect(envConfig.baseUrl, isNull);
    });

    test(
      'returns unconfigured when API_BASE_URL is missing or empty in .env',
      () {
        dotenv.loadFromString(envString: 'OTHER_VAR=value\n');
        expect(dotenv.isInitialized, isTrue);

        final config = AppConfig.fromDotEnv();
        expect(config.isConfigured, isFalse);
        expect(config.baseUrl, isNull);

        dotenv.clean();
        dotenv.loadFromString(envString: 'API_BASE_URL=\n');
        final emptyConfig = AppConfig.fromDotEnv();
        expect(emptyConfig.isConfigured, isFalse);
        expect(emptyConfig.baseUrl, isNull);
      },
    );

    test('loads and normalizes valid API_BASE_URL from .env', () {
      dotenv.loadFromString(
        envString: 'API_BASE_URL=https://api.example.com/api/v1\n',
      );
      final config = AppConfig.fromDotEnv();

      expect(config.isConfigured, isTrue);
      expect(config.baseUrl, isNotNull);
      expect(config.baseUrl.toString(), 'https://api.example.com/api/v1/');
    });

    test('loads valid API_BASE_URL with trailing slash correctly', () {
      dotenv.loadFromString(
        envString: 'API_BASE_URL=https://api.example.com/api/v1/\n',
      );
      final config = AppConfig.fromDotEnv();

      expect(config.isConfigured, isTrue);
      expect(config.baseUrl.toString(), 'https://api.example.com/api/v1/');
    });

    test('throws AppException on invalid API_BASE_URL from .env', () {
      for (final invalid in [
        'https://user:password@host/api/v1',
        'https://host/api/v1?query=1',
        '"https://host/api/v1#hash"',
        'https://host/invalid/path',
        'http://host/api/v1/../secret',
        'ftp://host/api/v1',
      ]) {
        dotenv.clean();
        dotenv.loadFromString(envString: 'API_BASE_URL=$invalid\n');
        expect(
          () => AppConfig.fromDotEnv(),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.configuration,
            ),
          ),
          reason: 'Failed to reject $invalid',
        );
      }
    });

    test('enforces HTTPS when requireHttps is true', () {
      dotenv.loadFromString(
        envString: 'API_BASE_URL=http://insecure.example.com/api/v1\n',
      );
      expect(
        () => AppConfig(
          apiBaseUrl: dotenv.env['API_BASE_URL'] ?? '',
          requireHttps: true,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            AppErrorKind.configuration,
          ),
        ),
      );
    });

    test('allows HTTP in debug mode (requireHttps: false)', () {
      dotenv.loadFromString(
        envString: 'API_BASE_URL=http://10.0.2.2:3000/api/v1\n',
      );
      final config = AppConfig(
        apiBaseUrl: dotenv.env['API_BASE_URL'] ?? '',
        requireHttps: false,
      );
      expect(config.isConfigured, isTrue);
      expect(config.baseUrl.toString(), 'http://10.0.2.2:3000/api/v1/');
    });
  });
}
